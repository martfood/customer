/**
 * Login security (account lockout + IP rate limiting) and support email workflow.
 *
 * Loaded from index.js AFTER admin.initializeApp() and setGlobalOptions(), so all
 * functions here inherit the project region (europe-west1).
 *
 * Collections (server-write only, see firestore.rules):
 *   login_security/{emailHash}   per-account failure counter + lockout stage
 *   ip_rate_limits/{ipHash}      per-IP failure window + block
 *   lockout_history/{autoId}     audit trail of lock / unlock events
 *   support_requests/{id}        inbound + outbound support emails (+ messages sub-collection)
 *   settings/security_config     admin-editable thresholds, durations, support email
 */
const crypto = require("crypto");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");

// Set with: firebase functions:secrets:set RESEND_WEBHOOK_SECRET
const RESEND_WEBHOOK_SECRET = defineSecret("RESEND_WEBHOOK_SECRET");

// Public Firebase Web API key (identifies the project; not a secret).
const FIREBASE_WEB_API_KEY = "AIzaSyDuJk8Zg6O4ezxY8wkuECPRGr4MKlKyDN4";

const DEFAULT_CONFIG = {
  maxFailedPerStage: 5,
  // Minutes for stage 1, 2, 3. Stage 4 is indefinite (admin only).
  stageDurationsMin: [5, 15, 30],
  ipMaxAttempts: 20,
  ipWindowMin: 15,
  ipBlockMin: 15,
  stageDecayHours: 24,
  supportEmail: "support@martfooddelivery.com",
};

const db = () => admin.firestore();
const now = () => Date.now();
const FieldValue = () => admin.firestore.FieldValue;

const sha = (v) => crypto.createHash("sha256").update(String(v)).digest("hex");
const normEmail = (e) => String(e || "").trim().toLowerCase();

async function getConfig() {
  try {
    const snap = await db().collection("settings").doc("security_config").get();
    const d = snap.exists ? snap.data() : {};
    const durations = Array.isArray(d.stageDurationsMin) && d.stageDurationsMin.length >= 3
      ? d.stageDurationsMin.slice(0, 3).map((n) => Math.max(1, Number(n) || 1))
      : DEFAULT_CONFIG.stageDurationsMin;
    return {
      ...DEFAULT_CONFIG,
      ...d,
      stageDurationsMin: durations,
      maxFailedPerStage: Math.max(1, Number(d.maxFailedPerStage) || DEFAULT_CONFIG.maxFailedPerStage),
      ipMaxAttempts: Math.max(1, Number(d.ipMaxAttempts) || DEFAULT_CONFIG.ipMaxAttempts),
      ipWindowMin: Math.max(1, Number(d.ipWindowMin) || DEFAULT_CONFIG.ipWindowMin),
      ipBlockMin: Math.max(1, Number(d.ipBlockMin) || DEFAULT_CONFIG.ipBlockMin),
      supportEmail: (d.supportEmail || DEFAULT_CONFIG.supportEmail).toString(),
    };
  } catch (e) {
    logger.error("getConfig failed, using defaults", e);
    return DEFAULT_CONFIG;
  }
}

function clientIp(req) {
  const xff = (req.headers["x-forwarded-for"] || "").toString().split(",")[0].trim();
  return xff || req.ip || "unknown";
}

function cors(req, res) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return true;
  }
  return false;
}

