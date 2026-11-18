-- ==============================================================================
-- BlueFarm Automated Email Notification System & Delivery Engine
-- Migration: 20261117000000_automated_email_notifications.sql
-- Database: PostgreSQL (Supabase)
-- Target Tables: public.email_notifications, public.app_config
-- Dependent Tables: public.profiles, public.orders, public.listings, public.account_deletion_requests
-- ==============================================================================

-- 1. Optional extension support
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
EXCEPTION WHEN OTHERS THEN
    -- Ignore if already present or permission restricted
    NULL;
END $$;

-- 2. Create app_config table for centralized settings (like admin notification email)
CREATE TABLE IF NOT EXISTS public.app_config (
    key VARCHAR(100) PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Seed BlueFarm admin email
INSERT INTO public.app_config (key, value, description)
VALUES ('admin_email', 'bluefarm1572@gmail.com', 'Primary BlueFarm administrative notification recipient')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

INSERT INTO public.app_config (key, value, description)
VALUES ('sender_email', 'bluefarm1572@gmail.com', 'Verified sender email for BlueFarm transactional notifications')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

INSERT INTO public.app_config (key, value, description)
VALUES ('sender_name', 'BlueFarm', 'Display sender name for transactional emails')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- Enable RLS on app_config
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Allow public read on app_config" ON public.app_config;
    CREATE POLICY "Allow public read on app_config" ON public.app_config FOR SELECT USING (true);
    
    DROP POLICY IF EXISTS "Service role full access on app_config" ON public.app_config;
    CREATE POLICY "Service role full access on app_config" ON public.app_config FOR ALL TO service_role USING (true) WITH CHECK (true);
END $$;

-- 3. Create public.email_notifications table for queueing, logging, and idempotency
CREATE TABLE IF NOT EXISTS public.email_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(50) NOT NULL CHECK (event_type IN ('user_registration', 'new_order', 'order_cancellation', 'new_harvest', 'account_deletion')),
    recipient_email VARCHAR(255) NOT NULL,
    recipient_name VARCHAR(255),
    recipient_role VARCHAR(50) NOT NULL CHECK (recipient_role IN ('buyer', 'farmer', 'admin', 'user')),
    subject TEXT NOT NULL,
    html_content TEXT NOT NULL,
    text_content TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
    provider VARCHAR(50),
    provider_message_id TEXT,
    error_message TEXT,
    retry_count INT NOT NULL DEFAULT 0,
    max_retries INT NOT NULL DEFAULT 3,
    idempotency_key VARCHAR(255) UNIQUE,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    sent_at TIMESTAMPTZ,
    last_attempt_at TIMESTAMPTZ
);

-- Helpful indexes for querying queue and debugging
CREATE INDEX IF NOT EXISTS idx_email_notifications_pending 
ON public.email_notifications(status, created_at) 
WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_email_notifications_event_type 
ON public.email_notifications(event_type);

CREATE INDEX IF NOT EXISTS idx_email_notifications_recipient 
ON public.email_notifications(recipient_email);

-- Enable Row Level Security (RLS)
ALTER TABLE public.email_notifications ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Service role has full management on email_notifications" ON public.email_notifications;
    CREATE POLICY "Service role has full management on email_notifications" 
    ON public.email_notifications FOR ALL TO service_role USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Users can view their own email notifications" ON public.email_notifications;
    CREATE POLICY "Users can view their own email notifications" 
    ON public.email_notifications FOR SELECT TO authenticated
    USING (recipient_email = (auth.jwt() ->> 'email'));
END $$;

-- Helper function to get config value
CREATE OR REPLACE FUNCTION public.fn_get_app_config(p_key VARCHAR(100), p_default TEXT DEFAULT '')
RETURNS TEXT LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_val TEXT;
BEGIN
    SELECT value INTO v_val FROM public.app_config WHERE key = p_key;
    RETURN COALESCE(v_val, p_default);
END;
$$;

-- ==============================================================================
-- 4. Trigger Function A: New User Registration
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.fn_on_user_registration_email()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_admin_email TEXT;
    v_clean_name TEXT;
    v_user_email TEXT;
    v_role_title TEXT;
    v_created_time TEXT;
