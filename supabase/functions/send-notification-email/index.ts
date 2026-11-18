// ==============================================================================
// BlueFarm — Supabase Edge Function: send-notification-email
// Automated Email Notification System using Direct Gmail SMTP (Google App Password)
//
// Supported Events:
// 1. User Registration (User Welcome & Admin Alert)
// 2. New Order Placed (Buyer Confirmation, Farmer Alert, Admin Alert)
// 3. Order Cancellation (Buyer Notice, Farmer Notice, Admin Notice)
// 4. New Harvest Listed (Farmer Confirmation, Admin Alert)
// 5. Account Deletion Request (User Confirmation & Admin Alert)
// 6. Queue Processing (Batch/Webhook processor for public.email_notifications)
//
// Primary Provider:
// - Direct Gmail SMTP (Free 500 emails/day, no 3rd-party accounts, sends from bluefarm1572@gmail.com)
//   Requires secrets: `GMAIL_USER` and `GMAIL_APP_PASSWORD`
// Fallback Providers:
// - Resend (`RESEND_API_KEY`) / Brevo (`BREVO_API_KEY`)
// ==============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.13";

const BLUEFARM_ADMIN = Deno.env.get("BLUEFARM_ADMIN_EMAIL") || "bluefarm1572@gmail.com";
const GMAIL_USER = Deno.env.get("GMAIL_USER") || Deno.env.get("BLUEFARM_SENDER_EMAIL") || "bluefarm1572@gmail.com";
const SENDER_NAME = Deno.env.get("BLUEFARM_SENDER_NAME") || "BlueFarm";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface EmailDispatchItem {
  toEmail: string;
  toName?: string;
  subject: string;
  htmlContent: string;
  textContent?: string;
}

interface DispatchResult {
  success: boolean;
  provider: string;
  messageId?: string;
  error?: string;
}

// ── Email Dispatcher (Gmail SMTP Primary) ────────────────────────────────────
async function dispatchEmail(item: EmailDispatchItem): Promise<DispatchResult> {
  const gmailPass = Deno.env.get("GMAIL_APP_PASSWORD");
  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const brevoApiKey = Deno.env.get("BREVO_API_KEY");

  // Validate email address format
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(item.toEmail) || item.toEmail.match(/^\d+@/)) {
    return {
      success: false,
      provider: "none",
      error: `Invalid or placeholder email address: ${item.toEmail}`,
    };
  }

  // 1. Primary Method: Direct Gmail SMTP using Google App Password
  if (gmailPass && gmailPass.trim() !== "") {
    try {
      const cleanPass = gmailPass.replace(/\s+/g, "").trim(); // Strip any accidental spaces
      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
          user: GMAIL_USER,
          pass: cleanPass,
        },
      });

      const recipient = item.toName ? `"${item.toName}" <${item.toEmail.trim()}>` : item.toEmail.trim();

      const info = await transporter.sendMail({
        from: `"${SENDER_NAME}" <${GMAIL_USER}>`,
        to: recipient,
        subject: item.subject,
        html: item.htmlContent,
        text: item.textContent || item.subject,
      });

      console.log(`[Gmail SMTP Success] Message sent to ${item.toEmail}: ${info.messageId}`);
      return {
        success: true,
        provider: "gmail_smtp",
        messageId: info.messageId || "gmail-" + Date.now(),
      };
    } catch (err) {
      console.error("[Gmail SMTP Error]:", err);
      // Fall through to secondary provider if available
      if (!resendApiKey && !brevoApiKey) {
        return {
          success: false,
          provider: "gmail_smtp",
          error: (err as Error).message,
        };
      }
    }
  }

  // 2. Secondary Method: Resend API (if RESEND_API_KEY is configured)
  if (resendApiKey && resendApiKey.trim() !== "") {
    try {
      const fromAddress = GMAIL_USER.includes("@bluefarm.")
        ? `${SENDER_NAME} <${GMAIL_USER}>`
        : Deno.env.get("RESEND_SENDER_EMAIL") || "BlueFarm <onboarding@resend.dev>";

      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendApiKey.trim()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: fromAddress,
          to: [item.toEmail.trim()],
          subject: item.subject,
          html: item.htmlContent,
          text: item.textContent || item.subject,
        }),
      });

      const resData = await response.json().catch(() => ({}));
      if (response.ok && (response.status === 200 || response.status === 201)) {
        return {
          success: true,
          provider: "resend",
          messageId: resData.id || "resend-" + Date.now(),
        };
      } else {
        const errorMsg = resData.message || resData.name || `Resend HTTP ${response.status}`;
        if (!brevoApiKey) {
          return { success: false, provider: "resend", error: errorMsg };
        }
      }
    } catch (err) {
      if (!brevoApiKey) {
        return { success: false, provider: "resend", error: (err as Error).message };
      }
    }
  }

  // 3. Tertiary Method: Brevo API (if BREVO_API_KEY is configured)
  if (brevoApiKey && brevoApiKey.trim() !== "") {
    try {
      const response = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: {
          "api-key": brevoApiKey.trim(),
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: JSON.stringify({
          sender: { name: SENDER_NAME, email: GMAIL_USER },
          to: [{ email: item.toEmail.trim(), name: item.toName || item.toEmail.split("@")[0] }],
          subject: item.subject,
          htmlContent: item.htmlContent,
          textContent: item.textContent || item.subject,
        }),
      });

      const resData = await response.json().catch(() => ({}));
      if (response.ok && (response.status === 201 || response.status === 200)) {
        return { success: true, provider: "brevo", messageId: resData.messageId || "brevo-" + Date.now() };
      } else {
        return { success: false, provider: "brevo", error: resData.message || `Brevo HTTP ${response.status}` };
      }
    } catch (err) {
      return { success: false, provider: "brevo", error: (err as Error).message };
    }
  }

  // 4. Fallback: No credentials configured yet
  console.warn("⚠️ GMAIL_APP_PASSWORD is not configured in Supabase secrets.");
  console.log(`[DRY-RUN EMAIL] To: ${item.toEmail} | Subject: ${item.subject}`);

  return {
    success: false,
    provider: "unconfigured",
    error: "GMAIL_APP_PASSWORD secret is not configured in Supabase. Generate a Google App Password for bluefarm1572@gmail.com and set it in Supabase secrets.",
  };
}

