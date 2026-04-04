/**
 * WhatsApp Cloud API — sends an approved template to the signed-in user's phone.
 *
 * Setup:
 * 1. Meta Developer → WhatsApp → get permanent token, Phone number ID, verify template (e.g. hello_world).
 * 2. firebase functions:config:set whatsapp.token="EAAG..." whatsapp.phone_number_id="123456789"
 * 3. firebase deploy --only functions
 *
 * Optional override: whatsapp.template_default for template name (default hello_world).
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * @param {string} raw E.164 or digits
 */
function whatsappToDigits(raw) {
  if (!raw || typeof raw !== 'string') return '';
  return raw.replace(/\D/g, '');
}

exports.sendUserWhatsApp = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  const tokenPhone = context.auth.token.phone_number;
  const digits = whatsappToDigits(tokenPhone || '');
  if (!digits || digits.length < 10) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'WhatsApp notifications require phone (OTP) sign-in so we know your number.',
    );
  }

  const cfg = functions.config().whatsapp || {};
  const graphToken = process.env.WHATSAPP_TOKEN || cfg.token;
  const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID || cfg.phone_number_id;
  if (!graphToken || !phoneNumberId) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'WhatsApp is not configured. Set whatsapp.token and whatsapp.phone_number_id (Firebase Functions config).',
    );
  }

  const templateName =
    (data && data.templateName) ||
    cfg.template_default ||
    'hello_world';
  const languageCode = (data && data.languageCode) || 'en_US';

  const url = `https://graph.facebook.com/v21.0/${phoneNumberId}/messages`;
  const body = {
    messaging_product: 'whatsapp',
    to: digits,
    type: 'template',
    template: {
      name: String(templateName),
      language: { code: String(languageCode) },
    },
  };

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${graphToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    functions.logger.error('WhatsApp API error', { status: res.status, json });
    throw new functions.https.HttpsError(
      'internal',
      json.error && json.error.message
        ? json.error.message
        : `WhatsApp HTTP ${res.status}`,
    );
  }

  functions.logger.info('WhatsApp sent', {
    uid: context.auth.uid,
    kind: data && data.kind,
    dressType: data && data.dressType,
  });

  return { ok: true, messageId: json.messages && json.messages[0] && json.messages[0].id };
});
