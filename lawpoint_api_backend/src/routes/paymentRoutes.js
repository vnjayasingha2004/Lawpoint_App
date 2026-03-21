const express = require('express');
const crypto = require('crypto');
const { z } = require('zod');

const { all, get, run } = require('../db');
const { authRequired, requireRole } = require('../middleware/auth');
const { validateBody } = require('../middleware/validate');
const { nowIso } = require('../utils/time');
const { writeAudit } = require('../services/auditService');
const { hydrateUser } = require('../services/userService');
const { createNotification } = require('../services/notificationService');

const router = express.Router();

const checkoutSessionSchema = z.object({
  appointmentId: z.string().trim().min(1, 'appointmentId is required.'),
  amount: z.coerce.number().positive().optional(),
  currency: z
    .preprocess((value) => {
      if (value == null) return 'LKR';
      return String(value).trim().toUpperCase();
    }, z.string().length(3))
    .optional(),
});

async function getClientProfileId(userId) {
  const profile = await get(
    `SELECT * FROM public."ClientProfile" WHERE "userId" = ?`,
    [userId]
  );
  return profile ? profile.id : null;
}

async function getLawyerProfileId(userId) {
  const profile = await get(
    `SELECT * FROM public."LawyerProfile" WHERE "userId" = ?`,
    [userId]
  );
  return profile ? profile.id : null;
}

function upperMd5(value) {
  return crypto.createHash('md5').update(String(value)).digest('hex').toUpperCase();
}

function formatAmount(value) {
  return Number(value || 0).toFixed(2);
}

function payHereHash({ merchantId, orderId, amount, currency, merchantSecret }) {
  return upperMd5(
    merchantId +
      orderId +
      formatAmount(amount) +
      currency +
      upperMd5(merchantSecret)
  );
}

function payHereNotifySig({
  merchantId,
  orderId,
  amount,
  currency,
  statusCode,
  merchantSecret,
}) {
  return upperMd5(
    merchantId +
      orderId +
      amount +
      currency +
      statusCode +
      upperMd5(merchantSecret)
  );
}

function mapGatewayStatus(statusCode) {
  switch (String(statusCode)) {
    case '2':
      return 'PAID';
    case '0':
      return 'PENDING';
    case '-1':
      return 'CANCELLED';
    case '-2':
    case '-3':
      return 'FAILED';
    default:
      return 'PENDING';
  }
}

function buildReceipt(row) {
  return row.paymentStatus === 'PAID'
    ? {
        receiptId: `R-${row.id}`,
        transactionId: row.gatewayTransactionId || row.id,
        amount: Number(row.amount || 0),
        currency: row.currency || 'LKR',
        paidAt: row.paidAt,
        service: 'Legal consultation',
      }
    : null;
}

function mapPaymentFromAppointment(row) {
  return {
    id: row.id,
    appointmentId: row.id,
    gatewayTxnId: row.gatewayTransactionId || '',
    amount: Number(row.amount || 0),
    currency: row.currency || 'LKR',
    status: row.paymentStatus || 'PENDING',
    paidAt: row.paidAt,
    receipt: buildReceipt(row),
  };
}

async function canViewAppointmentPayment(reqUser, appointment) {
  if (reqUser.role === 'admin') return true;

  if (reqUser.role === 'client') {
    const clientId = await getClientProfileId(reqUser.id);
    return appointment.clientId === clientId;
  }

  if (reqUser.role === 'lawyer') {
    const lawyerId = await getLawyerProfileId(reqUser.id);
    return appointment.lawyerId === lawyerId;
  }

  return false;
}

router.get('/', authRequired, async (req, res, next) => {
  try {
    let rows = [];

    if (req.user.role === 'client') {
      const clientId = await getClientProfileId(req.user.id);
      rows = await all(
        `SELECT *
         FROM public."Appointment"
         WHERE "clientId" = ?
         ORDER BY COALESCE("paidAt", "updatedAt") DESC`,
        [clientId]
      );
    } else if (req.user.role === 'lawyer') {
      const lawyerId = await getLawyerProfileId(req.user.id);
      rows = await all(
        `SELECT *
         FROM public."Appointment"
         WHERE "lawyerId" = ?
         ORDER BY COALESCE("paidAt", "updatedAt") DESC`,
        [lawyerId]
      );
    } else {
      rows = await all(
        `SELECT *
         FROM public."Appointment"
         ORDER BY COALESCE("paidAt", "updatedAt") DESC`
      );
    }

    res.json({
      items: rows
        .filter((row) => Number(row.amount || 0) > 0 || row.paymentStatus != null)
        .map(mapPaymentFromAppointment),
    });
  } catch (error) {
    next(error);
  }
});