BEGIN
    -- Only proceed if user has a valid name and role
    IF NEW.full_name IS NULL OR TRIM(NEW.full_name) = '' THEN
        RETURN NEW;
    END IF;

    v_admin_email := public.fn_get_app_config('admin_email', 'bluefarm1572@gmail.com');
    v_clean_name := TRIM(NEW.full_name);
    v_user_email := NULLIF(TRIM(COALESCE(NEW.email, '')), '');
    v_role_title := CASE 
        WHEN LOWER(COALESCE(NEW.role, '')) = 'farmer' THEN 'Aquaculture Farmer'
        WHEN LOWER(COALESCE(NEW.role, '')) = 'buyer' THEN 'Fish Buyer / Exporter'
        ELSE 'Member'
    END;
    v_created_time := to_char(COALESCE(NEW.created_at, now()), 'YYYY-MM-DD HH24:MI:SS') || ' UTC';

    -- 1. Queue Welcome Email to the User (if valid email provided)
    IF v_user_email IS NOT NULL AND v_user_email LIKE '%@%' AND NOT v_user_email ~* '^\d+@' THEN
        INSERT INTO public.email_notifications (
            event_type,
            recipient_email,
            recipient_name,
            recipient_role,
            subject,
            html_content,
            text_content,
            idempotency_key,
            metadata
        ) VALUES (
            'user_registration',
            v_user_email,
            v_clean_name,
            CASE WHEN LOWER(COALESCE(NEW.role, '')) = 'buyer' THEN 'buyer' ELSE 'farmer' END,
            'Welcome to BlueFarm, ' || v_clean_name || '! Your Account is Ready 🐟',
            '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">' ||
              '<div style="background-color: #0d4f7c; padding: 24px; text-align: center; border-radius: 8px 8px 0 0;">' ||
                '<h1 style="color: #ffffff; margin: 0; font-size: 22px;">Welcome to BlueFarm!</h1>' ||
                '<p style="color: #93c5fd; margin: 6px 0 0 0; font-size: 14px;">Next-Gen Aquaculture Marketplace & Monitoring</p>' ||
              '</div>' ||
              '<div style="padding: 24px; color: #334155; line-height: 1.6;">' ||
                '<p>Hello <strong>' || v_clean_name || '</strong>,</p>' ||
                '<p>Your BlueFarm account has been created successfully as a <strong>' || v_role_title || '</strong>.</p>' ||
                '<div style="background-color: #f0f9ff; border-left: 4px solid #0284c7; padding: 14px; border-radius: 6px; margin: 20px 0;">' ||
                  '<p style="margin: 0; font-size: 14px;"><strong>Account Type:</strong> ' || v_role_title || '<br/>' ||
                  '<strong>Registered Email:</strong> ' || v_user_email || '<br/>' ||
                  '<strong>Registration Date:</strong> ' || v_created_time || '</p>' ||
                '</div>' ||
                '<p>You can now manage your farm ponds, monitor real-time water quality telemetry, explore nearby fish markets, and connect directly with verified buyers and farmers.</p>' ||
                '<p style="margin-top: 24px; font-size: 13px; color: #64748b;">Need help? Reply directly to this email or contact <a href="mailto:bluefarm1572@gmail.com" style="color: #0284c7;">bluefarm1572@gmail.com</a>.</p>' ||
              '</div>' ||
              '<div style="padding: 16px; background-color: #f8fafc; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; border-radius: 0 0 8px 8px;">' ||
                '&copy; ' || to_char(now(), 'YYYY') || ' BlueFarm Aquaculture Technologies · All rights reserved.' ||
              '</div>' ||
            '</div>',
            'Welcome to BlueFarm, ' || v_clean_name || '! Your account as ' || v_role_title || ' is ready. Registered email: ' || v_user_email,
            'reg_user_' || NEW.id::text,
            jsonb_build_object('user_id', NEW.id, 'role', NEW.role, 'email', v_user_email)
        )
        ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;

    -- 2. Queue Admin Alert to bluefarm1572@gmail.com
    INSERT INTO public.email_notifications (
        event_type,
        recipient_email,
        recipient_name,
        recipient_role,
        subject,
        html_content,
        text_content,
        idempotency_key,
        metadata
    ) VALUES (
        'user_registration',
        v_admin_email,
        'BlueFarm Admin',
        'admin',
        '[BlueFarm Admin] New ' || v_role_title || ' Registration: ' || v_clean_name,
        '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">' ||
          '<div style="background-color: #0f172a; padding: 20px; text-align: center; border-radius: 8px 8px 0 0;">' ||
            '<h2 style="color: #ffffff; margin: 0; font-size: 18px;">New User Registration Alert</h2>' ||
            '<p style="color: #94a3b8; margin: 4px 0 0 0; font-size: 13px;">BlueFarm Admin Operations</p>' ||
          '</div>' ||
          '<div style="padding: 24px; color: #334155; line-height: 1.6;">' ||
            '<p>A new user has just registered on the BlueFarm platform:</p>' ||
            '<table style="width: 100%; border-collapse: collapse; font-size: 14px; margin: 16px 0;">' ||
              '<tr><td style="padding: 8px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>User Name:</strong></td><td style="padding: 8px 0; border-bottom: 1px solid #f1f5f9; font-weight: bold; color: #0f172a;">' || v_clean_name || '</td></tr>' ||
              '<tr><td style="padding: 8px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Account Role:</strong></td><td style="padding: 8px 0; border-bottom: 1px solid #f1f5f9;">' || v_role_title || '</td></tr>' ||
              '<tr><td style="padding: 8px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Registered Email:</strong></td><td style="padding: 8px 0; border-bottom: 1px solid #f1f5f9;">' || COALESCE(v_user_email, 'Not provided') || '</td></tr>' ||
              '<tr><td style="padding: 8px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Phone:</strong></td><td style="padding: 8px 0; border-bottom: 1px solid #f1f5f9;">' || COALESCE(NEW.phone, 'Not provided') || '</td></tr>' ||
              '<tr><td style="padding: 8px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Region / Location:</strong></td><td style="padding: 8px 0; border-bottom: 1px solid #f1f5f9;">' || COALESCE(NEW.region, 'Not provided') || '</td></tr>' ||
              '<tr><td style="padding: 8px 0; color: #64748b;"><strong>Registration Date:</strong></td><td style="padding: 8px 0;">' || v_created_time || '</td></tr>' ||
            '</table>' ||
          '</div>' ||
          '<div style="padding: 14px; background-color: #f8fafc; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; border-radius: 0 0 8px 8px;">' ||
            'BlueFarm Automatic Administration Notification' ||
          '</div>' ||
        '</div>',
        'New registration: ' || v_clean_name || ' as ' || v_role_title || '. Email: ' || COALESCE(v_user_email, 'None') || ', Phone: ' || COALESCE(NEW.phone, 'None'),
        'reg_admin_' || NEW.id::text,
        jsonb_build_object('user_id', NEW.id, 'role', NEW.role, 'email', v_user_email)
    )
    ON CONFLICT (idempotency_key) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_new_user_registration ON public.profiles;
CREATE TRIGGER trg_notify_new_user_registration
AFTER INSERT OR UPDATE OF full_name, role, email ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.fn_on_user_registration_email();

-- ==============================================================================
-- 5. Trigger Function B: New Order Placement
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.fn_on_new_order_email()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_admin_email TEXT;
    v_buyer_name TEXT := 'Valued Buyer';
    v_buyer_email TEXT;
    v_buyer_phone TEXT;
    v_farmer_name TEXT := 'Fish Farmer';
    v_farmer_email TEXT;
    v_farmer_phone TEXT;
    v_farm_name TEXT;
    v_order_id TEXT;
    v_species TEXT;
    v_qty TEXT;
    v_price TEXT;
    v_total TEXT;
    v_pay_method TEXT;
    v_address TEXT;
    v_created_time TEXT;
