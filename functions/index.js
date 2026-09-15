const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

// Declare Server-Side Environment Secrets
const textbeeDeviceId = defineSecret("TEXTBEE_DEVICE_ID");
const textbeeApiKey = defineSecret("TEXTBEE_API_KEY");
const emergencyEmail = defineSecret("EMERGENCY_EMAIL");
const emergencyEmailAppPassword = defineSecret("EMERGENCY_EMAIL_APP_PASSWORD");

const ALL_SECRETS = [
  textbeeDeviceId,
  textbeeApiKey,
  emergencyEmail,
  emergencyEmailAppPassword,
];

// Helper: Enable CORS headers for mobile and web apps
function setCorsHeaders(req, res) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization, x-api-key");
}

// Helper: Dispatch SMS via TextBee Cloud Gateway
async function sendTextBeeSms(apiKey, deviceId, phoneNumber, message) {
  let cleanPhone = (phoneNumber || "").toString().replace(/[\s\-()]/g, "");
  if (!cleanPhone) {
    return { success: false, error: "Empty recipient phone number" };
  }
  if (cleanPhone.length === 10 && !cleanPhone.startsWith("+")) {
    cleanPhone = "+91" + cleanPhone;
  }

  const endpoint = deviceId && deviceId.trim()
    ? `https://api.textbee.dev/api/v1/gateway/devices/${deviceId.trim()}/send-sms`
    : "https://api.textbee.dev/api/v1/gateway/send-sms";

  const payload = {
    recipients: [cleanPhone],
    message: message,
  };
  if (deviceId && deviceId.trim()) {
    payload.deviceId = deviceId.trim();
  }

  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey.trim(),
      },
      body: JSON.stringify(payload),
    });

    const responseData = await response.json().catch(() => ({}));
    if (response.ok) {
      return {
        success: true,
        recipient: cleanPhone,
        status: "accepted",
        statusDisplay: "Dispatch accepted",
        method: "TextBee Cloud Gateway",
        data: responseData,
      };
    } else {
      return {
        success: false,
        recipient: cleanPhone,
        status: "failed",
        statusDisplay: `Failed (${response.status})`,
        error: responseData.message || `HTTP ${response.status}`,
      };
    }
  } catch (err) {
    return {
      success: false,
      recipient: cleanPhone,
      status: "failed",
      statusDisplay: "Network Error",
      error: err.message,
    };
  }
}

// Helper: Dispatch Email via Gmail SMTP using Nodemailer
async function sendEmergencyEmail(userEmail, appPassword, recipientEmail, subject, textContent, htmlContent) {
  if (!recipientEmail || !recipientEmail.includes("@")) {
    return { success: false, error: "Invalid recipient email address" };
  }

  const cleanEmail = (userEmail || "").trim();
  const cleanPass = (appPassword || "").trim().replace(/\s/g, "");

  if (!cleanEmail || !cleanPass) {
    return { success: false, error: "Emergency email server credentials not configured on backend" };
  }

  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: cleanEmail,
      pass: cleanPass,
    },
  });

  try {
    const info = await transporter.sendMail({
      from: `"Accident Guard System" <${cleanEmail}>`,
      to: recipientEmail.trim(),
      subject: subject,
      text: textContent,
      html: htmlContent || textContent,
    });

    return {
      success: true,
      recipient: recipientEmail,
      messageId: info.messageId,
      status: "250 OK",
      method: "Gmail SMTP Secure Relay",
    };
  } catch (err) {
    return {
      success: false,
      recipient: recipientEmail,
      status: "SMTP Failed",
      error: err.message,
    };
  }
}

/**
 * 🚨 /emergencyDispatch
 * Centralized endpoint to dispatch both SMS and Email alerts concurrently for confirmed crash events.
 */