router.post(
  '/checkout-session',
  authRequired,
  requireRole('client'),
  validateBody(checkoutSessionSchema),
  async (req, res, next) => {
    try {
      const { appointmentId, amount, currency = 'LKR' } = req.validatedBody;

      const appointment = await get(
        `SELECT *
         FROM public."Appointment"
         WHERE id = ?`,
        [appointmentId]
      );

      if (!appointment) {
        return res.status(404).json({ error: 'Appointment not found.' });
      }

      const clientId = await getClientProfileId(req.user.id);
      if (!clientId || appointment.clientId !== clientId) {
        return res.status(403).json({ error: 'Forbidden.' });
      }

      if (appointment.status !== 'SCHEDULED') {
        return res.status(400).json({
          error: 'Only scheduled appointments can be paid.',
        });
      }

      if (String(appointment.paymentStatus || '').toUpperCase() === 'PAID') {
        return res.status(400).json({ error: 'This appointment is already paid.' });
      }

      const safeAmount =
        Number(appointment.amount || 0) > 0
          ? Number(appointment.amount)
          : Number(amount || 0);

      if (!(safeAmount > 0)) {
        return res.status(400).json({
          error: 'A valid appointment amount is required before payment.',
        });
      }

      const merchantId = process.env.PAYHERE_MERCHANT_ID;
      const merchantSecret = process.env.PAYHERE_MERCHANT_SECRET;
      const sandbox = String(process.env.PAYHERE_SANDBOX).toLowerCase() === 'true';
      const publicBaseUrl = process.env.PUBLIC_BASE_URL;
      const hydratedUser = await hydrateUser(req.user);

      if (!merchantId || !merchantSecret || !publicBaseUrl) {
        return res.status(500).json({
          error: 'PayHere environment is not configured.',
        });
      }

      await run(
        `UPDATE public."Appointment"
         SET amount = ?, currency = ?, "paymentStatus" = ?, "updatedAt" = ?
         WHERE id = ?`,
        [safeAmount, currency, 'PENDING', nowIso(), appointment.id]
      );

      const orderId = appointment.id;
      const hash = payHereHash({
        merchantId,
        orderId,
        amount: safeAmount,
        currency,
        merchantSecret,
      });

      const checkoutUrl = sandbox
        ? 'https://sandbox.payhere.lk/pay/checkout'
        : 'https://www.payhere.lk/pay/checkout';

      const fullName = (hydratedUser?.profile?.fullName || 'LawPoint User').trim();
      const nameParts = fullName.split(/\s+/);
      const firstName = nameParts[0] || 'LawPoint';
      const lastName = nameParts.slice(1).join(' ') || 'User';

      const fields = {
        merchant_id: merchantId,
        return_url: `${publicBaseUrl}/payhere/return`,
        cancel_url: `${publicBaseUrl}/payhere/cancel`,
        notify_url: `${publicBaseUrl}/api/v1/payments/payhere/notify`,
        order_id: orderId,
        items: `Consultation payment - ${appointment.id}`,
        currency,
        amount: formatAmount(safeAmount),
        first_name: firstName,
        last_name: lastName,
        email: hydratedUser?.email || 'client@lawpoint.app',
        phone: hydratedUser?.phone || '0700000000',
        address: 'LawPoint',
        city: 'Colombo',
        country: 'Sri Lanka',
        custom_1: appointment.id,
        custom_2: req.user.id,
        hash,
      };

      await writeAudit({
        actorUserId: req.user.id,
        eventType: 'payment.checkout_started',
        targetType: 'appointment',
        targetId: appointment.id,
        ipAddress: req.ip,
      });

      const updated = await get(
        `SELECT *
         FROM public."Appointment"
         WHERE id = ?`,
        [appointment.id]
      );

      res.status(201).json({
        paymentId: updated.id,
        item: mapPaymentFromAppointment(updated),
        checkout: {
          actionUrl: checkoutUrl,
          method: 'POST',
          fields,
        },
      });
    } catch (error) {
      next(error);
    }
  }
);

