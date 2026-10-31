// ==============================================================================
// BlueFarm — Supabase Edge Function Blueprint: verify-payment
// STATUS: [UNCONFIGURED / BLUEPRINT TEMPLATE ONLY]
//
// ⚠️ WARNING: DO NOT DEPLOY TO PRODUCTION UNTIL A LICENSED MERCHANT GATEWAY
// (E.G. RAZORPAY, CASHFREE, OR PHONEPE PG) IS ONBOARDED AND DOCUMENTED
// HMAC SHA256 WEBHOOK SIGNATURE VERIFICATION IS FULLY WIRED.
//
// THIS FUNCTION ENFORCES A 501 NOT IMPLEMENTED RESPONSE UNTIL A REAL
// `PAYMENT_WEBHOOK_SECRET` IS CONFIGURED IN SUPABASE ENVIRONMENT SECRETS.
// ==============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-webhook-signature",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Guard: Fail closed if webhook secret has not been configured
  const webhookSecret = Deno.env.get("PAYMENT_WEBHOOK_SECRET");
  if (!webhookSecret || webhookSecret.trim() === "" || webhookSecret === "UNCONFIGURED") {
    return new Response(
      JSON.stringify({
        error: "Payment verification webhook is UNCONFIGURED. Live webhook processing is disabled until a licensed merchant provider secret is set.",
        code: "GATEWAY_UNCONFIGURED",
      }),
      { status: 501, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "" // Privileged key strictly inside server environment
    );

    const body = await req.json();
    const { order_id, payment_id, signature, amount_paise } = body;

    if (!order_id || !payment_id) {
      return new Response(
        JSON.stringify({ error: "Missing required order_id or payment_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Fetch current order from DB
    const { data: order, error: fetchErr } = await supabaseClient
      .from("orders")
      .select("*")
      .eq("id", order_id)
      .single();

    if (fetchErr || !order) {
      return new Response(
        JSON.stringify({ error: "Order not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Idempotency Check: if already paid, do not re-process
    if (order.payment_status === "paid") {
      return new Response(
        JSON.stringify({ message: "Order is already marked paid (idempotent)", status: "paid" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Amount & Currency Verification
    // Never trust client amount: verify that the amount paid matches the stored order amount
    const expectedAmount = order.amount_paise ?? Math.round(order.total_price * 100);
    if (amount_paise && Number(amount_paise) !== expectedAmount) {
      return new Response(
        JSON.stringify({ error: "Amount mismatch detected. Payment rejected." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Cryptographic Signature Verification (HMAC SHA256)
    // Replace with provider-specific signature verification (e.g., Razorpay/Cashfree SDK)
    // const crypto = await import("node:crypto");
    // const expectedSig = crypto.createHmac("sha256", webhookSecret).update(`${order_id}|${payment_id}`).digest("hex");
    // if (signature !== expectedSig) throw new Error("Invalid signature");

    // 5. Update order to 'paid' and status to 'confirmed' using Service Role
    const { data: updated, error: updateErr } = await supabaseClient
      .from("orders")
      .update({
        payment_status: "paid",
        status: "confirmed",
        payment_ref: payment_id,
        paid_at: new Date().toISOString(),
      })
      .eq("id", order_id)
      .select()
      .single();

    if (updateErr) {
      throw updateErr;
    }

    return new Response(
      JSON.stringify({ success: true, order: updated }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message ?? "Internal error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