exports.emergencyDispatch = onRequest(
  { secrets: ALL_SECRETS, cors: true, timeoutSeconds: 30 },
  async (req, res) => {
    setCorsHeaders(req, res);
    if (req.method === "OPTIONS") {
      return res.status(204).send("");
    }

    if (req.method !== "POST") {
      return res.status(405).json({ error: "Method Not Allowed. Use POST." });
    }

    const {
      parentPhone,
      hospitalPhone,
      hospitalPhones,
      recipientEmail,
      driverName = "Driver",
      bloodGroup = "O+",
      accidentType = "Impact Collision",
      impactMagnitude = 35.0,
      latitude,
      longitude,
      hospitalInfo,
      timestamp = new Date().toISOString(),
    } = req.body || {};

    const apiKey = textbeeApiKey.value();
    const deviceId = textbeeDeviceId.value();
    const emailSender = emergencyEmail.value();
    const emailPass = emergencyEmailAppPassword.value();

    const locationUrl = (latitude && longitude)
      ? `https://maps.google.com/?q=${latitude},${longitude}`
      : "GPS Signal Unavailable";

    const emergencySmsBody = `🚨 CRITICAL ACCIDENT ALERT 🚨\nDriver: ${driverName} (${bloodGroup})\nCrash: ${accidentType} (${Number(impactMagnitude).toFixed(1)} m/s²)\nGPS Location: ${locationUrl}\nImmediate emergency assistance requested.`;

    const emailSubject = `🚨 CRITICAL ACCIDENT ALERT: ${driverName}`;
    const emailBody = `ACCIDENT GUARD EMERGENCY DISPATCH\n` +
      `-----------------------------------------\n` +
      `Driver: ${driverName}\n` +
      `Blood Group: ${bloodGroup}\n` +
      `Crash Vector: ${accidentType} (${Number(impactMagnitude).toFixed(1)} m/s²)\n` +
      `Time: ${timestamp}\n` +
      `GPS Coordinates: ${latitude || "N/A"}, ${longitude || "N/A"}\n` +
      `Live Map Link: ${locationUrl}\n` +
      `Nearest Medical Facility: ${typeof hospitalInfo === "string" ? hospitalInfo : JSON.stringify(hospitalInfo || "Queried via OpenStreetMap")}\n` +
      `-----------------------------------------\n` +
      `Dispatched by Accident Guard Centralized Cloud Backend.`;

    const errors = [];
    const dispatchPromises = [];

    // 1. Dispatch Parent SMS
    let parentSmsPromise = Promise.resolve(null);
    if (parentPhone && parentPhone.trim().length > 0) {
      parentSmsPromise = sendTextBeeSms(apiKey, deviceId, parentPhone, emergencySmsBody);
    }
    dispatchPromises.push(parentSmsPromise);

    // 2. Dispatch Hospital SMS
    const targetHospitalPhone = hospitalPhone || (Array.isArray(hospitalPhones) && hospitalPhones.length > 0 ? hospitalPhones[0] : null);
    let hospitalSmsPromise = Promise.resolve(null);
    if (targetHospitalPhone && targetHospitalPhone.trim().length > 0) {
      hospitalSmsPromise = sendTextBeeSms(apiKey, deviceId, targetHospitalPhone, emergencySmsBody);
    }
    dispatchPromises.push(hospitalSmsPromise);

    // 3. Dispatch Email
    let emailPromise = Promise.resolve(null);
    if (recipientEmail && recipientEmail.includes("@")) {
      emailPromise = sendEmergencyEmail(emailSender, emailPass, recipientEmail, emailSubject, emailBody);
    }
    dispatchPromises.push(emailPromise);

    // Execute concurrently
    const [parentSmsResult, hospitalSmsResult, emailResult] = await Promise.all(dispatchPromises);

    if (parentSmsResult && !parentSmsResult.success) {
      errors.push({ channel: "parentSms", error: parentSmsResult.error });
    }
    if (hospitalSmsResult && !hospitalSmsResult.success) {
      errors.push({ channel: "hospitalSms", error: hospitalSmsResult.error });
    }
    if (emailResult && !emailResult.success) {
      errors.push({ channel: "email", error: emailResult.error });
    }

    const smsAccepted = (parentSmsResult?.success === true) || (hospitalSmsResult?.success === true);
    const emailSent = emailResult?.success === true;

    return res.status(200).json({
      success: smsAccepted || emailSent,
      smsAccepted,
      emailSent,
      parentSmsResult,
      hospitalSmsResult,
      emailResult,
      errors,
      timestamp: new Date().toISOString(),
    });
  }
);

/**
 * 📲 /testSms
 * Test endpoint to verify centralized TextBee SMS configuration without triggering a crash.
 */
exports.testSms = onRequest(
  { secrets: [textbeeDeviceId, textbeeApiKey], cors: true, timeoutSeconds: 15 },
  async (req, res) => {
    setCorsHeaders(req, res);
    if (req.method === "OPTIONS") {
      return res.status(204).send("");
    }

    const recipientPhone = req.body?.recipientPhone || req.query?.recipientPhone;
    if (!recipientPhone) {
      return res.status(400).json({ success: false, error: "recipientPhone parameter is required." });
    }

    const apiKey = textbeeApiKey.value();
    const deviceId = textbeeDeviceId.value();
    const testMsg = "🚨 TEST: Accident Guard System SMS Verification. Centralized Cloud SMS Gateway is active and functional.";

    const result = await sendTextBeeSms(apiKey, deviceId, recipientPhone, testMsg);
    return res.status(result.success ? 200 : 500).json(result);
  }
);

/**
 * ✉️ /testEmail
 * Test endpoint to verify centralized Gmail SMTP email configuration without triggering a crash.
 */
exports.testEmail = onRequest(
  { secrets: [emergencyEmail, emergencyEmailAppPassword], cors: true, timeoutSeconds: 15 },
  async (req, res) => {
    setCorsHeaders(req, res);
    if (req.method === "OPTIONS") {
      return res.status(204).send("");
    }

    const recipientEmail = req.body?.recipientEmail || req.query?.recipientEmail;
    if (!recipientEmail || !recipientEmail.includes("@")) {
      return res.status(400).json({ success: false, error: "Valid recipientEmail parameter is required." });
    }

    const emailSender = emergencyEmail.value();
    const emailPass = emergencyEmailAppPassword.value();
    const subject = "🚨 TEST: Accident Guard Cloud Email Verification";
    const body = "This is a verified test email from the Accident Guard Centralized Cloud Backend.\n" +
      "Emergency notifications are configured and functioning properly.";

    const result = await sendEmergencyEmail(emailSender, emailPass, recipientEmail, subject, body);
    return res.status(result.success ? 200 : 500).json(result);
  }
);