BEGIN
    v_admin_email := public.fn_get_app_config('admin_email', 'bluefarm1572@gmail.com');
    v_order_id := UPPER(SUBSTRING(REPLACE(NEW.id::text, '-', ''), 1, 8));
    v_species := COALESCE(NEW.species, 'Aquaculture Produce');
    v_qty := ROUND(COALESCE(NEW.quantity_kg, 1.0)::numeric, 2)::text || ' kg';
    v_price := '₹' || ROUND(COALESCE(NEW.price_per_kg, 0.0)::numeric, 2)::text || ' / kg';
    v_total := '₹' || ROUND(COALESCE(NEW.total_price, 0.0)::numeric, 2)::text;
    v_pay_method := UPPER(COALESCE(NEW.payment_method, 'COD'));
    v_address := COALESCE(NEW.delivery_address, 'Address on file');
    v_created_time := to_char(COALESCE(NEW.created_at, now()), 'YYYY-MM-DD HH24:MI:SS') || ' UTC';

    -- Fetch Buyer Details
    IF NEW.buyer_id IS NOT NULL THEN
        SELECT full_name, email, phone 
        INTO v_buyer_name, v_buyer_email, v_buyer_phone
        FROM public.profiles 
        WHERE id = NEW.buyer_id;
    END IF;

    -- Fetch Farmer Details
    IF NEW.farmer_id IS NOT NULL THEN
        SELECT full_name, email, phone, farm_name 
        INTO v_farmer_name, v_farmer_email, v_farmer_phone, v_farm_name
        FROM public.profiles 
        WHERE id = NEW.farmer_id;
    END IF;

    v_farm_name := COALESCE(v_farm_name, NEW.farm_name, 'BlueFarm Partner');
    v_buyer_name := COALESCE(NULLIF(TRIM(v_buyer_name), ''), 'BlueFarm Buyer');
    v_farmer_name := COALESCE(NULLIF(TRIM(v_farmer_name), ''), 'BlueFarm Farmer');

    -- 1. Queue Buyer Order Confirmation Email
    IF v_buyer_email IS NOT NULL AND v_buyer_email LIKE '%@%' AND NOT v_buyer_email ~* '^\d+@' THEN
        INSERT INTO public.email_notifications (
            event_type,
            recipient_email,
            recipient_name,
            recipient_role,
            subject,
            html_content,
            text_content,
            idempotency_key,
            metadata
        ) VALUES (
            'new_order',
            v_buyer_email,
            v_buyer_name,
            'buyer',
            'Order Confirmed: #' || v_order_id || ' - ' || v_species || ' (' || v_qty || ') 📦',
            '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">' ||
              '<div style="background-color: #059669; padding: 24px; text-align: center; border-radius: 8px 8px 0 0;">' ||
                '<h2 style="color: #ffffff; margin: 0; font-size: 20px;">Order Placed Successfully!</h2>' ||
                '<p style="color: #a7f3d0; margin: 4px 0 0 0; font-size: 14px;">Order ID: #' || v_order_id || '</p>' ||
              '</div>' ||
              '<div style="padding: 24px; color: #334155; line-height: 1.6;">' ||
                '<p>Hello <strong>' || v_buyer_name || '</strong>,</p>' ||
                '<p>Thank you for purchasing on BlueFarm! Your order has been placed and sent to the farmer for dispatch.</p>' ||
                '<div style="background-color: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 16px; margin: 20px 0;">' ||
                  '<table style="width: 100%; border-collapse: collapse; font-size: 14px;">' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Fish Species:</strong></td><td style="padding: 6px 0; font-weight: bold; color: #0f172a;">' || v_species || '</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Quantity:</strong></td><td style="padding: 6px 0;">' || v_qty || '</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Unit Price:</strong></td><td style="padding: 6px 0;">' || v_price || '</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Total Amount:</strong></td><td style="padding: 6px 0; font-size: 16px; font-weight: bold; color: #059669;">' || v_total || '</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Payment Mode:</strong></td><td style="padding: 6px 0;">' || v_pay_method || '</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Farmer / Farm:</strong></td><td style="padding: 6px 0;">' || v_farmer_name || ' (' || v_farm_name || ')</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Delivery Address:</strong></td><td style="padding: 6px 0;">' || v_address || '</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Order Date:</strong></td><td style="padding: 6px 0;">' || v_created_time || '</td></tr>' ||
                  '</table>' ||
                '</div>' ||
                '<p style="font-size: 13px; color: #64748b;">You can track order status in the BlueFarm app under the <strong>Orders</strong> tab.</p>' ||
              '</div>' ||
              '<div style="padding: 14px; background-color: #f8fafc; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; border-radius: 0 0 8px 8px;">' ||
                '&copy; ' || to_char(now(), 'YYYY') || ' BlueFarm Marketplace · Support: bluefarm1572@gmail.com' ||
              '</div>' ||
            '</div>',
            'Order #' || v_order_id || ' confirmed for ' || v_species || ' (' || v_qty || '). Total: ' || v_total || ', Payment: ' || v_pay_method,
            'order_buyer_' || NEW.id::text,
            jsonb_build_object('order_id', NEW.id, 'buyer_id', NEW.buyer_id, 'farmer_id', NEW.farmer_id)
        )
        ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;

    -- 2. Queue Farmer New Order Notification Email
    IF v_farmer_email IS NOT NULL AND v_farmer_email LIKE '%@%' AND NOT v_farmer_email ~* '^\d+@' THEN
        INSERT INTO public.email_notifications (
            event_type,
            recipient_email,
            recipient_name,
            recipient_role,
            subject,
            html_content,
            text_content,
            idempotency_key,
            metadata
        ) VALUES (
            'new_order',
            v_farmer_email,
            v_farmer_name,
            'farmer',
            'New Order Received: #' || v_order_id || ' - ' || v_species || ' (' || v_qty || ') 🚀',
            '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">' ||
              '<div style="background-color: #1565c0; padding: 24px; text-align: center; border-radius: 8px 8px 0 0;">' ||
                '<h2 style="color: #ffffff; margin: 0; font-size: 20px;">You Received a New Order!</h2>' ||
                '<p style="color: #bfdbfe; margin: 4px 0 0 0; font-size: 14px;">Order ID: #' || v_order_id || '</p>' ||
              '</div>' ||
              '<div style="padding: 24px; color: #334155; line-height: 1.6;">' ||
                '<p>Hello <strong>' || v_farmer_name || '</strong>,</p>' ||
                '<p>Great news! A buyer has placed an order for your aquaculture harvest:</p>' ||
                '<div style="background-color: #eff6ff; border: 1px solid #bfdbfe; border-radius: 8px; padding: 16px; margin: 20px 0;">' ||
                  '<table style="width: 100%; border-collapse: collapse; font-size: 14px;">' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Species:</strong></td><td style="padding: 6px 0; font-weight: bold; color: #0f172a;">' || v_species || '</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Quantity:</strong></td><td style="padding: 6px 0;">' || v_qty || '</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Rate:</strong></td><td style="padding: 6px 0;">' || v_price || '</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Total Payout:</strong></td><td style="padding: 6px 0; font-size: 16px; font-weight: bold; color: #1565c0;">' || v_total || '</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Payment Mode:</strong></td><td style="padding: 6px 0;">' || v_pay_method || '</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Buyer Name:</strong></td><td style="padding: 6px 0;">' || v_buyer_name || '</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Delivery Destination:</strong></td><td style="padding: 6px 0;">' || v_address || '</td></tr>' ||
                  '</table>' ||
                '</div>' ||
                '<p style="font-size: 13px; color: #64748b;">Please prepare the stock for harvest and dispatch according to schedule.</p>' ||
              '</div>' ||
              '<div style="padding: 14px; background-color: #f8fafc; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; border-radius: 0 0 8px 8px;">' ||
                '&copy; ' || to_char(now(), 'YYYY') || ' BlueFarm Aquaculture Technologies · Farmer Order Desk' ||
              '</div>' ||
            '</div>',
            'New order #' || v_order_id || ' received from ' || v_buyer_name || ' for ' || v_species || ' (' || v_qty || '). Payout: ' || v_total,
            'order_farmer_' || NEW.id::text,
            jsonb_build_object('order_id', NEW.id, 'buyer_id', NEW.buyer_id, 'farmer_id', NEW.farmer_id)
        )
        ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;

    -- 3. Queue Admin Alert to bluefarm1572@gmail.com
    INSERT INTO public.email_notifications (
        event_type,
        recipient_email,
        recipient_name,
        recipient_role,
        subject,
        html_content,
        text_content,
        idempotency_key,
        metadata
    ) VALUES (
        'new_order',
        v_admin_email,
        'BlueFarm Admin',
        'admin',
        '[BlueFarm Admin] New Order #' || v_order_id || ' Placed: ' || v_total,
        '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">' ||
          '<div style="background-color: #0f172a; padding: 20px; text-align: center; border-radius: 8px 8px 0 0;">' ||
            '<h2 style="color: #ffffff; margin: 0; font-size: 18px;">New Order Notice</h2>' ||
            '<p style="color: #94a3b8; margin: 4px 0 0 0; font-size: 13px;">Marketplace Order #' || v_order_id || '</p>' ||
          '</div>' ||
          '<div style="padding: 24px; color: #334155; line-height: 1.6;">' ||
            '<p>A new marketplace trade has been created:</p>' ||
            '<table style="width: 100%; border-collapse: collapse; font-size: 14px; margin: 16px 0;">' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Order ID:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; font-weight: bold;">' || v_order_id || '</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Item:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9;">' || v_species || ' (' || v_qty || ')</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Total Price:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; font-weight: bold; color: #059669;">' || v_total || '</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Payment Mode:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9;">' || v_pay_method || '</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Buyer:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9;">' || v_buyer_name || ' (' || COALESCE(v_buyer_email, 'No email') || ', ' || COALESCE(v_buyer_phone, 'No phone') || ')</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Farmer:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9;">' || v_farmer_name || ' (' || COALESCE(v_farmer_email, 'No email') || ', ' || COALESCE(v_farmer_phone, 'No phone') || ')</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Delivery Address:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9;">' || v_address || '</td></tr>' ||
              '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Timestamp:</strong></td><td style="padding: 6px 0;">' || v_created_time || '</td></tr>' ||
            '</table>' ||
          '</div>' ||
          '<div style="padding: 14px; background-color: #f8fafc; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; border-radius: 0 0 8px 8px;">' ||
            'BlueFarm Automatic Order Logging' ||
          '</div>' ||
        '</div>',
        'New order #' || v_order_id || ' placed. Buyer: ' || v_buyer_name || ', Farmer: ' || v_farmer_name || ', Total: ' || v_total || ', Species: ' || v_species || ' (' || v_qty || ')',
        'order_admin_' || NEW.id::text,
        jsonb_build_object('order_id', NEW.id, 'buyer_id', NEW.buyer_id, 'farmer_id', NEW.farmer_id)
    )
    ON CONFLICT (idempotency_key) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_new_order ON public.orders;
