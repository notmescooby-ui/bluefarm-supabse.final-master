-- ==============================================================================
-- BlueFarm Payment Security, Order State Machine & Integrity Migration
-- Database: PostgreSQL (Supabase)
-- Target Table: public.orders
-- ==============================================================================

-- 1. Add additive payment state columns safely if they do not already exist
DO $$
BEGIN
    -- payment_status: tracks payment lifecycle ('pending', 'cod_due', 'initiated', 'verification_pending', 'paid', 'failed', 'cancelled')
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'payment_status'
    ) THEN
        ALTER TABLE public.orders 
        ADD COLUMN payment_status VARCHAR(30) NOT NULL DEFAULT 'pending';
    END IF;

    -- currency: standard ISO 4217 currency code (default 'INR')
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'currency'
    ) THEN
        ALTER TABLE public.orders 
        ADD COLUMN currency VARCHAR(10) NOT NULL DEFAULT 'INR';
    END IF;

    -- amount_paise: integer amount in paise (1 INR = 100 paise) to prevent floating-point rounding issues
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'amount_paise'
    ) THEN
        ALTER TABLE public.orders 
        ADD COLUMN amount_paise BIGINT;
    END IF;

    -- payment_ref: external payment transaction reference / UPI RRN / Gateway Payment ID
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'payment_ref'
    ) THEN
        ALTER TABLE public.orders 
        ADD COLUMN payment_ref VARCHAR(255);
    END IF;

    -- idempotency_key: unique key preventing duplicate order placement or duplicate callback processing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'idempotency_key'
    ) THEN
        ALTER TABLE public.orders 
        ADD COLUMN idempotency_key VARCHAR(255);
    END IF;

    -- paid_at: timestamp when payment was verified by a trusted server authority or cash collected upon delivery
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'paid_at'
    ) THEN
        ALTER TABLE public.orders 
        ADD COLUMN paid_at TIMESTAMPTZ;
    END IF;
END $$;

-- 2. Backfill existing orders safely without fabricating payment records
-- RATIONALE & ACCOUNTING AUDIT SAFETY:
-- Delivery is NOT definitive proof that cash was collected and reconciled.
-- Legacy database records lack explicit cash collection receipts, driver remittance logs, or paid_at timestamps.
-- Falsely recording delivered orders as 'paid' and fabricating paid_at timestamps corrupts financial ledgers
-- and tax audits. Therefore, legacy COD orders remain 'cod_due' until authorized collection is explicitly verified.
UPDATE public.orders
SET 
    payment_status = 'cod_due',
    currency = COALESCE(currency, 'INR'),
    amount_paise = COALESCE(amount_paise, ROUND(COALESCE(total_price, 0) * 100)),
    paid_at = NULL
WHERE payment_method = 'cod' 
  AND status != 'cancelled' 
  AND (payment_status IS NULL OR payment_status = 'pending');

-- Legacy cancelled orders are backfilled as 'cancelled'
UPDATE public.orders
SET 
    payment_status = 'cancelled',
    currency = COALESCE(currency, 'INR'),
    amount_paise = COALESCE(amount_paise, ROUND(COALESCE(total_price, 0) * 100))
WHERE status = 'cancelled' 
  AND (payment_status IS NULL OR payment_status != 'cancelled');

-- Legacy unverified online/UPI orders remain 'pending'
UPDATE public.orders
SET 
    payment_status = 'pending',
    currency = COALESCE(currency, 'INR'),
    amount_paise = COALESCE(amount_paise, ROUND(COALESCE(total_price, 0) * 100))
WHERE (payment_method = 'upi' OR payment_method IS NULL)
  AND status != 'cancelled'
  AND payment_status IS NULL;

-- 3. Add CHECK constraints to enforce valid states
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_orders_payment_status'
    ) THEN
        ALTER TABLE public.orders DROP CONSTRAINT chk_orders_payment_status;
    END IF;

    ALTER TABLE public.orders 
    ADD CONSTRAINT chk_orders_payment_status 
    CHECK (payment_status IN ('pending', 'cod_due', 'initiated', 'verification_pending', 'paid', 'failed', 'cancelled'));

    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_orders_currency'
    ) THEN
        ALTER TABLE public.orders DROP CONSTRAINT chk_orders_currency;
    END IF;

    ALTER TABLE public.orders
    ADD CONSTRAINT chk_orders_currency
    CHECK (currency = 'INR');
END $$;

-- 4. Unique index for idempotency keys (allows NULLs)
CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_idempotency_key 
ON public.orders (idempotency_key) 
WHERE idempotency_key IS NOT NULL;

