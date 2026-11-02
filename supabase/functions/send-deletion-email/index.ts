// ==============================================================================
// BlueFarm — Supabase Edge Function: send-deletion-email
//
// Sends two emails on account deletion:
// 1. Admin Alert to BlueFarm Gmail (bluefarm1572@gmail.com) with user's name & reason
// 2. Confirmation email to the requesting user (if valid email available)
//
// Supported Providers:
// - Resend (Recommended, free 3,000 emails/mo): Set `RESEND_API_KEY` in Supabase Secrets
// - Fallback console logging when API key is pending configuration
// ==============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const BLUEFARM_GMAIL = "bluefarm1572@gmail.com";
const DEFAULT_FROM = "BlueFarm Security <onboarding@resend.dev>";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface DeletionEmailPayload {
  reference_code: string;
  user_name: string;
  account_type: "farmer" | "buyer" | string;
  contact: string;
  user_email?: string | null;
  reason?: string | null;
  requested_at?: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const rawBody = await req.json();
    // Support both direct client invocations and Supabase Database Webhook payloads (rawBody.record)
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

    const resendApiKey = Deno.env.get("RESEND_API_KEY");

    // ============================================================================
    // 1. Prepare Admin Email to BlueFarm (bluefarm1572@gmail.com)
    // ============================================================================
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

    // ============================================================================
    // 2. Prepare User Confirmation Email (if user email provided)
    // ============================================================================
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

    // ============================================================================
    // 3. Dispatch Emails via Resend (or log if Resend API key is unconfigured)
    // ============================================================================
    if (!resendApiKey) {
      console.warn("⚠️ RESEND_API_KEY secret is not set in Supabase. Email output logged to console:");
      console.log(`[ADMIN NOTIFICATION] To: ${BLUEFARM_GMAIL} | Subject: ${adminSubject}`);
      console.log(`[USER CONFIRMATION] To: ${user_email || 'None'} | Subject: ${userSubject}`);

      return new Response(
        JSON.stringify({
          success: true,
          mode: "dry-run",
          message: "Email queued (RESEND_API_KEY not configured yet).",
          admin_recipient: BLUEFARM_GMAIL,
          user_recipient: user_email ?? null,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Send Admin Notification to bluefarm1572@gmail.com
    const adminEmailRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: DEFAULT_FROM,
        to: [BLUEFARM_GMAIL],
        subject: adminSubject,
        html: adminHtml,
      }),
    });
    const adminEmailResult = await adminEmailRes.json();

    // Send User Confirmation (if valid email present)
    let userEmailResult = null;
    if (user_email && user_email.includes("@") && !user_email.match(/^\d+@gmail\.com$/)) {
      const userEmailRes = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: DEFAULT_FROM,
          to: [user_email.trim()],
          subject: userSubject,
          html: userHtml,
        }),
      });
      userEmailResult = await userEmailRes.json();
    }

    return new Response(
      JSON.stringify({
        success: true,
        admin_email: adminEmailResult,
        user_email: userEmailResult,
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