// ── Main Server Request Handler ──────────────────────────────────────────────
serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const supabase = createClient(supabaseUrl, supabaseKey);

  try {
    const rawBody = await req.json().catch(() => ({}));
    const payload = rawBody.record ? rawBody.record : rawBody;
    const action = payload.action || rawBody.action || "process_queue";

    console.log(`[send-notification-email] Received action: ${action}`);

    // ── Action 1: Process Pending Queue from public.email_notifications ────────
    if (action === "process_queue" || action === "process_notification") {
      let query = supabase
        .from("email_notifications")
        .select("*")
        .eq("status", "pending")
        .order("created_at", { ascending: true })
        .limit(20);

      const targetId = payload.notification_id || rawBody.notification_id;
      if (targetId) {
        query = supabase.from("email_notifications").select("*").eq("id", targetId);
      }

      const { data: pendingItems, error: fetchErr } = await query;
      if (fetchErr) {
        throw new Error(`Failed to query email_notifications: ${fetchErr.message}`);
      }

      const results = [];
      for (const item of pendingItems || []) {
        const nextRetry = (item.retry_count || 0) + 1;

        const dispatch = await dispatchEmail({
          toEmail: item.recipient_email,
          toName: item.recipient_name,
          subject: item.subject,
          htmlContent: item.html_content,
          textContent: item.text_content,
        });

        if (dispatch.success) {
          await supabase
            .from("email_notifications")
            .update({
              status: "sent",
              provider: dispatch.provider,
              provider_message_id: dispatch.messageId,
              sent_at: new Date().toISOString(),
              last_attempt_at: new Date().toISOString(),
              retry_count: nextRetry,
              error_message: null,
            })
            .eq("id", item.id);

          results.push({ id: item.id, status: "sent", provider: dispatch.provider });
        } else {
          const isMaxRetries = nextRetry >= (item.max_retries || 3);
          await supabase
            .from("email_notifications")
            .update({
              status: isMaxRetries ? "failed" : "pending",
              provider: dispatch.provider,
              error_message: dispatch.error,
              last_attempt_at: new Date().toISOString(),
              retry_count: nextRetry,
            })
            .eq("id", item.id);

          results.push({ id: item.id, status: isMaxRetries ? "failed" : "retry_scheduled", error: dispatch.error });
        }
      }

      return new Response(
        JSON.stringify({
          success: true,
          processed_count: results.length,
          results,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── Action 2: Direct Single Email Send / Test Action ──────────────────────
    if (action === "send_direct") {
      const { to_email, to_name, subject, html_content, text_content } = payload;
      if (!to_email || !subject || !html_content) {
        return new Response(
          JSON.stringify({ error: "Missing required fields: to_email, subject, html_content" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const dispatch = await dispatchEmail({
        toEmail: to_email,
        toName: to_name,
        subject,
        htmlContent: html_content,
        textContent: text_content,
      });

      return new Response(
        JSON.stringify(dispatch),
        { status: dispatch.success ? 200 : 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── Action 3: Explicit Event Trigger (Client / Flutter fallback) ─────────
    const eventType = payload.event_type || rawBody.event_type;
    if (eventType) {
      const { data: queued, error: qErr } = await supabase
        .from("email_notifications")
        .select("*")
        .eq("status", "pending")
        .order("created_at", { ascending: false })
        .limit(10);

      const results = [];
      for (const item of queued || []) {
        const dispatch = await dispatchEmail({
          toEmail: item.recipient_email,
          toName: item.recipient_name,
          subject: item.subject,
          htmlContent: item.html_content,
          textContent: item.text_content,
        });

        await supabase
          .from("email_notifications")
          .update({
            status: dispatch.success ? "sent" : "failed",
            provider: dispatch.provider,
            provider_message_id: dispatch.messageId,
            error_message: dispatch.error,
            sent_at: dispatch.success ? new Date().toISOString() : null,
            last_attempt_at: new Date().toISOString(),
            retry_count: (item.retry_count || 0) + 1,
          })
          .eq("id", item.id);

        results.push({ id: item.id, recipient: item.recipient_email, success: dispatch.success });
      }

      return new Response(
        JSON.stringify({ success: true, event_type: eventType, processed: results }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ message: "send-notification-email endpoint active. Gmail SMTP enabled." }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("[send-notification-email Exception]:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
