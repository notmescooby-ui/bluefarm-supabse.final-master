// ==============================================================================
// BlueFarm — Supabase Edge Function: send-deletion-email
// Dedicated Account Deletion Email Delivery Engine via Direct Gmail SMTP
//
// Sends two emails on account deletion:
// 1. Admin Alert to BlueFarm Gmail (bluefarm1572@gmail.com) with user's name & reason
// 2. Confirmation email to the requesting user with reference tracking ID
//
// Primary Provider:
// - Direct Gmail SMTP (Uses bluefarm1572@gmail.com via Google App Password)
//   Requires secret: `GMAIL_APP_PASSWORD`
// Fallback Providers:
// - Resend (`RESEND_API_KEY`) / Brevo (`BREVO_API_KEY`)
// ==============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.13";

const BLUEFARM_GMAIL = Deno.env.get("BLUEFARM_ADMIN_EMAIL") || "bluefarm1572@gmail.com";
const GMAIL_USER = Deno.env.get("GMAIL_USER") || "bluefarm1572@gmail.com";
const SENDER_NAME = Deno.env.get("BLUEFARM_SENDER_NAME") || "BlueFarm Security";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface DispatchResult {
  success: boolean;
  provider: string;
  messageId?: string;
  error?: string;
}

async function sendEmail(toEmail: string, toName: string, subject: string, htmlContent: string): Promise<DispatchResult> {
  const gmailPass = Deno.env.get("GMAIL_APP_PASSWORD");
  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const brevoApiKey = Deno.env.get("BREVO_API_KEY");

  // Validate email address
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(toEmail) || toEmail.match(/^\d+@/)) {
    return { success: false, provider: "none", error: `Invalid recipient address: ${toEmail}` };
  }

  // 1. Primary: Direct Gmail SMTP
  if (gmailPass && gmailPass.trim() !== "") {
    try {
      const cleanPass = gmailPass.replace(/\s+/g, "").trim();
      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
          user: GMAIL_USER,
          pass: cleanPass,
        },
      });

      const recipient = toName ? `"${toName}" <${toEmail.trim()}>` : toEmail.trim();

      const info = await transporter.sendMail({
        from: `"${SENDER_NAME}" <${GMAIL_USER}>`,
        to: recipient,
        subject,
        html: htmlContent,
        text: subject,
      });

      console.log(`[Gmail SMTP Deletion Email] Sent to ${toEmail}: ${info.messageId}`);
      return { success: true, provider: "gmail_smtp", messageId: info.messageId || "gmail-" + Date.now() };
    } catch (err) {
      console.error("[Gmail SMTP Error]:", err);
      if (!resendApiKey && !brevoApiKey) {
        return { success: false, provider: "gmail_smtp", error: (err as Error).message };
      }
    }
  }

  // 2. Fallback: Resend API
  if (resendApiKey && resendApiKey.trim() !== "") {
    try {
      const senderFrom = GMAIL_USER.includes("@bluefarm.")
        ? `${SENDER_NAME} <${GMAIL_USER}>`
        : Deno.env.get("RESEND_SENDER_EMAIL") || "BlueFarm Security <onboarding@resend.dev>";

      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendApiKey.trim()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: senderFrom,
          to: [toEmail.trim()],
          subject,
          html: htmlContent,
          text: subject,
        }),
      });

      const resData = await response.json().catch(() => ({}));
      if (response.ok && (response.status === 200 || response.status === 201)) {
        return { success: true, provider: "resend", messageId: resData.id || "resend-" + Date.now() };
      } else {
        const errorMsg = resData.message || resData.name || `Resend HTTP ${response.status}`;
        if (!brevoApiKey) return { success: false, provider: "resend", error: errorMsg };
      }
    } catch (err) {
      if (!brevoApiKey) return { success: false, provider: "resend", error: (err as Error).message };
    }
  }

  // 3. Fallback: Brevo API
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
          to: [{ email: toEmail.trim(), name: toName || toEmail.split("@")[0] }],
          subject,
          htmlContent,
          textContent: subject,
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

  console.warn("⚠️ GMAIL_APP_PASSWORD is not configured in Supabase secrets.");
  return {
    success: false,
    provider: "unconfigured",
    error: "GMAIL_APP_PASSWORD secret is not configured in Supabase.",
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const supabase = createClient(supabaseUrl, supabaseKey);

  try {
    const rawBody = await req.json().catch(() => ({}));
    const rec = rawBody.record ? rawBody.record : rawBody;

    const reference_code = rec.reference_code || rawBody.reference_code || "BF-UNKNOWN";
    const user_name = rec.user_name || rec.audit_metadata?.user_name || rawBody.user_name || "BlueFarm User";
    const account_type = rec.account_type || rawBody.account_type || "account";
    const contact = rec.contact || rec.contact_email || rec.contact_phone || rawBody.contact || "Not provided";
    const user_email = rec.user_email || rec.contact_email || rawBody.user_email || null;
    const reason = rec.reason || rec.audit_metadata?.reason || rawBody.reason || null;
    const requested_at = rec.requested_at || rawBody.requested_at || null;

    const formattedDate = requested_at
      ? new Date(requested_at).toLocaleString("en-IN", { timeZone: "Asia/Kolkata" }) + " IST"
      : new Date().toLocaleString("en-IN", { timeZone: "Asia/Kolkata" }) + " IST";

    const cleanReason = (reason && reason.trim()) ? reason.trim() : "No reason provided by user.";
    const cleanName = (user_name && user_name.trim()) ? user_name.trim() : "BlueFarm User";
    const formattedRole = account_type ? account_type.charAt(0).toUpperCase() + account_type.slice(1) : "Account";

    // ── 1. Admin Email HTML ──────────────────────────────────────────────────
    const adminSubject = `[BlueFarm] New Account Deletion Request - ${cleanName} (${reference_code})`;
    const adminHtml = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px; }
          .card { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05); }
          .header { background: #0f172a; padding: 24px; color: #ffffff; text-align: center; }
          .header h1 { margin: 0; font-size: 20px; font-weight: 700; }
          .header p { margin: 4px 0 0 0; font-size: 13px; color: #94a3b8; }
          .content { padding: 28px; }
          .badge { display: inline-block; background: #fee2e2; color: #991b1b; padding: 4px 12px; border-radius: 9999px; font-size: 12px; font-weight: 700; text-transform: uppercase; margin-bottom: 20px; }
          table { width: 100%; border-collapse: collapse; margin-top: 8px; }
          td { padding: 12px 0; border-bottom: 1px solid #f1f5f9; font-size: 14px; }
          .label { width: 35%; color: #64748b; font-weight: 600; }
          .value { color: #0f172a; font-weight: 500; }
          .reason-box { margin-top: 20px; padding: 16px; background: #f8fafc; border-radius: 12px; border-left: 4px solid #ef4444; font-size: 14px; color: #334155; line-height: 1.5; }
          .footer { padding: 16px 28px; background: #f8fafc; border-top: 1px solid #e2e8f0; font-size: 12px; color: #64748b; text-align: center; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="header">
            <h1>BlueFarm Account Deletion Notice</h1>
            <p>Automated Notification from Account Deletion Portal</p>
          </div>
          <div class="content">
            <span class="badge">Deletion Request Submitted</span>
            <table>
              <tr>
                <td class="label">User's Name</td>
                <td class="value"><strong>${cleanName}</strong></td>
              </tr>
              <tr>
                <td class="label">Reference ID</td>
                <td class="value"><code style="background: #e2e8f0; padding: 2px 6px; border-radius: 4px; font-size: 14px; color: #0f172a; font-weight: bold;">${reference_code}</code></td>
              </tr>
              <tr>
                <td class="label">Account Role</td>
                <td class="value">${formattedRole}</td>
              </tr>
              <tr>
                <td class="label">Registered Contact</td>
                <td class="value">${contact}</td>
              </tr>
              <tr>
                <td class="label">Submission Date</td>
                <td class="value">${formattedDate}</td>
              </tr>
            </table>

            <div style="margin-top: 24px;">
              <strong style="font-size: 13px; text-transform: uppercase; letter-spacing: 0.5px; color: #475569;">User's Reason for Leaving:</strong>
              <div class="reason-box">
                "${cleanReason}"
              </div>
            </div>
          </div>
          <div class="footer">
            BlueFarm Aquaculture Marketplace · Automatic Deletion Notification
          </div>
        </div>
      </body>
      </html>
    `;

    // ── 2. User Email HTML ───────────────────────────────────────────────────
    const userSubject = `Your BlueFarm Account Deletion Request [${reference_code}]`;
    const userHtml = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px; }
          .card { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05); }
          .header { background: #0284c7; padding: 24px; color: #ffffff; text-align: center; }
          .header h1 { margin: 0; font-size: 20px; font-weight: 700; }
          .content { padding: 28px; color: #334155; font-size: 14px; line-height: 1.6; }
          .ref-box { margin: 20px 0; padding: 16px; background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 12px; text-align: center; }
          .ref-title { font-size: 12px; color: #166534; font-weight: 600; text-transform: uppercase; }
          .ref-code { font-size: 24px; font-weight: 800; color: #15803d; letter-spacing: 1px; margin-top: 4px; }
          .checklist { background: #f8fafc; border-radius: 12px; padding: 16px 20px; margin: 20px 0; font-size: 13px; }
          .checklist li { margin-bottom: 8px; color: #475569; }
          .btn { display: inline-block; background: #0284c7; color: #ffffff !important; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 14px; margin-top: 10px; }
          .footer { padding: 16px 28px; background: #f8fafc; border-top: 1px solid #e2e8f0; font-size: 12px; color: #64748b; text-align: center; }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="header">
            <h1>BlueFarm Account Deletion</h1>
          </div>
          <div class="content">
            <p>Hello <strong>${cleanName}</strong>,</p>
            <p>We received your request to permanently delete your BlueFarm ${formattedRole.toLowerCase()} account and associated personal data.</p>
            
            <div class="ref-box">
              <div class="ref-title">Your Reference Tracking Code</div>
              <div class="ref-code">${reference_code}</div>
            </div>

            <p><strong>What happens now:</strong></p>
            <ul class="checklist">
              <li>Your personal profile data (name, contact details, authentication credentials) has been scheduled for permanent removal.</li>
              <li>You will no longer be able to sign in to the BlueFarm mobile app.</li>
              <li>Any active marketplace listings have been archived.</li>
              <li>Historical statutory transaction and order receipts are retained in anonymized format in accordance with applicable tax and regulatory laws.</li>
            </ul>

            <p>You can check the live progress of your request at any time using your tracking code:</p>
            <div style="text-align: center; margin: 20px 0;">
              <a href="https://bluefarmaccountdeletion.vercel.app/track" class="btn">Track Request Status</a>
            </div>

            <p style="margin-top: 24px; font-size: 13px; color: #64748b;">
              If you did not request this deletion or believe this is an error, please contact BlueFarm Support immediately at <a href="mailto:${BLUEFARM_GMAIL}">${BLUEFARM_GMAIL}</a>.
            </p>
          </div>
          <div class="footer">
            &copy; 2026 BlueFarm Marketplace · All rights reserved.
          </div>
        </div>
      </body>
      </html>
    `;

    // ── 3. Dispatch Emails via Gmail SMTP ─────────────────────────────────────
    const adminDispatch = await sendEmail(BLUEFARM_GMAIL, "BlueFarm Admin", adminSubject, adminHtml);

    let userDispatch: DispatchResult | null = null;
    if (user_email && user_email.includes("@") && !user_email.match(/^\d+@/)) {
      userDispatch = await sendEmail(user_email.trim(), cleanName, userSubject, userHtml);
    }

    // ── 4. Log or Update public.email_notifications ──────────────────────────
    try {
      if (supabaseUrl && supabaseKey) {
        await supabase.from("email_notifications").upsert(
          {
            event_type: "account_deletion",
            recipient_email: BLUEFARM_GMAIL,
            recipient_name: "BlueFarm Admin",
            recipient_role: "admin",
            subject: adminSubject,
            html_content: adminHtml,
            status: adminDispatch.success ? "sent" : "failed",
            provider: adminDispatch.provider,
            provider_message_id: adminDispatch.messageId,
            error_message: adminDispatch.error,
            sent_at: adminDispatch.success ? new Date().toISOString() : null,
            idempotency_key: `edge_del_admin_${reference_code}`,
          },
          { onConflict: "idempotency_key" }
        );

        if (user_email && userDispatch) {
          await supabase.from("email_notifications").upsert(
            {
              event_type: "account_deletion",
              recipient_email: user_email.trim(),
              recipient_name: cleanName,
              recipient_role: account_type,
              subject: userSubject,
              html_content: userHtml,
              status: userDispatch.success ? "sent" : "failed",
              provider: userDispatch.provider,
              provider_message_id: userDispatch.messageId,
              error_message: userDispatch.error,
              sent_at: userDispatch.success ? new Date().toISOString() : null,
              idempotency_key: `edge_del_user_${reference_code}`,
            },
            { onConflict: "idempotency_key" }
          );
        }
      }
    } catch (logErr) {
      console.warn("[email_notifications log error]:", logErr);
    }

    return new Response(
      JSON.stringify({
        success: adminDispatch.success || (userDispatch ? userDispatch.success : false),
        admin_dispatch: adminDispatch,
        user_dispatch: userDispatch,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("send-deletion-email error:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