-- 5. Row Level Security (RLS) Neutralization & Policies
-- Ensure RLS is active on public.orders
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Dynamic Cleanup: Drop ANY pre-existing UPDATE policies on public.orders.
-- Why? In PostgreSQL, multiple PERMISSIVE policies combine with logical OR.
-- If any pre-existing permissive policy allowed updating rows (e.g., "Users can update own orders"),
-- it would bypass our new restrictive policies. We purge all legacy update policies first.
DO $$
DECLARE
    pol record;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE schemaname = 'public' AND tablename = 'orders' AND cmd = 'UPDATE'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.orders', pol.policyname);
    END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- Policy 1: SELECT for Buyers
-- Authenticated buyers can view their own orders.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Buyers can view their own orders" ON public.orders;
CREATE POLICY "Buyers can view their own orders"
ON public.orders
FOR SELECT
TO authenticated
USING (auth.uid() = buyer_id);

-- -----------------------------------------------------------------------------
-- Policy 2: SELECT for Farmers
-- Authenticated farmers can view orders placed for their farm products.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Farmers can view orders for their products" ON public.orders;
CREATE POLICY "Farmers can view orders for their products"
ON public.orders
FOR SELECT
TO authenticated
USING (auth.uid() = farmer_id);

-- -----------------------------------------------------------------------------
-- Policy 3: SELECT for Admins
-- Administrators can view all orders across the platform.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins can view all orders" ON public.orders;
CREATE POLICY "Admins can view all orders"
ON public.orders
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
);

-- -----------------------------------------------------------------------------
-- Policy 4: INSERT for Buyers
-- Rules:
--   - buyer_id must equal auth.uid()
--   - payment_status cannot be 'paid'
--   - paid_at and payment_ref must be NULL on insert
--   - COD orders MUST start in 'cod_due'
--   - UPI orders MUST start in 'pending'
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Buyers can insert new orders" ON public.orders;
CREATE POLICY "Buyers can insert new orders"
ON public.orders
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = buyer_id 
    AND payment_status != 'paid'
    AND paid_at IS NULL
    AND payment_ref IS NULL
    AND (
        (payment_method = 'cod' AND payment_status = 'cod_due')
        OR 
        (payment_method = 'upi' AND payment_status = 'pending')
    )
);

-- -----------------------------------------------------------------------------
-- Policy 5: Permissive UPDATE for Buyers (Order Cancellation Only)
-- Buyers can ONLY update an order to cancel it before dispatch.
-- -----------------------------------------------------------------------------
CREATE POLICY "Buyers can only cancel their own orders"
ON public.orders
FOR UPDATE
TO authenticated
USING (auth.uid() = buyer_id)
WITH CHECK (
    auth.uid() = buyer_id 
    AND status = 'cancelled'
    AND payment_status = 'cancelled'
);

-- -----------------------------------------------------------------------------
-- Policy 6: Permissive UPDATE for Farmers (Fulfillment Only)
-- Farmers can update fulfillment status ('confirmed', 'delivered', 'cancelled'),
-- but cannot set payment_status to 'paid'.
-- -----------------------------------------------------------------------------
CREATE POLICY "Farmers can only update fulfillment status"
ON public.orders
FOR UPDATE
TO authenticated
USING (auth.uid() = farmer_id)
WITH CHECK (
    auth.uid() = farmer_id
    AND status IN ('confirmed', 'delivered', 'cancelled')
    AND payment_status != 'paid'
);

-- -----------------------------------------------------------------------------
-- Policy 7: RESTRICTIVE UPDATE Policy (Defense-in-Depth)
-- Combined with logical AND across all permissive policies.
-- Guarantees that no permissive policy can ever allow a non-service_role client
-- to set payment_status to 'paid'.
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Enforce payment status immutability for clients" ON public.orders;
CREATE POLICY "Enforce payment status immutability for clients"
ON public.orders
AS RESTRICTIVE
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (
    (current_setting('request.jwt.claim.role', true) = 'service_role')
    OR 
    (payment_status != 'paid')
);