function escapeHtml(s) {
  return String(s || "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

/** Shared branded email shell, also used by the admin live preview. */
function brandedEmail({ title, bodyHtml }) {
  return `<!DOCTYPE html><html><body style="font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;background:#f8fafc;margin:0;padding:24px;color:#334155;">
<div style="max-width:560px;margin:0 auto;background:#fff;border:1px solid #e2e8f0;border-radius:12px;overflow:hidden;">
<div style="background:#7C3AED;padding:24px;text-align:center;"><h2 style="color:#fff;margin:0;font-size:20px;">${escapeHtml(title)}</h2></div>
<div style="padding:24px;line-height:1.6;font-size:14px;">${bodyHtml}</div>
<div style="background:#f8fafc;padding:16px;text-align:center;border-top:1px solid #e2e8f0;font-size:12px;color:#94a3b8;">&copy; MartFood Technologies. All rights reserved.</div>
</div></body></html>`;
}

module.exports = function buildSecurity({ sendEmail, resendApiKey }) {
  const out = {};

  async function logHistory(entry) {
    try {
      await db().collection("lockout_history").add({ ...entry, createdAt: FieldValue().serverTimestamp() });
    } catch (e) {
      logger.error("logHistory failed", e);
    }
  }

  async function verifyPassword(email, password) {
    const r = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_WEB_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password, returnSecureToken: false }),
      }
    );
    const j = await r.json();
    if (r.ok && j.localId) return { ok: true, uid: j.localId };
    const code = (j.error && j.error.message) || "UNKNOWN";
    return { ok: false, code };
  }

  function lockResponse(res, data) {
    res.status(423).json({ success: false, code: "locked", ...data });
  }

  /**
   * POST { email, password, app } -> { success, token } | { code: locked | ip_blocked | invalid }
   * Server-side enforcement of account lockout + IP rate limiting.
   */
  out.secureLogin = onRequest(async (req, res) => {
    if (cors(req, res)) return;
    if (req.method !== "POST") return res.status(405).json({ success: false, error: "Method Not Allowed" });

    const email = normEmail(req.body && req.body.email);
    const password = (req.body && req.body.password) || "";
    const appName = ((req.body && req.body.app) || "unknown").toString().slice(0, 20);
    if (!email || !password) return res.status(400).json({ success: false, code: "invalid", error: "Email and password are required." });

    try {
      const cfg = await getConfig();
      const ip = clientIp(req);
      const ipId = sha(ip);
      const emailId = sha(email);
      const ipRef = db().collection("ip_rate_limits").doc(ipId);
      const secRef = db().collection("login_security").doc(emailId);

      // ---- 1. IP block check ----
      const ipSnap = await ipRef.get();
      const ipData = ipSnap.exists ? ipSnap.data() : {};
      if (ipData.blockedUntil && ipData.blockedUntil > now()) {
        return res.status(429).json({
          success: false,
          code: "ip_blocked",
          retryAfterSec: Math.ceil((ipData.blockedUntil - now()) / 1000),
          supportEmail: cfg.supportEmail,
        });
      }

      // ---- 2. Account lock check ----
      const secSnap = await secRef.get();
      let sec = secSnap.exists ? secSnap.data() : { stage: 0, failedCount: 0 };

      // Decay stages 1-3 after good behaviour window
      if (sec.stage > 0 && sec.stage < 4 && !sec.indefinite && sec.lastFailureAt &&
        now() - sec.lastFailureAt > cfg.stageDecayHours * 3600 * 1000 &&
        !(sec.lockedUntil && sec.lockedUntil > now())) {
        sec = { ...sec, stage: 0, failedCount: 0 };
        await secRef.set({ stage: 0, failedCount: 0 }, { merge: true });
      }

      if (sec.indefinite) {
        return lockResponse(res, { stage: 4, indefinite: true, supportEmail: cfg.supportEmail });
      }
      if (sec.lockedUntil && sec.lockedUntil > now()) {
        return lockResponse(res, {
          stage: sec.stage,
          indefinite: false,
          remainingSec: Math.ceil((sec.lockedUntil - now()) / 1000),
          supportEmail: cfg.supportEmail,
        });
      }

      // ---- 3. Verify password ----
      const result = await verifyPassword(email, password);

      if (result.ok) {
        await secRef.set({ failedCount: 0, stage: 0, lockedUntil: null, indefinite: false, lastSuccessAt: now() }, { merge: true });
        await ipRef.set({ failedCount: 0, windowStart: now() }, { merge: true });
        const token = await admin.auth().createCustomToken(result.uid);
        return res.status(200).json({ success: true, token, uid: result.uid });
      }

      if (result.code === "USER_DISABLED") {
        // Disabled outside of our lockout flow (e.g. admin suspension)
        return res.status(403).json({ success: false, code: "disabled", error: "This account has been disabled. Please contact support.", supportEmail: cfg.supportEmail });
      }

      // ---- 4. Record failure (account + IP) ----
      const windowMs = cfg.ipWindowMin * 60 * 1000;
      const inWindow = ipData.windowStart && now() - ipData.windowStart < windowMs;
      const ipFailed = (inWindow ? ipData.failedCount || 0 : 0) + 1;
      const ipUpdate = {
        ip,
        failedCount: ipFailed,
        windowStart: inWindow ? ipData.windowStart : now(),
        lastAttemptAt: now(),
        lastEmail: email,
        totalFailed: (ipData.totalFailed || 0) + 1,
        firstSeenAt: ipData.firstSeenAt || now(),
        updatedAt: FieldValue().serverTimestamp(),
      };
      let ipJustBlocked = false;
      if (ipFailed >= cfg.ipMaxAttempts) {
        ipUpdate.blockedUntil = now() + cfg.ipBlockMin * 60 * 1000;
        ipUpdate.blockCount = (ipData.blockCount || 0) + 1;
        ipUpdate.failedCount = 0;
        ipJustBlocked = true;
      }
      await ipRef.set(ipUpdate, { merge: true });

      const failedCount = (sec.failedCount || 0) + 1;
      const secUpdate = {
        email,
        app: appName,
        failedCount,
        stage: sec.stage || 0,
        lastFailureAt: now(),
        lastIp: ip,
        updatedAt: FieldValue().serverTimestamp(),
      };

      if (failedCount >= cfg.maxFailedPerStage) {
        const stage = Math.min((sec.stage || 0) + 1, 4);
        secUpdate.stage = stage;
        secUpdate.failedCount = 0;
        secUpdate.lockedAt = now();
        secUpdate.reason = `${cfg.maxFailedPerStage} consecutive failed login attempts`;
        let remainingSec = null;
        if (stage >= 4) {
          secUpdate.indefinite = true;
          secUpdate.lockedUntil = null;
          try {
            const u = await admin.auth().getUserByEmail(email);
            secUpdate.uid = u.uid;
            await admin.auth().updateUser(u.uid, { disabled: true });
          } catch (e) {
            logger.warn("Stage 4: no auth user to disable for", email);
          }
        } else {
          const mins = cfg.stageDurationsMin[stage - 1];
          secUpdate.lockedUntil = now() + mins * 60 * 1000;
          secUpdate.indefinite = false;
          remainingSec = mins * 60;
        }
        await secRef.set(secUpdate, { merge: true });
        await logHistory({ type: "locked", email, emailHash: emailId, stage, app: appName, ip, reason: secUpdate.reason, lockedUntil: secUpdate.lockedUntil || null, indefinite: !!secUpdate.indefinite });

        // Notify the account owner (best effort, do not reveal to caller whether account exists)
        sendEmail({
          to: email,
          subject: stage >= 4 ? "Your MartFood account has been locked" : "Too many failed login attempts",
          html: brandedEmail({
            title: "Account Security Alert",
            bodyHtml: stage >= 4
              ? `<p>Your account was locked after repeated failed login attempts. It can only be restored by our support team.</p><p>Please contact <b>${escapeHtml(cfg.supportEmail)}</b> to unlock it.</p><p>If this was not you, we also recommend resetting your password once you regain access.</p>`
              : `<p>We detected ${cfg.maxFailedPerStage} failed login attempts on your account. For your security, login is paused for <b>${cfg.stageDurationsMin[stage - 1]} minutes</b>.</p><p>If this was not you, or you forgot your password, please reset it from the login screen.</p>`,
          }),
        }).catch((e) => logger.error("lockout email failed", e));

        return lockResponse(res, {
          stage,
          indefinite: stage >= 4,
          remainingSec,
          supportEmail: cfg.supportEmail,
        });
      }

      await secRef.set(secUpdate, { merge: true });

      if (ipJustBlocked) {
        return res.status(429).json({ success: false, code: "ip_blocked", retryAfterSec: cfg.ipBlockMin * 60, supportEmail: cfg.supportEmail });
      }
      // Uniform message: never reveal whether the email exists.
      return res.status(401).json({
        success: false,
        code: "invalid",
        error: "Incorrect email or password.",
        attemptsRemaining: cfg.maxFailedPerStage - failedCount,
      });
    } catch (e) {
      logger.error("secureLogin error", e);
      return res.status(500).json({ success: false, code: "server", error: "Unable to sign in right now. Please try again." });
    }
  });

  /** Public, read-only: remaining lock info + support email for an email address (used on app start / after reset). */
  out.getLockStatus = onRequest(async (req, res) => {
    if (cors(req, res)) return;
    try {
      const email = normEmail(req.body && req.body.email);
      const cfg = await getConfig();
      if (!email) return res.status(200).json({ locked: false, supportEmail: cfg.supportEmail });
      const snap = await db().collection("login_security").doc(sha(email)).get();
      const s = snap.exists ? snap.data() : {};
      if (s.indefinite) return res.status(200).json({ locked: true, stage: 4, indefinite: true, supportEmail: cfg.supportEmail });
      if (s.lockedUntil && s.lockedUntil > now()) {
        return res.status(200).json({ locked: true, stage: s.stage, remainingSec: Math.ceil((s.lockedUntil - now()) / 1000), supportEmail: cfg.supportEmail });
      }
      return res.status(200).json({ locked: false, supportEmail: cfg.supportEmail });
    } catch (e) {
      return res.status(200).json({ locked: false });
    }
  });

  // ---------- Admin guard ----------
  async function requireAdmin(request) {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");
    const snap = await db().collection("admins").doc(request.auth.uid).get();
    if (!snap.exists || !snap.data().role) throw new HttpsError("permission-denied", "Admin access required.");
    return { uid: request.auth.uid, ...snap.data() };
  }

  out.adminUnlockAccount = onCall(async (request) => {
    const adminUser = await requireAdmin(request);
    const emailHash = (request.data && request.data.emailHash) || "";
    if (!emailHash) throw new HttpsError("invalid-argument", "emailHash required.");
    const ref = db().collection("login_security").doc(emailHash);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError("not-found", "Lockout record not found.");
    const s = snap.data();
    if (s.email) {
      try {
        const u = await admin.auth().getUserByEmail(s.email);
        if (u.disabled) await admin.auth().updateUser(u.uid, { disabled: false });
      } catch (e) {
        logger.warn("unlock: auth user not found", s.email);
      }
    }
    await ref.set({ stage: 0, failedCount: 0, lockedUntil: null, indefinite: false, unlockedAt: now(), unlockedBy: adminUser.uid }, { merge: true });
    await logHistory({ type: "unlocked", email: s.email || "", emailHash, stage: s.stage || 0, app: s.app || "", by: adminUser.uid, byEmail: adminUser.email || "" });
    if (s.email) {
      const cfg = await getConfig();
      sendEmail({
        to: s.email,
        subject: "Your MartFood account has been unlocked",
        html: brandedEmail({ title: "Account Restored", bodyHtml: `<p>Your account has been unlocked by our support team. You can sign in again.</p><p>If you do not remember your password, use "Forgot password" on the login screen. Questions? ${escapeHtml(cfg.supportEmail)}</p>` }),
      }).catch((e) => logger.error("unlock email failed", e));
    }
    return { success: true };
  });

  out.adminReleaseIp = onCall(async (request) => {
    const adminUser = await requireAdmin(request);
    const ipHash = (request.data && request.data.ipHash) || "";
    if (!ipHash) throw new HttpsError("invalid-argument", "ipHash required.");
    await db().collection("ip_rate_limits").doc(ipHash).set({ blockedUntil: null, failedCount: 0, releasedAt: now(), releasedBy: adminUser.uid }, { merge: true });
    await logHistory({ type: "ip_released", ipHash, by: adminUser.uid, byEmail: adminUser.email || "" });
    return { success: true };
  });

  // ---------- Support workflow ----------
  /** Resend (Svix) signature verification. */
  function verifySvix(req, secret) {
    const id = req.headers["svix-id"];
    const ts = req.headers["svix-timestamp"];
    const sigHeader = req.headers["svix-signature"];
    if (!id || !ts || !sigHeader) return false;
    if (Math.abs(Math.floor(now() / 1000) - Number(ts)) > 300) return false;
    const key = Buffer.from(secret.replace(/^whsec_/, ""), "base64");
    const raw = req.rawBody ? req.rawBody.toString("utf8") : JSON.stringify(req.body);
    const expected = crypto.createHmac("sha256", key).update(`${id}.${ts}.${raw}`).digest("base64");
    return sigHeader.split(" ").some((part) => {
      const sig = part.split(",")[1];
      if (!sig) return false;
      const a = Buffer.from(sig);
      const b = Buffer.from(expected);
      return a.length === b.length && crypto.timingSafeEqual(a, b);
    });
  }

  function parseAddress(from) {
    const m = /<([^>]+)>/.exec(from || "");
    return normEmail(m ? m[1] : from);
  }

  out.resendInboundWebhook = onRequest({ secrets: [RESEND_WEBHOOK_SECRET] }, async (req, res) => {
    if (req.method !== "POST") return res.status(405).send("Method Not Allowed");
    if (!verifySvix(req, RESEND_WEBHOOK_SECRET.value())) {
      logger.warn("Resend webhook signature invalid");
      return res.status(401).send("Invalid signature");
    }
    try {
      const event = req.body || {};
      const type = event.type;
      const data = event.data || {};

      if (type === "email.received" || type === "inbox.email.received") {
        const emailId = data.email_id || data.id;
        if (!emailId) return res.status(200).send("no email_id");
        const dup = await db().collection("support_requests").where("resendEmailId", "==", emailId).limit(1).get();
        if (!dup.empty) return res.status(200).send("duplicate");

        let html = "";
        let text = "";
        try {
          const r = await fetch(`https://api.resend.com/emails/receiving/${emailId}`, { headers: { Authorization: `Bearer ${resendApiKey}` } });
          if (r.ok) {
            const j = await r.json();
            html = j.html || "";
            text = j.text || "";
          } else {
            logger.warn("Receiving API fetch failed", r.status);
          }
        } catch (e) {
          logger.error("Receiving API error", e);
        }

        const fromEmail = parseAddress(data.from);
        // Link to a known account (best effort)
        let account = {};
        const sec = await db().collection("login_security").doc(sha(fromEmail)).get();
        if (sec.exists) account = { stage: sec.data().stage || 0, app: sec.data().app || "", locked: !!sec.data().indefinite || (sec.data().lockedUntil || 0) > now(), emailHash: sha(fromEmail) };

        const plainText = text || (html ? html.replace(/<[^>]*>?/gm, " ").replace(/\s+/g, " ").trim() : "");

        const ref = await db().collection("support_requests").add({
          resendEmailId: emailId,
          from: data.from || "",
          fromEmail,
          to: data.to || [],
          subject: data.subject || "(no subject)",
          preview: (plainText || "(No content)").slice(0, 200),
          status: "open",
          direction: "inbound",
          account,
          createdAt: FieldValue().serverTimestamp(),
          updatedAt: FieldValue().serverTimestamp(),
        });
        await ref.collection("messages").add({
          direction: "inbound",
          from: data.from || "",
          subject: data.subject || "",
          html,
          text,
          createdAt: FieldValue().serverTimestamp(),
        });
        return res.status(200).send("stored");
      }

      // Delivery status for admin replies
      const statusMap = {
        "email.delivered": "delivered",
        "email.bounced": "bounced",
        "email.failed": "failed",
        "email.delivery_delayed": "delayed",
        "email.complained": "complained",
      };
      const deliveryEmailId = data.email_id || data.id;
      if (statusMap[type] && deliveryEmailId) {
        const q = await db().collectionGroup("messages").where("resendId", "==", deliveryEmailId).limit(1).get();
        if (!q.empty) await q.docs[0].ref.set({ deliveryStatus: statusMap[type], deliveryUpdatedAt: FieldValue().serverTimestamp() }, { merge: true });
      }
      return res.status(200).send("ok");
    } catch (e) {
      logger.error("resendInboundWebhook error", e);
      return res.status(500).send("error");
    }
  });

  /** Admin: compose a new email or reply to a request. Same HTML builder as the live preview. */
  out.adminSendSupportReply = onCall(async (request) => {
    const adminUser = await requireAdmin(request);
    const d = request.data || {};
    const to = normEmail(d.to);
    const subject = (d.subject || "").toString().trim();
    const message = (d.message || "").toString().trim();
    if (!to || !subject || !message) throw new HttpsError("invalid-argument", "to, subject and message are required.");
    const cfg = await getConfig();
    const bodyHtml = message.split(/\n{2,}/).map((p) => `<p>${escapeHtml(p).replace(/\n/g, "<br/>")}</p>`).join("");
    const html = brandedEmail({ title: subject, bodyHtml });
    const sent = await sendEmail({ to, subject, html, replyTo: cfg.supportEmail });
    if (!sent.ok) throw new HttpsError("internal", "Email delivery failed.");

    let reqRef;
    if (d.requestId) {
      reqRef = db().collection("support_requests").doc(d.requestId);
      await reqRef.set({ status: "replied", updatedAt: FieldValue().serverTimestamp() }, { merge: true });
    } else {
      reqRef = await db().collection("support_requests").add({
        from: cfg.supportEmail, fromEmail: to, to: [to], subject, preview: message.slice(0, 200),
        status: "replied", direction: "outbound", createdAt: FieldValue().serverTimestamp(), updatedAt: FieldValue().serverTimestamp(),
      });
    }
    await reqRef.collection("messages").add({
      direction: "outbound", from: cfg.supportEmail, to, subject, html, text: message,
      resendId: sent.id || "", sentBy: adminUser.uid, sentByEmail: adminUser.email || "", createdAt: FieldValue().serverTimestamp(),
    });
    return { success: true, requestId: reqRef.id };
  });

  out.adminSetSupportStatus = onCall(async (request) => {
    await requireAdmin(request);
    const { requestId, status } = request.data || {};
    if (!requestId || !["open", "replied", "closed"].includes(status)) throw new HttpsError("invalid-argument", "Invalid input.");
    await db().collection("support_requests").doc(requestId).set({ status, updatedAt: FieldValue().serverTimestamp() }, { merge: true });
    return { success: true };
  });

  /** Daily housekeeping: drop idle IP records. */
  out.securityCleanup = onSchedule("every 24 hours", async () => {
    const cutoff = now() - 7 * 24 * 3600 * 1000;
    const snap = await db().collection("ip_rate_limits").where("lastAttemptAt", "<", cutoff).limit(400).get();
    const batch = db().batch();
    snap.docs.forEach((d) => {
      const b = d.data().blockedUntil;
      if (!b || b < now()) batch.delete(d.ref);
    });
    await batch.commit();
  });

  return out;
};

module.exports.brandedEmail = brandedEmail;