router.post('/payhere/notify', async (req, res, next) => {
  try {
    const {
      merchant_id,
      order_id,
      payment_id,
      payhere_amount,
      payhere_currency,
      status_code,
      md5sig,
    } = req.body;

    const merchantSecret = process.env.PAYHERE_MERCHANT_SECRET;
    const merchantId = process.env.PAYHERE_MERCHANT_ID;

    if (!merchantSecret || !merchantId) {
      return res.status(500).send('payhere not configured');
    }

    const localSig = payHereNotifySig({
      merchantId: merchant_id,
      orderId: order_id,
      amount: payhere_amount,
      currency: payhere_currency,
      statusCode: status_code,
      merchantSecret,
    });

    if (
      merchant_id !== merchantId ||
      String(localSig).toUpperCase() !== String(md5sig || '').toUpperCase()
    ) {
      return res.status(400).send('invalid signature');
    }

    const appointment = await get(
      `SELECT *
       FROM public."Appointment"
       WHERE id = ?`,
      [order_id]
    );

    if (!appointment) {
      return res.status(404).send('appointment not found');
    }

    const newStatus = mapGatewayStatus(status_code);
    const paidAt = newStatus === 'PAID' ? nowIso() : null;
    const safeAmount =
      Number(payhere_amount || 0) > 0
        ? Number(payhere_amount)
        : Number(appointment.amount || 0);

    await run(
      `UPDATE public."Appointment"
       SET "gatewayTransactionId" = COALESCE(?, "gatewayTransactionId"),
           amount = ?,
           currency = ?,
           "paymentStatus" = ?,
           "paidAt" = ?,
           "updatedAt" = ?
       WHERE id = ?`,
      [
        payment_id || null,
        safeAmount,
        payhere_currency || appointment.currency || 'LKR',
        newStatus,
        paidAt,
        nowIso(),
        appointment.id,
      ]
    );

    const updated = await get(
      `SELECT *
       FROM public."Appointment"
       WHERE id = ?`,
      [appointment.id]
    );

    const clientUser = await get(
      `SELECT "userId" FROM public."ClientProfile" WHERE id = ?`,
      [updated.clientId]
    );

    const lawyerUser = await get(
      `SELECT "userId" FROM public."LawyerProfile" WHERE id = ?`,
      [updated.lawyerId]
    );

    if (clientUser?.userId) {
      await createNotification({
        userId: clientUser.userId,
        type: 'payment.status_changed',
        title: newStatus === 'PAID' ? 'Payment successful' : 'Payment updated',
        body: `Appointment ${updated.id} payment status: ${newStatus}`,
        data: {
          appointmentId: updated.id,
          screen: 'payments',
        },
      });
    }

    if (lawyerUser?.userId) {
      await createNotification({
        userId: lawyerUser.userId,
        type: 'payment.status_changed',
        title: newStatus === 'PAID' ? 'Client payment received' : 'Payment updated',
        body: `Appointment ${updated.id} payment status: ${newStatus}`,
        data: {
          appointmentId: updated.id,
          screen: 'payments',
        },
      });
    }

    await writeAudit({
      actorUserId: null,
      eventType: 'payment.gateway_callback',
      targetType: 'appointment',
      targetId: updated.id,
      ipAddress: req.ip,
    });

    res.send('ok');
  } catch (error) {
    next(error);
  }
});

router.get('/receipt/:paymentId', authRequired, async (req, res, next) => {
  try {
    const appointment = await get(
      `SELECT *
       FROM public."Appointment"
       WHERE id = ?`,
      [req.params.paymentId]
    );

    if (!appointment) {
      return res.status(404).json({ error: 'Receipt not found.' });
    }

    const allowed = await canViewAppointmentPayment(req.user, appointment);
    if (!allowed) {
      return res.status(403).json({ error: 'Forbidden.' });
    }

    if (String(appointment.paymentStatus || '').toUpperCase() !== 'PAID') {
      return res.status(400).json({
        error: 'Receipt is only available for successful payments.',
      });
    }

    const receipt = {
      receiptId: `R-${appointment.id}`,
      transactionId: appointment.gatewayTransactionId || appointment.id,
      paymentId: appointment.id,
      appointmentId: appointment.id,
      amount: Number(appointment.amount || 0),
      currency: appointment.currency || 'LKR',
      status: appointment.paymentStatus,
      paidAt: appointment.paidAt,
      service: 'Legal consultation',
      appointmentStart: appointment.startTime,
      appointmentEnd: appointment.endTime,
      downloadableText:
        `LawPoint Payment Receipt\n` +
        `Receipt ID: R-${appointment.id}\n` +
        `Transaction ID: ${appointment.gatewayTransactionId || appointment.id}\n` +
        `Appointment ID: ${appointment.id}\n` +
        `Service: Legal consultation\n` +
        `Amount: ${Number(appointment.amount || 0).toFixed(2)} ${appointment.currency || 'LKR'}\n` +
        `Status: ${appointment.paymentStatus}\n` +
        `Paid At: ${appointment.paidAt}\n`,
    };

    res.json(receipt);
  } catch (error) {
    next(error);
  }
});

module.exports = router;