CREATE TRIGGER trg_notify_new_order
AFTER INSERT ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.fn_on_new_order_email();

-- ==============================================================================
-- 6. Trigger Function C: Order Cancellation
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.fn_on_order_cancelled_email()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_admin_email TEXT;
    v_buyer_name TEXT := 'Valued Buyer';
    v_buyer_email TEXT;
    v_farmer_name TEXT := 'Fish Farmer';
    v_farmer_email TEXT;
    v_order_id TEXT;
    v_species TEXT;
    v_qty TEXT;
    v_total TEXT;
    v_cancel_time TEXT;
BEGIN
    -- Only fire when status transitioned to 'cancelled'
    IF NEW.status != 'cancelled' OR (OLD.status IS NOT NULL AND OLD.status = 'cancelled') THEN
        RETURN NEW;
    END IF;

    v_admin_email := public.fn_get_app_config('admin_email', 'bluefarm1572@gmail.com');
    v_order_id := UPPER(SUBSTRING(REPLACE(NEW.id::text, '-', ''), 1, 8));
    v_species := COALESCE(NEW.species, 'Aquaculture Produce');
    v_qty := ROUND(COALESCE(NEW.quantity_kg, 1.0)::numeric, 2)::text || ' kg';
    v_total := '₹' || ROUND(COALESCE(NEW.total_price, 0.0)::numeric, 2)::text;
    v_cancel_time := to_char(now(), 'YYYY-MM-DD HH24:MI:SS') || ' UTC';

    -- Fetch Buyer Details
    IF NEW.buyer_id IS NOT NULL THEN
        SELECT full_name, email INTO v_buyer_name, v_buyer_email
        FROM public.profiles WHERE id = NEW.buyer_id;
    END IF;

    -- Fetch Farmer Details
    IF NEW.farmer_id IS NOT NULL THEN
        SELECT full_name, email INTO v_farmer_name, v_farmer_email
        FROM public.profiles WHERE id = NEW.farmer_id;
    END IF;

    v_buyer_name := COALESCE(NULLIF(TRIM(v_buyer_name), ''), 'BlueFarm Buyer');
    v_farmer_name := COALESCE(NULLIF(TRIM(v_farmer_name), ''), 'BlueFarm Farmer');

    -- 1. Notify Buyer of Cancellation
    IF v_buyer_email IS NOT NULL AND v_buyer_email LIKE '%@%' AND NOT v_buyer_email ~* '^\d+@' THEN
        INSERT INTO public.email_notifications (
            event_type,
            recipient_email,
            recipient_name,
            recipient_role,
            subject,
            html_content,
            text_content,
            idempotency_key,
            metadata
        ) VALUES (
            'order_cancellation',
            v_buyer_email,
            v_buyer_name,
            'buyer',
            'Order Cancelled: #' || v_order_id || ' - ' || v_species,
            '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">' ||
              '<div style="background-color: #dc2626; padding: 20px; text-align: center; border-radius: 8px 8px 0 0;">' ||
                '<h2 style="color: #ffffff; margin: 0; font-size: 20px;">Order Cancelled</h2>' ||
                '<p style="color: #fecaca; margin: 4px 0 0 0; font-size: 14px;">Order ID: #' || v_order_id || '</p>' ||
              '</div>' ||
              '<div style="padding: 24px; color: #334155; line-height: 1.6;">' ||
                '<p>Hello <strong>' || v_buyer_name || '</strong>,</p>' ||
                '<p>Your order for <strong>' || v_species || ' (' || v_qty || ')</strong> has been marked as cancelled.</p>' ||
                '<div style="background-color: #fef2f2; border: 1px solid #fecaca; border-radius: 8px; padding: 14px; margin: 16px 0;">' ||
                  '<p style="margin: 0; font-size: 14px; color: #991b1b;">' ||
                    '<strong>Order Amount:</strong> ' || v_total || '<br/>' ||
                    '<strong>Cancelled At:</strong> ' || v_cancel_time || '<br/>' ||
                    'If any prepaid amount was collected, your refund will be processed in accordance with BlueFarm terms.' ||
                  '</p>' ||
                '</div>' ||
                '<p style="font-size: 13px; color: #64748b;">If you did not request this cancellation or have questions, contact <a href="mailto:bluefarm1572@gmail.com" style="color: #dc2626;">bluefarm1572@gmail.com</a>.</p>' ||
              '</div>' ||
              '<div style="padding: 14px; background-color: #f8fafc; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; border-radius: 0 0 8px 8px;">' ||
                '&copy; ' || to_char(now(), 'YYYY') || ' BlueFarm Marketplace' ||
              '</div>' ||
            '</div>',
            'Your order #' || v_order_id || ' for ' || v_species || ' has been cancelled.',
            'cancel_buyer_' || NEW.id::text,
            jsonb_build_object('order_id', NEW.id, 'buyer_id', NEW.buyer_id)
        )
        ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;

    -- 2. Notify Farmer of Cancellation
    IF v_farmer_email IS NOT NULL AND v_farmer_email LIKE '%@%' AND NOT v_farmer_email ~* '^\d+@' THEN
        INSERT INTO public.email_notifications (
            event_type,
            recipient_email,
            recipient_name,
            recipient_role,
            subject,
            html_content,
            text_content,
            idempotency_key,
            metadata
        ) VALUES (
            'order_cancellation',
            v_farmer_email,
            v_farmer_name,
            'farmer',
            'Order Cancelled: #' || v_order_id || ' - ' || v_species,
            '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">' ||
              '<div style="background-color: #dc2626; padding: 20px; text-align: center; border-radius: 8px 8px 0 0;">' ||
                '<h2 style="color: #ffffff; margin: 0; font-size: 20px;">Order Cancellation Notice</h2>' ||
                '<p style="color: #fecaca; margin: 4px 0 0 0; font-size: 14px;">Order ID: #' || v_order_id || '</p>' ||
              '</div>' ||
              '<div style="padding: 24px; color: #334155; line-height: 1.6;">' ||
                '<p>Hello <strong>' || v_farmer_name || '</strong>,</p>' ||
                '<p>Please note that Order <strong>#' || v_order_id || '</strong> for <strong>' || v_species || ' (' || v_qty || ')</strong> has been cancelled.</p>' ||
                '<p>You do not need to prepare or ship this order. Your inventory has been updated accordingly.</p>' ||
              '</div>' ||
              '<div style="padding: 14px; background-color: #f8fafc; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; border-radius: 0 0 8px 8px;">' ||
                '&copy; ' || to_char(now(), 'YYYY') || ' BlueFarm Marketplace' ||
              '</div>' ||
            '</div>',
            'Order #' || v_order_id || ' for ' || v_species || ' has been cancelled. No shipment required.',
            'cancel_farmer_' || NEW.id::text,
            jsonb_build_object('order_id', NEW.id, 'farmer_id', NEW.farmer_id)
        )
        ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;

    -- 3. Notify Admin of Cancellation
    INSERT INTO public.email_notifications (
        event_type,
        recipient_email,
        recipient_name,
        recipient_role,
        subject,
        html_content,
        text_content,
        idempotency_key,
        metadata
    ) VALUES (
        'order_cancellation',
        v_admin_email,
        'BlueFarm Admin',
        'admin',
        '[BlueFarm Admin] Order #' || v_order_id || ' Cancelled',
        '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">' ||
          '<div style="background-color: #0f172a; padding: 20px; text-align: center; border-radius: 8px 8px 0 0;">' ||
            '<h2 style="color: #ffffff; margin: 0; font-size: 18px;">Order Cancellation Log</h2>' ||
            '<p style="color: #94a3b8; margin: 4px 0 0 0; font-size: 13px;">Order #' || v_order_id || '</p>' ||
          '</div>' ||
          '<div style="padding: 24px; color: #334155; line-height: 1.6;">' ||
            '<p>The following order has been cancelled:</p>' ||
            '<table style="width: 100%; border-collapse: collapse; font-size: 14px; margin: 16px 0;">' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Order ID:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; font-weight: bold;">' || v_order_id || '</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Produce:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9;">' || v_species || ' (' || v_qty || ')</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Value:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9;">' || v_total || '</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Buyer:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9;">' || v_buyer_name || ' (' || COALESCE(v_buyer_email, 'No email') || ')</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Farmer:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9;">' || v_farmer_name || ' (' || COALESCE(v_farmer_email, 'No email') || ')</td></tr>' ||
              '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Cancellation Time:</strong></td><td style="padding: 6px 0;">' || v_cancel_time || '</td></tr>' ||
            '</table>' ||
          '</div>' ||
          '<div style="padding: 14px; background-color: #f8fafc; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; border-radius: 0 0 8px 8px;">' ||
            'BlueFarm Automatic Order Audit Notification' ||
          '</div>' ||
        '</div>',
        'Order #' || v_order_id || ' cancelled. Produce: ' || v_species || ' (' || v_qty || '), Buyer: ' || v_buyer_name || ', Farmer: ' || v_farmer_name,
        'cancel_admin_' || NEW.id::text,
        jsonb_build_object('order_id', NEW.id)
    )
    ON CONFLICT (idempotency_key) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_order_cancellation ON public.orders;
