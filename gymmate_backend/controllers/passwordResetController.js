const crypto = require('crypto');
const PasswordResetCode = require('../models/PasswordResetCode');
const User = require('../models/User');
const Gym = require('../models/Gym');
const { sendEmail } = require('../services/emailService');

const GENERIC_RESPONSE = {
  message: 'If that email belongs to a GymMate account, a reset code will arrive shortly.',
};

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function hashCode(email, code) {
  const pepper = process.env.PASSWORD_RESET_PEPPER || process.env.JWT_SECRET || 'dev-reset-pepper';
  return crypto
    .createHash('sha256')
    .update(`${normalizeEmail(email)}:${String(code).trim()}:${pepper}`)
    .digest('hex');
}

function resetEmailHtml(code, minutes) {
  return `
  <div style="font-family:Inter,Arial,sans-serif;background:#f6f7fb;padding:32px;color:#111827">
    <div style="max-width:560px;margin:0 auto;background:#ffffff;border-radius:18px;padding:32px;border:1px solid #e5e7eb">
      <div style="font-size:24px;font-weight:800;letter-spacing:-0.03em">GymMate</div>
      <h1 style="font-size:24px;margin:28px 0 10px">Reset your password</h1>
      <p style="color:#4b5563;line-height:1.6">Use this code to set a new password. It expires in ${minutes} minutes.</p>
      <div style="font-size:34px;font-weight:800;letter-spacing:0.18em;background:#111827;color:#ffffff;border-radius:14px;padding:18px;text-align:center;margin:24px 0">${code}</div>
      <p style="color:#6b7280;line-height:1.6">If you did not request this, you can ignore the email. No account change happens until this code is used.</p>
      <p style="color:#111827;font-weight:700;margin-top:28px">GymMate Support</p>
    </div>
  </div>`;
}

function resetEmailText(code, minutes) {
  return `GymMate password reset\n\nUse this code to reset your password: ${code}\n\nIt expires in ${minutes} minutes. If you did not request this, ignore this email.`;
}

function requestContext(req) {
  return {
    ipAddress: req.ip || req.headers['x-forwarded-for'] || '',
    userAgent: req.headers['user-agent'] || '',
  };
}

exports.requestPasswordReset = async (req, res) => {
  try {
    const email = normalizeEmail(req.body.email);
    if (!email) {
      return res.status(200).json(GENERIC_RESPONSE);
    }

    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const recentRequestCount = await PasswordResetCode.countDocuments({
      email,
      createdAt: { $gte: oneHourAgo },
    });
    if (recentRequestCount >= 5) {
      return res.status(200).json(GENERIC_RESPONSE);
    }

    const latestRequest = await PasswordResetCode.findOne({ email }).sort({ createdAt: -1 });
    if (latestRequest && Date.now() - latestRequest.createdAt.getTime() < 60 * 1000) {
      return res.status(200).json(GENERIC_RESPONSE);
    }

    const user = await User.findOne({ email });
    if (!user || user.accountStatus === 'deactivated') {
      return res.status(200).json(GENERIC_RESPONSE);
    }

    if (user.gymId) {
      const gym = await Gym.findById(user.gymId).select('status');
      if (gym && gym.status !== 'active') {
        return res.status(200).json(GENERIC_RESPONSE);
      }
    }

    const code = String(crypto.randomInt(100000, 1000000));
    const ttlMinutes = Math.max(5, Number(process.env.PASSWORD_RESET_CODE_TTL_MINUTES || 10));
    const resetCode = await PasswordResetCode.create({
      email,
      userId: user._id,
      codeHash: hashCode(email, code),
      expiresAt: new Date(Date.now() + ttlMinutes * 60 * 1000),
      ...requestContext(req),
    });

    try {
      await sendEmail({
        to: email,
        subject: 'Your GymMate password reset code',
        html: resetEmailHtml(code, ttlMinutes),
        text: resetEmailText(code, ttlMinutes),
      });
    } catch (error) {
      console.error('Password reset email failed:', error);
      await PasswordResetCode.findByIdAndDelete(resetCode._id).catch(() => {});
    }

    return res.status(200).json(GENERIC_RESPONSE);
  } catch (error) {
    console.error('Password reset request failed:', error);
    return res.status(200).json(GENERIC_RESPONSE);
  }
};

exports.verifyPasswordResetCode = async (req, res) => {
  try {
    const email = normalizeEmail(req.body.email);
    const code = String(req.body.code || '').trim();
    const record = await PasswordResetCode.findOne({
      email,
      usedAt: null,
      expiresAt: { $gt: new Date() },
    }).sort({ createdAt: -1 });

    if (!record || record.attempts >= 5 || record.codeHash !== hashCode(email, code)) {
      if (record) {
        record.attempts += 1;
        await record.save();
      }
      return res.status(400).json({ message: 'Invalid or expired reset code.' });
    }

    return res.status(200).json({ message: 'Reset code verified.' });
  } catch (error) {
    console.error('Password reset verify failed:', error);
    return res.status(400).json({ message: 'Invalid or expired reset code.' });
  }
};

exports.completePasswordReset = async (req, res) => {
  try {
    const email = normalizeEmail(req.body.email);
    const code = String(req.body.code || '').trim();
    const newPassword = String(req.body.newPassword || '');

    if (newPassword.length < 6) {
      return res.status(400).json({ message: 'Password must be at least 6 characters.' });
    }

    const record = await PasswordResetCode.findOne({
      email,
      usedAt: null,
      expiresAt: { $gt: new Date() },
    }).sort({ createdAt: -1 });

    if (!record || record.attempts >= 5 || record.codeHash !== hashCode(email, code)) {
      if (record) {
        record.attempts += 1;
        await record.save();
      }
      return res.status(400).json({ message: 'Invalid or expired reset code.' });
    }

    const user = await User.findById(record.userId);
    if (!user || user.accountStatus === 'deactivated') {
      return res.status(400).json({ message: 'Invalid or expired reset code.' });
    }

    user.password = newPassword;
    await user.save();
    record.usedAt = new Date();
    await record.save();

    return res.status(200).json({ message: 'Password updated. Please log in with your new password.' });
  } catch (error) {
    console.error('Password reset complete failed:', error);
    return res.status(400).json({ message: 'Invalid or expired reset code.' });
  }
};
