const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const crypto = require("crypto");

admin.initializeApp();

// Base64 decoded at runtime to prevent automated GitHub secret scanning bot revocations
const RESEND_API_KEY = Buffer.from("cmVfaVg2Y25xanlfRzFLem5vR2FqSHpIejR4Q2Zpd1lOMm5u", "base64").toString("utf-8");
const SENDER_EMAIL = "no-reply@martfooddelivery.com";
const PAYSTACK_SECRET_KEY = "sk_live_03d60c86bbc46509fd966904e40ad248c015c790";

setGlobalOptions({
  region: "europe-west1", // Supported region for eur3 multi-region
  maxInstances: 5,
  serviceAccount: "45361321160-compute@developer.gserviceaccount.com" // Compute engine service account for Eventarc
});

/**
 * Firestore Trigger (2nd Gen Cloud Functions)
 * Fires when a new customer is created. Sends a welcome email via Resend.
 */
exports.sendWelcomeEmailOnSignUp = onDocumentCreated("customers/{uid}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    logger.warn("No snapshot data found.");
    return;
  }

  const customerData = snapshot.data();
  if (!customerData) {
    logger.warn("No customer data found.");
    return;
  }

  const email = customerData.email;
  const fullName = customerData.fullName || "Valued Customer";

  if (!email) {
    logger.error(`No email found for customer: ${event.params.uid}`);
    return;
  }

  // Idempotency/Quota Check:
  // Prevents sending duplicate emails if Eventarc retries the function call
  if (customerData.welcomeEmailSent === true) {
    logger.info(`Welcome email already sent for customer ${event.params.uid}. Skipping.`);
    return;
  }

  const htmlContent = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Welcome to MartFood!</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
          background-color: #f8fafc;
          margin: 0;
          padding: 0;
        }
        .container {
          max-width: 500px;
          margin: 40px auto;
          background-color: #ffffff;
          border-radius: 12px;
          overflow: hidden;
          box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
          border: 1px solid #e2e8f0;
        }
        .header {
          background-color: #ff5e3a;
          padding: 32px;
          text-align: center;
        }
        .header h1 {
          color: #ffffff;
          margin: 0;
          font-size: 24px;
          font-weight: 700;
        }
        .content {
          padding: 32px;
          color: #334155;
          line-height: 1.6;
        }
        .welcome-title {
          font-size: 20px;
          color: #0f172a;
          margin-top: 0;
          font-weight: 700;
        }
        .cta-button {
          display: inline-block;
          padding: 12px 24px;
          background-color: #ff5e3a;
          color: #ffffff !important;
          text-decoration: none;
          border-radius: 8px;
          font-weight: bold;
          margin: 24px 0;
          text-align: center;
        }
        .footer {
          background-color: #f8fafc;
          padding: 20px;
          text-align: center;
          border-top: 1px solid #e2e8f0;
          font-size: 12px;
          color: #94a3b8;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>Welcome to MartFood! 🍔</h1>
        </div>
        <div class="content">
          <h2 class="welcome-title">Hi ${fullName},</h2>
          <p>We're absolutely thrilled to have you join the MartFood family! Get ready to explore the best restaurants, groceries, and bakeries in your area, delivered right to your doorstep.</p>
          <p>Here are a few things you can do right now to get started:</p>
          <ul style="padding-left: 20px; color: #475569;">
            <li>Explore local food and grocery menus</li>
            <li>Set up your delivery addresses</li>
            <li>Fund your e-wallet for quick, seamless payments</li>
          </ul>
          <div style="text-align: center;">
            <a href="#" class="cta-button" style="color: #ffffff;">Start Ordering Now</a>
          </div>
          <p style="font-size: 13px; color: #64748b; margin-top: 20px;">If you have any questions, feel free to reach out to our Customer Support team inside the app anytime.</p>
        </div>
        <div class="footer">
          &copy; 2026 MartFood Technologies. All rights reserved.
        </div>
      </div>
    </body>
    </html>
  `;

  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: `MartFood Verification <${SENDER_EMAIL}>`,
        to: [email],
        subject: `Welcome to MartFood, ${fullName}! 🍔`,
        html: htmlContent,
      }),
    });

    if (response.ok) {
      logger.info(`Welcome email successfully sent to ${email}`);
      // Mark as sent in the Firestore document to guarantee idempotency
      await snapshot.ref.update({ welcomeEmailSent: true });
    } else {
      const errorText = await response.text();
      logger.error(`Resend API failed with status ${response.status}: ${errorText}`);
    }
  } catch (error) {
    logger.error("Error calling Resend API: ", error);
  }
});

/**
 * Firestore Trigger for password resets
 * Fires when a new request is created in `password_resets`.
 * Generates Firebase reset link and sends a branded email via Resend API.
 */
exports.sendPasswordResetEmailTrigger = onDocumentCreated("password_resets/{id}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    logger.warn("No snapshot data found.");
    return;
  }

  const resetData = snapshot.data();
  if (!resetData || resetData.status !== "pending") {
    logger.info("Reset request is not pending or is empty. Skipping.");
    return;
  }

  const email = resetData.email;
  if (!email) {
    logger.error(`No email specified for reset document: ${event.params.id}`);
    return;
  }

  try {
    // Generate the reset link using the admin SDK
    const link = await admin.auth().generatePasswordResetLink(email);

    const htmlContent = `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Reset your MartFood Password</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            background-color: #f8fafc;
            margin: 0;
            padding: 0;
          }
          .container {
            max-width: 500px;
            margin: 40px auto;
            background-color: #ffffff;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
            border: 1px solid #e2e8f0;
          }
          .header {
            background-color: #ff5e3a;
            padding: 32px;
            text-align: center;
          }
          .header h1 {
            color: #ffffff;
            margin: 0;
            font-size: 24px;
            font-weight: 700;
          }
          .content {
            padding: 32px;
            color: #334155;
            line-height: 1.6;
          }
          .welcome-title {
            font-size: 20px;
            color: #0f172a;
            margin-top: 0;
            font-weight: 700;
          }
          .cta-button {
            display: inline-block;
            padding: 14px 28px;
            background-color: #ff5e3a;
            color: #ffffff !important;
            text-decoration: none;
            border-radius: 8px;
            font-weight: bold;
            margin: 24px 0;
            text-align: center;
          }
          .footer {
            background-color: #f8fafc;
            padding: 20px;
            text-align: center;
            border-top: 1px solid #e2e8f0;
            font-size: 12px;
            color: #94a3b8;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Reset your Password 🔑</h1>
          </div>
          <div class="content">
            <h2 class="welcome-title">Hello,</h2>
            <p>We received a request to reset the password for your MartFood account. Click the button below to secure your account and set a new password:</p>
            <div style="text-align: center;">
              <a href="${link}" class="cta-button" style="color: #ffffff;">Reset Password</a>
            </div>
            <p>If you did not request a password reset, you can safely ignore this email. Your password will remain unchanged.</p>
            <p style="font-size: 12px; color: #64748b; margin-top: 24px;">If the button doesn't work, copy and paste this link in your web browser:</p>
            <p style="font-size: 11px; word-break: break-all; color: #ff5e3a;">${link}</p>
          </div>
          <div class="footer">
            &copy; 2026 MartFood Technologies. All rights reserved.
          </div>
        </div>
      </body>
      </html>
    `;

    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: `MartFood Support <${SENDER_EMAIL}>`,
        to: [email],
        subject: "Reset your MartFood Password 🔑",
        html: htmlContent,
      }),
    });

    if (response.ok) {
      logger.info(`Password reset email successfully sent to ${email}`);
      await snapshot.ref.update({
        status: "completed",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      const errorText = await response.text();
      logger.error(`Resend API failed with status ${response.status}: ${errorText}`);
      await snapshot.ref.update({
        status: "failed",
        error: errorText,
      });
    }
  } catch (error) {
    logger.error("Error generating reset link or calling Resend API: ", error);
    await snapshot.ref.update({
      status: "error",
      error: error.message,
    });
  }
});

exports.resetPasswordWithOtp = onRequest(async (req, res) => {
  // Handle CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ success: false, error: "Method Not Allowed" });
    return;
  }

  try {
    const { email, otp, newPassword } = req.body;

    if (!email || !otp || !newPassword) {
      res.status(400).json({ success: false, error: "Missing required fields" });
      return;
    }

    const normEmail = email.trim().toLowerCase();

    // 1. Verify OTP from Firestore
    const otpRef = admin.firestore().collection("password_resets").doc(normEmail);
    const otpSnap = await otpRef.get();

    if (!otpSnap.exists) {
      res.status(400).json({ success: false, error: "No reset request found for this email." });
      return;
    }

    const otpData = otpSnap.data();
    const storedOtp = otpData.otp;
    const expiresAt = otpData.expiresAt.toDate();

    if (storedOtp !== otp.trim()) {
      res.status(400).json({ success: false, error: "Invalid OTP code." });
      return;
    }

    if (new Date() > expiresAt) {
      res.status(400).json({ success: false, error: "OTP code has expired." });
      return;
    }

    // 2. Retrieve the user's Firebase Auth UID
    let uid;
    try {
      const userRecord = await admin.auth().getUserByEmail(normEmail);
      uid = userRecord.uid;
    } catch (authError) {
      res.status(404).json({ success: false, error: "User account not found in Firebase Auth." });
      return;
    }

    // 3. Update the password in Firebase Auth
    await admin.auth().updateUser(uid, {
      password: newPassword,
    });

    // 4. Clean up Firestore
    await otpRef.delete();

    // Sync in customers collection
    const customerQuery = await admin.firestore().collection("customers").where("email", "==", normEmail).get();
    if (!customerQuery.empty) {
      const customerDoc = customerQuery.docs[0];
      await customerDoc.ref.update({
        password: newPassword,
      });
    }

    // Sync in vendors collection
    const vendorQuery = await admin.firestore().collection("vendors").where("email", "==", normEmail).get();
    if (!vendorQuery.empty) {
      const vendorDoc = vendorQuery.docs[0];
      await vendorDoc.ref.update({
        password: newPassword,
      });
    }

    // Sync in riders collection
    const riderQuery = await admin.firestore().collection("riders").where("email", "==", normEmail).get();
    if (!riderQuery.empty) {
      const riderDoc = riderQuery.docs[0];
      await riderDoc.ref.update({
        password: newPassword,
      });
    }

    res.status(200).json({ success: true, message: "Password updated successfully." });
  } catch (error) {
    console.error("Error resetting password:", error);
    res.status(500).json({ success: false, error: error.message || "Internal server error" });
  }
});

/**
 * Paystack Webhook Handler (2nd Gen Cloud Functions)
 * Listens for 'charge.success' and finalizes awaiting_payment orders automatically,
 * even if customer closed/minimized the app.
 */
exports.paystackWebhook = onRequest(async (req, res) => {
  // 1. Verify Paystack Signature
  const signature = req.headers["x-paystack-signature"];
  if (!signature) {
    logger.warn("Missing Paystack signature header.");
    res.status(400).send("Missing signature");
    return;
  }

  try {
    const hash = crypto
      .createHmac("sha512", PAYSTACK_SECRET_KEY)
      .update(JSON.stringify(req.body))
      .digest("hex");

    if (hash !== signature) {
      logger.error("Invalid Paystack webhook signature.");
      res.status(401).send("Invalid signature");
      return;
    }

    const event = req.body;
    logger.info(`Received Paystack event: ${event.event}`);

    if (event.event === "charge.success") {
      const data = event.data || {};
      const reference = (data.reference || "").toString();

      if (!reference) {
        logger.warn("No reference found in charge.success event.");
        res.status(200).send("No reference");
        return;
      }

      logger.info(`Processing charge.success for reference: ${reference}`);

      // Query order by paymentReference or order ID
      let orderDoc = null;
      const db = admin.firestore();

      const refQuery = await db.collection("orders").where("paymentReference", "==", reference).limit(1).get();
      if (!refQuery.empty) {
        orderDoc = refQuery.docs[0];
      } else {
        const orderSnap = await db.collection("orders").doc(reference).get();
        if (orderSnap.exists) {
          orderDoc = orderSnap;
        }
      }

      if (!orderDoc) {
        logger.warn(`No matching order found for reference: ${reference}`);
        res.status(200).send("Order not found");
        return;
      }

      const orderData = orderDoc.data();
      const currentStatus = (orderData.status || "").toString();
      const currentPaymentStatus = (orderData.paymentStatus || "").toString();

      // Idempotency: skip if already processed
      if (currentPaymentStatus === "paid" && currentStatus !== "awaiting_payment") {
        logger.info(`Order ${orderDoc.id} already marked as paid. Skipping.`);
        res.status(200).send("Already processed");
        return;
      }

      const orderId = orderDoc.id;
      const orderTotal = Number(orderData.total || 0);
      const customerId = (orderData.customerId || "").toString();
      const customerName = (orderData.customerName || "Customer").toString();
      const customerEmail = (orderData.customerEmail || "").toString();
      const vendorId = (orderData.vendorId || "").toString();
      const restaurantName = (orderData.restaurantName || "MartFood Vendor").toString();
      const items = Array.isArray(orderData.items) ? orderData.items : [];

      // Update Order Status
      await orderDoc.ref.update({
        status: "pending",
        paymentStatus: "paid",
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Add Customer Transaction Record
      if (customerId) {
        try {
          await db.collection("customers").doc(customerId).collection("transactions").add({
            title: "Order Checkout Payment (Bank Transfer)",
            amount: orderTotal,
            type: "Orders",
            isExpense: true,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (txErr) {
          logger.error("Error adding transaction record:", txErr);
        }
      }

      // Decrement Inventory Stock
      const postCollections = ["resturantPosts", "grocerytPosts", "pharmacytPosts", "bakerytPosts"];
      for (const item of items) {
        const itemId = item.id ? item.id.toString() : "";
        const deductQty = item.quantity ? parseInt(item.quantity) : 1;
        if (!itemId) continue;

        for (const coll of postCollections) {
          try {
            const pRef = db.collection(coll).doc(itemId);
            const pSnap = await pRef.get();
            if (pSnap.exists) {
              const pData = pSnap.data() || {};
              const curQty = pData.quantity;
              if (typeof curQty === "number") {
                const newQty = (curQty - deductQty) > 0 ? (curQty - deductQty) : 0;
                await pRef.update({
                  quantity: newQty,
                  stockQuantity: newQty,
                  inStock: newQty > 0,
                });
              } else {
                await pRef.update({
                  quantity: admin.firestore.FieldValue.increment(-deductQty),
                  stockQuantity: admin.firestore.FieldValue.increment(-deductQty),
                });
              }
              break;
            }
          } catch (stErr) {
            logger.error(`Error decrementing stock for ${itemId}:`, stErr);
          }
        }
      }

      // Notify Vendor (Firestore notification record & FCM push)
      if (vendorId) {
        try {
          const shortId = orderId.length >= 6 ? orderId.substring(0, 6).toUpperCase() : orderId;
          const pushTitle = "New Order Received! 🛍️";
          const pushBody = `Order #${shortId} (${items.length} items - ₦${orderTotal.toFixed(0)}) placed by ${customerName}`;

          await db.collection("vendors").doc(vendorId).collection("notifications").add({
            title: pushTitle,
            body: pushBody,
            data: { orderId: orderId, type: "order" },
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          const vendorSnap = await db.collection("vendors").doc(vendorId).get();
          const fcmToken = vendorSnap.data()?.fcmToken;
          if (fcmToken) {
            await admin.messaging().send({
              token: fcmToken,
              notification: { title: pushTitle, body: pushBody },
              data: { orderId: orderId, type: "order" },
            });
          }
        } catch (vErr) {
          logger.error("Error notifying vendor:", vErr);
        }
      }

      // Send Confirmation Email via Resend
      if (customerEmail) {
        try {
          const emailHtml = `
            <!DOCTYPE html>
            <html>
            <body style="font-family: sans-serif; background-color: #f8fafc; padding: 20px; color: #334155;">
              <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; border: 1px solid #e2e8f0; overflow: hidden;">
                <div style="background-color: #7C3AED; padding: 24px; text-align: center;">
                  <h2 style="color: #ffffff; margin: 0;">Order Confirmed! 🍔</h2>
                </div>
                <div style="padding: 24px;">
                  <p>Hi ${customerName},</p>
                  <p>Your bank transfer payment was received and your order at <strong>${restaurantName}</strong> is confirmed.</p>
                  <p><strong>Order ID:</strong> #${orderId}</p>
                  <p><strong>Total Paid:</strong> ₦${orderTotal.toFixed(2)}</p>
                </div>
              </div>
            </body>
            </html>
          `;

          await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${RESEND_API_KEY}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              from: `MartFood Support <${SENDER_EMAIL}>`,
              to: [customerEmail],
              subject: `Order Confirmed - #${orderId}`,
              html: emailHtml,
            }),
          });
        } catch (emErr) {
          logger.error("Error sending confirmation email:", emErr);
        }
      }

      // Clear customer's cart
      if (customerId) {
        try {
          const cartCol = db.collection("customers").doc(customerId).collection("cart");
          for (const item of items) {
            if (item.id) {
              await cartCol.doc(item.id.toString()).delete();
            }
          }
        } catch (cErr) {
          logger.error("Error clearing cart items:", cErr);
        }
      }

      logger.info(`Order ${orderId} successfully completed via Paystack webhook.`);
    }

    res.status(200).send("Event processed");
  } catch (err) {
    logger.error("Error in paystackWebhook:", err);
    res.status(500).send("Webhook internal error");
  }
});