CREATE TRIGGER trg_notify_order_cancellation
AFTER UPDATE OF status ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.fn_on_order_cancelled_email();

-- ==============================================================================
-- 7. Trigger Function D: New Harvest / Listing Published
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.fn_on_new_harvest_email()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_admin_email TEXT;
    v_farmer_name TEXT := 'Fish Farmer';
    v_farmer_email TEXT;
    v_farmer_phone TEXT;
    v_farm_name TEXT;
    v_region TEXT;
    v_species TEXT;
    v_qty TEXT;
    v_price TEXT;
    v_count TEXT;
    v_pond TEXT;
    v_created_time TEXT;
BEGIN
    -- Only trigger on active listings
    IF NEW.status IS NOT NULL AND NEW.status != 'active' THEN
        RETURN NEW;
    END IF;

    v_admin_email := public.fn_get_app_config('admin_email', 'bluefarm1572@gmail.com');
    v_species := COALESCE(NEW.species, 'Aquaculture Crop');
    v_qty := ROUND(COALESCE(NEW.quantity_kg, 1.0)::numeric, 2)::text || ' kg';
    v_price := '₹' || ROUND(COALESCE(NEW.price_per_kg, 0.0)::numeric, 2)::text || ' / kg';
    v_count := CASE WHEN NEW.fish_count IS NOT NULL THEN NEW.fish_count::text || ' fish' ELSE 'N/A' END;
    v_pond := COALESCE(NULLIF(TRIM(NEW.pond_number), ''), 'General Pond');
    v_created_time := to_char(COALESCE(NEW.created_at, now()), 'YYYY-MM-DD HH24:MI:SS') || ' UTC';

    -- Fetch Farmer Details
    IF NEW.farmer_id IS NOT NULL THEN
        SELECT full_name, email, phone, farm_name, region
        INTO v_farmer_name, v_farmer_email, v_farmer_phone, v_farm_name, v_region
        FROM public.profiles WHERE id = NEW.farmer_id;
    END IF;

    v_farmer_name := COALESCE(NULLIF(TRIM(v_farmer_name), ''), 'BlueFarm Farmer');
    v_farm_name := COALESCE(NULLIF(TRIM(v_farm_name), ''), 'BlueFarm Registered Farm');
    v_region := COALESCE(NULLIF(TRIM(v_region), ''), 'India');

    -- 1. Notify Farmer that Harvest is Published
    IF v_farmer_email IS NOT NULL AND v_farmer_email LIKE '%@%' AND NOT v_farmer_email ~* '^\d+@' THEN
        INSERT INTO public.email_notifications (
            event_type,
            recipient_email,
            recipient_name,
            recipient_role,
            subject,
            html_content,
            text_content,
            idempotency_key,
            metadata
        ) VALUES (
            'new_harvest',
            v_farmer_email,
            v_farmer_name,
            'farmer',
            'Harvest Listed Successfully: ' || v_species || ' (' || v_qty || ') 🌾',
            '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">' ||
              '<div style="background-color: #0284c7; padding: 24px; text-align: center; border-radius: 8px 8px 0 0;">' ||
                '<h2 style="color: #ffffff; margin: 0; font-size: 20px;">Harvest Published to Marketplace!</h2>' ||
                '<p style="color: #e0f2fe; margin: 4px 0 0 0; font-size: 14px;">Your harvest is now live for buyers across India</p>' ||
              '</div>' ||
              '<div style="padding: 24px; color: #334155; line-height: 1.6;">' ||
                '<p>Hello <strong>' || v_farmer_name || '</strong>,</p>' ||
                '<p>Your harvest listing has been published to the BlueFarm buyer marketplace:</p>' ||
                '<div style="background-color: #f0f9ff; border: 1px solid #bae6fd; border-radius: 8px; padding: 16px; margin: 20px 0;">' ||
                  '<table style="width: 100%; border-collapse: collapse; font-size: 14px;">' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Fish Species:</strong></td><td style="padding: 6px 0; font-weight: bold; color: #0369a1;">' || v_species || '</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Available Stock:</strong></td><td style="padding: 6px 0;">' || v_qty || ' (' || v_count || ')</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Asking Price:</strong></td><td style="padding: 6px 0; font-weight: bold; color: #0284c7;">' || v_price || '</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Pond Reference:</strong></td><td style="padding: 6px 0;">' || v_pond || '</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Farm / Location:</strong></td><td style="padding: 6px 0;">' || v_farm_name || ', ' || v_region || '</td></tr>' ||
                    '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Listing Date:</strong></td><td style="padding: 6px 0;">' || v_created_time || '</td></tr>' ||
                  '</table>' ||
                '</div>' ||
                '<p style="font-size: 13px; color: #64748b;">You will receive instant email and app notifications whenever a buyer places an order for this listing.</p>' ||
              '</div>' ||
              '<div style="padding: 14px; background-color: #f8fafc; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; border-radius: 0 0 8px 8px;">' ||
                '&copy; ' || to_char(now(), 'YYYY') || ' BlueFarm Aquaculture Technologies · Farmer Marketplace' ||
              '</div>' ||
            '</div>',
            'Harvest listing live: ' || v_species || ' (' || v_qty || ') at ' || v_price,
            'harvest_farmer_' || NEW.id::text,
            jsonb_build_object('listing_id', NEW.id, 'farmer_id', NEW.farmer_id)
        )
        ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;

    -- 2. Notify Admin of New Listing
    INSERT INTO public.email_notifications (
        event_type,
        recipient_email,
        recipient_name,
        recipient_role,
        subject,
        html_content,
        text_content,
        idempotency_key,
        metadata
    ) VALUES (
        'new_harvest',
        v_admin_email,
        'BlueFarm Admin',
        'admin',
        '[BlueFarm Admin] New Harvest Listed: ' || v_species || ' by ' || v_farmer_name,
        '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">' ||
          '<div style="background-color: #0f172a; padding: 20px; text-align: center; border-radius: 8px 8px 0 0;">' ||
            '<h2 style="color: #ffffff; margin: 0; font-size: 18px;">New Harvest Posted Alert</h2>' ||
            '<p style="color: #94a3b8; margin: 4px 0 0 0; font-size: 13px;">Marketplace Inventory Addition</p>' ||
          '</div>' ||
          '<div style="padding: 24px; color: #334155; line-height: 1.6;">' ||
            '<p>A farmer has posted a new harvest listing:</p>' ||
            '<table style="width: 100%; border-collapse: collapse; font-size: 14px; margin: 16px 0;">' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Farmer Name:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; font-weight: bold;">' || v_farmer_name || '</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Farm / Region:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9;">' || v_farm_name || ' (' || v_region || ')</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Farmer Contact:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9;">' || COALESCE(v_farmer_email, 'No email') || ', ' || COALESCE(v_farmer_phone, 'No phone') || '</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Fish Species:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; font-weight: bold; color: #0284c7;">' || v_species || '</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Available Quantity:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9;">' || v_qty || ' (' || v_count || ')</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Listed Price:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; font-weight: bold;">' || v_price || '</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Pond Reference:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9;">' || v_pond || '</td></tr>' ||
              '<tr><td style="padding: 6px 0; color: #64748b;"><strong>Listing Date:</strong></td><td style="padding: 6px 0;">' || v_created_time || '</td></tr>' ||
            '</table>' ||
          '</div>' ||
          '<div style="padding: 14px; background-color: #f8fafc; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; border-radius: 0 0 8px 8px;">' ||
            'BlueFarm Automatic Inventory Audit' ||
          '</div>' ||
        '</div>',
        'New harvest listed by ' || v_farmer_name || ': ' || v_species || ' (' || v_qty || ') at ' || v_price || ' in ' || v_region,
        'harvest_admin_' || NEW.id::text,
        jsonb_build_object('listing_id', NEW.id, 'farmer_id', NEW.farmer_id)
    )
    ON CONFLICT (idempotency_key) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_new_harvest ON public.listings;