-- 6. PostgreSQL Trigger: Column-Level Integrity & Mutation Protection
-- RLS checks row-level filters; triggers compare OLD vs NEW columns directly.
-- This trigger blocks all column tampering (buyer_id, amount_paise, total_price, etc.)
-- and strictly blocks ordinary clients from setting paid_at, payment_ref, or payment_status='paid'.
CREATE OR REPLACE FUNCTION public.trg_orders_protect_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- 1. Privileged service_role and postgres superuser bypass all restrictions
    -- (used by Supabase Edge Functions, trusted webhooks, background accounting workers)
    IF (current_setting('request.jwt.claim.role', true) = 'service_role') 
       OR (current_user = 'postgres') THEN
        RETURN NEW;
    END IF;

    -- 2. Strictly immutable order fields for all clients (buyers, farmers, anonymous):
    IF NEW.id IS DISTINCT FROM OLD.id THEN
        RAISE EXCEPTION 'Field id is immutable';
    END IF;
    IF NEW.buyer_id IS DISTINCT FROM OLD.buyer_id THEN
        RAISE EXCEPTION 'Field buyer_id is immutable';
    END IF;
    IF NEW.farmer_id IS DISTINCT FROM OLD.farmer_id THEN
        RAISE EXCEPTION 'Field farmer_id is immutable';
    END IF;
    IF NEW.amount_paise IS DISTINCT FROM OLD.amount_paise THEN
        RAISE EXCEPTION 'Field amount_paise is immutable';
    END IF;
    IF NEW.total_price IS DISTINCT FROM OLD.total_price THEN
        RAISE EXCEPTION 'Field total_price is immutable';
    END IF;
    IF NEW.currency IS DISTINCT FROM OLD.currency THEN
        RAISE EXCEPTION 'Field currency is immutable';
    END IF;
    IF NEW.payment_method IS DISTINCT FROM OLD.payment_method THEN
        RAISE EXCEPTION 'Field payment_method is immutable';
    END IF;
    IF NEW.idempotency_key IS DISTINCT FROM OLD.idempotency_key THEN
        RAISE EXCEPTION 'Field idempotency_key is immutable';
    END IF;
    IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'Field created_at is immutable';
    END IF;

    -- 3. Payment settlement fields cannot be manipulated by client-side tokens
    IF NEW.payment_status = 'paid' AND OLD.payment_status IS DISTINCT FROM 'paid' THEN
        RAISE EXCEPTION 'payment_status cannot be changed to paid by client. Payment verification and COD collection must be recorded via privileged backend service_role.';
    END IF;
    IF NEW.paid_at IS DISTINCT FROM OLD.paid_at THEN
        RAISE EXCEPTION 'Field paid_at cannot be modified by client';
    END IF;
    IF NEW.payment_ref IS DISTINCT FROM OLD.payment_ref THEN
        RAISE EXCEPTION 'Field payment_ref cannot be modified by client';
    END IF;

    -- 4. Role-specific mutation checks:
    -- Buyer role:
    IF auth.uid() = OLD.buyer_id THEN
        -- Buyer can ONLY transition to 'cancelled' if order is in a cancellable state
        IF NEW.status IS DISTINCT FROM OLD.status THEN
            IF NEW.status != 'cancelled' THEN
                RAISE EXCEPTION 'Buyers can only update order status to cancelled';
            END IF;
            IF OLD.status IN ('delivered', 'cancelled') THEN
                RAISE EXCEPTION 'Cannot cancel an order that is already %', OLD.status;
            END IF;
        END IF;
        IF NEW.payment_status IS DISTINCT FROM OLD.payment_status THEN
            IF NEW.payment_status != 'cancelled' THEN
                RAISE EXCEPTION 'Buyers can only update payment_status to cancelled';
            END IF;
        END IF;
        RETURN NEW;
    END IF;

    -- Farmer role:
    IF auth.uid() = OLD.farmer_id THEN
        -- Farmer CANNOT modify payment_status under any circumstance!
        IF NEW.payment_status IS DISTINCT FROM OLD.payment_status THEN
            RAISE EXCEPTION 'Farmers cannot modify payment_status. Payment collection must be recorded via authorized service role.';
        END IF;
        -- Farmer can ONLY update fulfillment status (confirmed -> delivered or cancelled)
        IF NEW.status IS DISTINCT FROM OLD.status THEN
            IF NEW.status NOT IN ('confirmed', 'delivered', 'cancelled') THEN
                RAISE EXCEPTION 'Invalid status transition for farmer: %', NEW.status;
            END IF;
        END IF;
        RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Unauthorized update on orders table';
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_protect_columns ON public.orders;
CREATE TRIGGER trg_orders_protect_columns
BEFORE UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.trg_orders_protect_columns();

-- -----------------------------------------------------------------------------
-- 7. Privileged Backend Service Role Notice
-- Supabase Edge Functions and backend processes connect using the service_role
-- secret key, which automatically bypasses PostgreSQL RLS policies and trigger
-- restrictions to update payment_status to 'paid' upon verified webhook signatures
-- or recorded cash collection receipts.
-- -----------------------------------------------------------------------------
