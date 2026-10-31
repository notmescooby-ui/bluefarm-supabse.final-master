-- ==============================================================================
-- BlueFarm Account Deletion Requests & Secure Lifecycle Processing
-- Target Database: PostgreSQL (Supabase)
-- Target Tables: public.account_deletion_requests, public.profiles, auth.users
-- ==============================================================================

-- 1. Create table public.account_deletion_requests safely
CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_code VARCHAR(32) NOT NULL,
    user_id UUID,
    account_type VARCHAR(20) NOT NULL CHECK (account_type IN ('farmer', 'buyer')),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    reason TEXT,
    verification_status VARCHAR(30) NOT NULL DEFAULT 'verified' CHECK (verification_status IN ('pending', 'verified', 'failed')),
    processing_status VARCHAR(30) NOT NULL DEFAULT 'received' CHECK (processing_status IN ('received', 'processing', 'completed', 'cancelled', 'rejected')),
    rejection_reason TEXT,
    retained_records_summary TEXT,
    audit_metadata JSONB DEFAULT '{}'::jsonb,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    completed_at TIMESTAMPTZ,
    CONSTRAINT fk_account_deletion_user FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Ensure reference_code has unique constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_account_deletion_requests_reference_code'
    ) THEN
        ALTER TABLE public.account_deletion_requests
        ADD CONSTRAINT uq_account_deletion_requests_reference_code UNIQUE (reference_code);
    END IF;
END $$;

-- 2. Trigger / Default for reference_code generation (e.g. BF-A1B2C3D4)
CREATE OR REPLACE FUNCTION public.fn_generate_deletion_reference_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.reference_code IS NULL OR NEW.reference_code = '' THEN
        NEW.reference_code := 'BF-' || UPPER(SUBSTRING(REPLACE(gen_random_uuid()::text, '-', ''), 1, 8));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_deletion_reference_code ON public.account_deletion_requests;
CREATE TRIGGER trg_set_deletion_reference_code
BEFORE INSERT ON public.account_deletion_requests
FOR EACH ROW
EXECUTE FUNCTION public.fn_generate_deletion_reference_code();

-- 3. Prevent duplicate active deletion requests per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_active_deletion_request_per_user 
ON public.account_deletion_requests (user_id) 
WHERE processing_status IN ('received', 'processing');

-- Helpful lookup index for tracking requests
CREATE INDEX IF NOT EXISTS idx_deletion_requests_reference_code 
ON public.account_deletion_requests (reference_code);

CREATE INDEX IF NOT EXISTS idx_deletion_requests_user_id 
ON public.account_deletion_requests (user_id);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;

-- Dynamic Cleanup of existing policies on account_deletion_requests to guarantee clean state
DO $$
DECLARE
    pol record;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE schemaname = 'public' AND tablename = 'account_deletion_requests'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.account_deletion_requests', pol.policyname);
    END LOOP;
END $$;

-- Policy 1: Authenticated users can insert their own deletion request after verifying via OTP
-- Constrained so users cannot insert as someone else, cannot mark completed, cannot bypass 'received' state
CREATE POLICY "Users can create their own deletion request"
ON public.account_deletion_requests
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id
    AND processing_status = 'received'
    AND verification_status = 'verified'
);

-- Policy 2: Authenticated users can view their own deletion requests
CREATE POLICY "Users can view their own deletion requests"
ON public.account_deletion_requests
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Policy 3: Service role has full administrative access for background processing
CREATE POLICY "Service role has full management on deletion requests"
ON public.account_deletion_requests
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- 5. Privileged Server-Side Function: process_account_deletion
-- Safe, idempotent execution of deletion workflow according to approved retention policy
CREATE OR REPLACE FUNCTION public.process_account_deletion(p_request_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_req RECORD;
    v_user_id UUID;
    v_has_active_orders BOOLEAN := FALSE;
    v_active_order_count INT := 0;
BEGIN
    -- 1. Fetch deletion request row
    SELECT * INTO v_req
    FROM public.account_deletion_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Request not found'
        );
    END IF;

    -- If already completed, return idempotent success
    IF v_req.processing_status = 'completed' THEN
        RETURN jsonb_build_object(
            'success', true,
            'status', 'completed',
            'message', 'Request was already completed previously'
        );
    END IF;

    v_user_id := v_req.user_id;

    -- 2. Check for active obligations / pending orders / active disputes
    -- Check if orders table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'orders'
    ) THEN
        -- Check active orders where user is buyer or farmer
        SELECT COUNT(*) INTO v_active_order_count
        FROM public.orders
        WHERE (buyer_id = v_user_id OR farmer_id = v_user_id)
          AND (
            status IN ('pending', 'confirmed', 'processing', 'shipped', 'out_for_delivery')
            OR payment_status IN ('initiated', 'verification_pending')
          );

        IF v_active_order_count > 0 THEN
            UPDATE public.account_deletion_requests
            SET processing_status = 'rejected',
                rejection_reason = format('Account has %s active or pending order(s). Please complete deliveries and settlements before requesting deletion.', v_active_order_count),
                audit_metadata = audit_metadata || jsonb_build_object('rejected_at', now(), 'active_order_count', v_active_order_count)
            WHERE id = p_request_id;

            RETURN jsonb_build_object(
                'success', false,
                'status', 'rejected',
                'reason', format('Account has %s active or pending order(s).', v_active_order_count)
            );
        END IF;
    END IF;

    -- 3. Mark request as processing
    UPDATE public.account_deletion_requests
    SET processing_status = 'processing'
    WHERE id = p_request_id;

    -- 4. Anonymize/Delete Personal Data in public.profiles (if exists)
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'profiles'
    ) THEN
        UPDATE public.profiles
        SET full_name = 'Deleted User',
            phone_number = NULL,
            email = NULL,
            address = 'Anonymized',
            avatar_url = NULL,
            fcm_token = NULL,
            aadhaar_verified = false,
            updated_at = now()
        WHERE id = v_user_id;
    END IF;

    -- 5. Deactivate farmer listings (if listings table exists)
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'listings'
    ) THEN
        UPDATE public.listings
        SET status = 'archived'
        WHERE farmer_id = v_user_id AND status = 'active';
    END IF;

    -- 6. Ponds / farm data: anonymize or mark archived (if ponds table exists)
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'ponds'
    ) THEN
        UPDATE public.ponds
        SET name = 'Archived Pond'
        WHERE user_id = v_user_id;
    END IF;

    -- 7. Securely delete the user from auth.users (cascades or clears authentication session)
    IF v_user_id IS NOT NULL THEN
        DELETE FROM auth.users WHERE id = v_user_id;
    END IF;

    -- 8. Finalize request status to completed
    UPDATE public.account_deletion_requests
    SET processing_status = 'completed',
        completed_at = timezone('utc'::text, now()),
        retained_records_summary = 'Historical order, payment, and transaction records retained for legal/tax compliance; personal profile and authentication credentials permanently deleted.',
        audit_metadata = audit_metadata || jsonb_build_object('completed_at', now(), 'execution', 'process_account_deletion')
    WHERE id = p_request_id;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'completed',
        'reference_code', v_req.reference_code
    );
END;
$$;

-- Revoke execute from public; only grant to service_role and postgres
REVOKE EXECUTE ON FUNCTION public.process_account_deletion(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.process_account_deletion(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.process_account_deletion(UUID) TO postgres;