CREATE TRIGGER trg_notify_new_harvest
AFTER INSERT ON public.listings
FOR EACH ROW
EXECUTE FUNCTION public.fn_on_new_harvest_email();

-- ==============================================================================
-- 8. Trigger Function E: Account Deletion (Fixing and Automating existing workflow)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.fn_on_account_deletion_email()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_admin_email TEXT;
    v_user_name TEXT := 'BlueFarm User';
    v_user_email TEXT;
    v_contact TEXT;
    v_reason TEXT;
    v_role_title TEXT;
    v_ref_code TEXT;
    v_req_time TEXT;
BEGIN
    v_admin_email := public.fn_get_app_config('admin_email', 'bluefarm1572@gmail.com');
    v_ref_code := COALESCE(NEW.reference_code, 'BF-' || UPPER(SUBSTRING(REPLACE(NEW.id::text, '-', ''), 1, 8)));
    v_user_name := COALESCE(NEW.audit_metadata->>'user_name', 'BlueFarm User');
    v_user_email := NULLIF(TRIM(COALESCE(NEW.contact_email, '')), '');
    v_contact := COALESCE(v_user_email, NEW.contact_phone, 'Not specified');
    v_reason := COALESCE(NULLIF(TRIM(NEW.reason), ''), 'No reason provided by user');
    v_role_title := CASE WHEN LOWER(COALESCE(NEW.account_type, '')) = 'buyer' THEN 'Buyer' ELSE 'Farmer' END;
    v_req_time := to_char(COALESCE(NEW.requested_at, now()), 'YYYY-MM-DD HH24:MI:SS') || ' UTC';

    -- 1. Notify Requesting User (if valid email provided)
    IF v_user_email IS NOT NULL AND v_user_email LIKE '%@%' AND NOT v_user_email ~* '^\d+@' THEN
        INSERT INTO public.email_notifications (
            event_type,
            recipient_email,
            recipient_name,
            recipient_role,
            subject,
            html_content,
            text_content,
            idempotency_key,
            metadata
        ) VALUES (
            'account_deletion',
            v_user_email,
            v_user_name,
            LOWER(v_role_title),
            'Your BlueFarm Account Deletion Request [' || v_ref_code || ']',
            '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">' ||
              '<div style="background-color: #0284c7; padding: 24px; text-align: center; border-radius: 8px 8px 0 0;">' ||
                '<h2 style="color: #ffffff; margin: 0; font-size: 20px;">BlueFarm Account Deletion</h2>' ||
                '<p style="color: #e0f2fe; margin: 4px 0 0 0; font-size: 14px;">Confirmation & Request Tracking</p>' ||
              '</div>' ||
              '<div style="padding: 24px; color: #334155; line-height: 1.6;">' ||
                '<p>Hello <strong>' || v_user_name || '</strong>,</p>' ||
                '<p>We received your request to delete your BlueFarm ' || v_role_title || ' account and associated personal data.</p>' ||
                '<div style="margin: 20px 0; padding: 16px; background-color: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 8px; text-align: center;">' ||
                  '<div style="font-size: 12px; color: #166534; font-weight: bold; text-transform: uppercase;">Your Tracking Reference Code</div>' ||
                  '<div style="font-size: 24px; font-weight: 800; color: #15803d; letter-spacing: 1px; margin-top: 4px;">' || v_ref_code || '</div>' ||
                '</div>' ||
                '<p><strong>Summary of actions scheduled:</strong></p>' ||
                '<ul style="padding-left: 20px; font-size: 13px; color: #475569;">' ||
                  '<li>Personal profile credentials and contact data are scheduled for permanent purge.</li>' ||
                  '<li>Active marketplace listings have been archived.</li>' ||
                  '<li>Historical transaction receipts are retained in anonymized format in accordance with statutory accounting and tax compliance laws.</li>' ||
                '</ul>' ||
                '<div style="text-align: center; margin: 24px 0;">' ||
                  '<a href="https://bluefarmaccountdeletion.vercel.app/track" style="display: inline-block; background-color: #0284c7; color: #ffffff; padding: 12px 24px; border-radius: 6px; text-decoration: none; font-weight: bold; font-size: 14px;">Track Request Status</a>' ||
                '</div>' ||
                '<p style="font-size: 13px; color: #64748b;">If you did not request this deletion, please alert BlueFarm Support immediately at <a href="mailto:bluefarm1572@gmail.com" style="color: #0284c7;">bluefarm1572@gmail.com</a>.</p>' ||
              '</div>' ||
              '<div style="padding: 14px; background-color: #f8fafc; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; border-radius: 0 0 8px 8px;">' ||
                '&copy; ' || to_char(now(), 'YYYY') || ' BlueFarm Marketplace' ||
              '</div>' ||
            '</div>',
            'Your account deletion request for ' || v_user_name || ' [' || v_ref_code || '] has been received. Track status at https://bluefarmaccountdeletion.vercel.app/track',
            'deletion_user_' || NEW.id::text,
            jsonb_build_object('request_id', NEW.id, 'reference_code', v_ref_code)
        )
        ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;

    -- 2. Notify Admin at bluefarm1572@gmail.com
    INSERT INTO public.email_notifications (
        event_type,
        recipient_email,
        recipient_name,
        recipient_role,
        subject,
        html_content,
        text_content,
        idempotency_key,
        metadata
    ) VALUES (
        'account_deletion',
        v_admin_email,
        'BlueFarm Admin',
        'admin',
        '[BlueFarm Admin] Account Deletion Request - ' || v_user_name || ' (' || v_ref_code || ')',
        '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">' ||
          '<div style="background-color: #0f172a; padding: 20px; text-align: center; border-radius: 8px 8px 0 0;">' ||
            '<h2 style="color: #ffffff; margin: 0; font-size: 18px;">Account Deletion Request Notice</h2>' ||
            '<p style="color: #94a3b8; margin: 4px 0 0 0; font-size: 13px;">Reference Code: ' || v_ref_code || '</p>' ||
          '</div>' ||
          '<div style="padding: 24px; color: #334155; line-height: 1.6;">' ||
            '<p>A user has submitted an account deletion request:</p>' ||
            '<table style="width: 100%; border-collapse: collapse; font-size: 14px; margin: 16px 0;">' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>User Name:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; font-weight: bold;">' || v_user_name || '</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Reference Code:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; font-weight: bold; color: #dc2626;">' || v_ref_code || '</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Account Role:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9;">' || v_role_title || '</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Contact Detail:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9;">' || v_contact || '</td></tr>' ||
              '<tr><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9; color: #64748b;"><strong>Submission Time:</strong></td><td style="padding: 6px 0; border-bottom: 1px solid #f1f5f9;">' || v_req_time || '</td></tr>' ||
            '</table>' ||
            '<div style="margin-top: 16px;">' ||
              '<strong style="font-size: 13px; color: #475569; text-transform: uppercase;">User Reason for Leaving:</strong>' ||
              '<div style="margin-top: 6px; padding: 12px; background-color: #f8fafc; border-left: 4px solid #ef4444; border-radius: 4px; font-size: 13px; color: #334155;">' ||
                '"' || v_reason || '"' ||
              '</div>' ||
            '</div>' ||
          '</div>' ||
          '<div style="padding: 14px; background-color: #f8fafc; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; border-radius: 0 0 8px 8px;">' ||
            'BlueFarm Automatic Deletion Operations' ||
          '</div>' ||
        '</div>',
        'Account deletion request [' || v_ref_code || '] for ' || v_user_name || ' (' || v_role_title || '). Reason: ' || v_reason,
        'deletion_admin_' || NEW.id::text,
        jsonb_build_object('request_id', NEW.id, 'reference_code', v_ref_code)
    )
    ON CONFLICT (idempotency_key) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_account_deletion ON public.account_deletion_requests;
CREATE TRIGGER trg_notify_account_deletion
AFTER INSERT ON public.account_deletion_requests
FOR EACH ROW
EXECUTE FUNCTION public.fn_on_account_deletion_email();
