const { InviteCode } = require('../models/InviteCode');
const Gym = require('../models/Gym');
const User = require('../models/User');
const { hasRole } = require('../utils/roles');
const { ensureCanCreateMemberInvite } = require('../utils/gymLimits');
const { normalizeIndianPhone, indianPhoneVariants } = require('../utils/phone');

function formatDateLabel(dateValue) {
  if (!dateValue) return null;
  const date = new Date(dateValue);
  if (Number.isNaN(date.getTime())) return null;
  const day = String(date.getDate()).padStart(2, '0');
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const year = date.getFullYear();
  return `${day}/${month}/${year}`;
}

function buildUsedByLookupVariants(usedBy) {
  if (!usedBy) return [];
  const values = [usedBy];
  try {
    values.push(usedBy.toString());
  } catch (_) {}
  return [...new Set(values.filter(Boolean))];
}

function normalizeInviteCode(value) {
  return String(value || '').trim().toUpperCase();
}

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function normalizePhone(value) {
  return normalizeIndianPhone(value) || String(value || '').trim();
}

function idsEqual(first, second) {
  if (!first || !second) {
    return false;
  }
  return String(first) === String(second);
}

function isValidEmail(value) {
  return /^\S+@\S+\.\S+$/.test(String(value || '').trim());
}

function phoneLookup(value) {
  const variants = indianPhoneVariants(value);
  return variants.length
    ? { phone_number: { $in: variants } }
    : { phone_number: String(value || '').trim() };
}

function inviteePayload(invite) {
  return {
    name: invite.inviteeName || '',
    email: invite.inviteeEmail || '',
    phone_number: invite.inviteePhone || '',
  };
}

exports.validateInviteCode = async (req, res) => {
  const code = normalizeInviteCode(req.body.code);
  if (!code) {
    return res.status(400).json({ error: 'Invite code is required.' });
  }

  try {
    const invite = await InviteCode.findOne({ code });
    if (!invite || invite.used) {
      return res.status(400).json({ error: 'Invalid invite code.' });
    }

    if (invite.role === 'gym_owner') {
      return res.status(200).json({
        message: 'Valid invite code.',
        role: invite.role,
        invitee: inviteePayload(invite),
        gym: null,
        gymId: null,
      });
    }

    if (!invite.gymId) {
      return res.status(400).json({ error: 'Invite code does not reference a valid gym.' });
    }

    const gym = await Gym.findById(invite.gymId);
    if (!gym) {
      return res.status(400).json({ error: 'Gym not found for this invite code.' });
    }
    if (gym.status !== 'active') {
      return res.status(400).json({ error: 'Gym is not active for this invite code.' });
    }

    return res.status(200).json({
      message: 'Valid invite code.',
      role: invite.role,
      invitee: inviteePayload(invite),
      gym: { gymName: gym.gymName, _id: gym._id },
      gymId: gym._id,
    });
  } catch (err) {
    console.error('❌ Error validating invite code:', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

exports.listInviteCodes = async (req, res) => {
  try {
    let filter = {};

    if (hasRole(req.user, ['owner'])) {
      if (!req.user.gymId) {
        return res.status(200).json({ codes: [] });
      }
      const currentGym = await Gym.findById(req.user.gymId).select('gymName');
      filter = {
        role: { $in: ['gym_member', 'gym_trainer'] },
        $or: [
          { gymId: req.user.gymId },
          ...(currentGym?.gymName ? [{ gymName: currentGym.gymName }] : []),
        ],
      };
    } else if (hasRole(req.user, ['admin'])) {
      filter = {};
    } else {
      return res.status(403).json({ message: 'Access denied' });
    }

    const codes = await InviteCode.find(filter).sort({ updatedAt: -1 }).lean();
    const usedValues = [...new Set(codes.flatMap((code) => buildUsedByLookupVariants(code.usedBy)))];

    let usersByKey = new Map();
    if (usedValues.length > 0) {
      const usedUsers = await User.find({
        $or: [
          { email: { $in: usedValues } },
          { _id: { $in: usedValues.filter((value) => /^[a-fA-F0-9]{24}$/.test(String(value))) } },
        ],
      })
        .select('name email phone_number role joinDate hasCompletedOnboarding')
        .lean();

      usersByKey = new Map();
      for (const user of usedUsers) {
        if (user.email) usersByKey.set(String(user.email), user);
        if (user._id) usersByKey.set(String(user._id), user);
      }
    }

    const enrichedCodes = codes.map((code) => {
      const matchedUser =
        buildUsedByLookupVariants(code.usedBy)
          .map((key) => usersByKey.get(String(key)))
          .find(Boolean) || null;

      return {
        ...code,
        statusLabel: code.used ? 'Used' : 'Open',
        createdDateLabel: formatDateLabel(code.createdAt),
        usedDateLabel: code.used ? formatDateLabel(code.usedAt || code.updatedAt) : null,
        name: code.inviteeName || '',
        email: code.inviteeEmail || '',
        phone_number: code.inviteePhone || '',
        invitee: inviteePayload(code),
        usedByUser: matchedUser
          ? {
              id: matchedUser._id,
              name: matchedUser.name || null,
              email: matchedUser.email || null,
              phone_number: matchedUser.phone_number || null,
              role: matchedUser.role || null,
              joinedAt: matchedUser.joinDate || null,
              hasCompletedOnboarding: Boolean(matchedUser.hasCompletedOnboarding),
            }
          : null,
      };
    });

    res.status(200).json({ codes: enrichedCodes || [] });
  } catch (error) {
    console.error('listInviteCodes error:', {
      message: error.message,
      stack: error.stack,
      userRole: req.user?.normalizedRole,
      gymId: req.user?.gymId?.toString?.() || req.user?.gymId,
      name: error.name,
      code: error.code,
    });
    res.status(500).json({ message: 'Internal server error' });
  }
};

// Generate invite code (for gym_owner or superadmin)
exports.generateInviteCode = async (req, res) => {
  try {
    const { role } = req.body;
    const phone_number = normalizePhone(
      req.body.phone_number || req.body.phoneNumber || req.body.phone,
    );
    const name = String(req.body.name || '').trim();
    const email = normalizeEmail(req.body.email);
    const currentUser = req.user;

    if (!role) {
      return res.status(400).json({ message: 'role is required' });
    }

    // Superadmin can only create gym_owner codes
    if (hasRole(currentUser, ['admin']) && role !== 'gym_owner') {
      return res.status(403).json({ message: 'Superadmin can only generate codes for gym_owner' });
    }

    // Gym owner can invite members/trainers only. Staff accounts are added directly by owners.
    const normalizedRole = typeof role === 'string' ? role.trim().toLowerCase() : '';
    if (hasRole(currentUser, ['owner']) && !['gym_member', 'gym_trainer'].includes(normalizedRole)) {
      return res.status(403).json({ message: 'Gym owner can only invite members or trainers. Add staff from the Staff screen.' });
    }
    
    // For a gym_owner creating an invite, we need their gymId
    let gymId = null;
    let gymName = null;
    if (hasRole(currentUser, ['owner'])) {
      if (!currentUser.gymId) {
        return res.status(400).json({ message: 'Gym owner must be associated with a gym.' });
      }
      const gym = await Gym.findById(currentUser.gymId);
      if (!gym) {
        return res.status(404).json({ message: 'Gym not found for the current user.' });
      }
      if (gym.status !== 'active') {
        return res.status(403).json({ message: 'Gym account is inactive.' });
      }
      gymId = gym._id;
      gymName = gym.gymName;
    }

    if (['gym_member', 'gym_trainer'].includes(normalizedRole)) {
      if (normalizedRole === 'gym_member') {
        await ensureCanCreateMemberInvite(gymId);
      }
      if (!name) {
        return res.status(400).json({ message: `Name is required for ${normalizedRole === 'gym_member' ? 'members' : 'trainers'}.` });
      }
      if (!isValidEmail(email)) {
        return res.status(400).json({ message: `A valid email is required for ${normalizedRole === 'gym_member' ? 'members' : 'trainers'}.` });
      }
      if (!normalizeIndianPhone(phone_number)) {
        return res.status(400).json({ message: `A valid Indian phone number is required for ${normalizedRole === 'gym_member' ? 'members' : 'trainers'}.` });
      }
    }

    if (phone_number) {
      if (!name || !email) {
        return res.status(400).json({ message: 'Name and email are required when providing a phone number.' });
      }
      const existingRegistered = await User.findOne({
        ...phoneLookup(phone_number),
        role: normalizedRole,
        gymId,
        registered: true,
      });
      if (existingRegistered) {
        return res.status(409).json({ message: 'User with this phone number already exists.' });
      }
      const existingEmailUser = await User.findOne({ email });
      if (
        existingEmailUser &&
        (existingEmailUser.registered ||
          existingEmailUser.role !== normalizedRole ||
          !idsEqual(existingEmailUser.gymId, gymId) ||
          !indianPhoneVariants(phone_number).includes(existingEmailUser.phone_number))
      ) {
        return res.status(409).json({ message: 'User with this email already exists.' });
      }
    }

    const code = Math.random().toString(36).substring(2, 10).toUpperCase();
    
    const invite = new InviteCode({
      code,
      role: normalizedRole,
      gymId: gymId,
      gymName: gymName,
      inviteeName: name,
      inviteeEmail: email,
      inviteePhone: phone_number,
      createdBy: currentUser.id
    });
    
    await invite.save();

    if (phone_number) {
      let placeholder = await User.findOne({
        role: normalizedRole,
        gymId,
        $or: [phoneLookup(phone_number), { email }],
      });
      if (!placeholder) {
        placeholder = new User({
          name,
          email,
          phone_number,
          role: normalizedRole,
          gymId,
          invited: true,
          registered: false,
        });
      } else {
        placeholder.name = name;
        placeholder.email = email;
        placeholder.invited = true;
        placeholder.registered = false;
      }
      placeholder.inviteCodeId = invite._id;
      placeholder.inviteCode = invite.code;
      await placeholder.save({ validateBeforeSave: false });
    }

    res.status(201).json(invite); // Return the full invite object
  } catch (err) {
    console.error('Error generating invite code:', err);
    res.status(err.statusCode || 500).json({
      message: err.statusCode ? err.message : 'Internal server error',
      error: err.statusCode ? err.message : 'Internal server error',
      usage: err.usage
        ? {
            activeMembers: err.usage.activeMembers,
            openMemberInvites: err.usage.openMemberInvites,
            usedSeats: err.usage.usedSeats,
            memberCap: err.usage.memberCap,
            remainingSeats: err.usage.remainingSeats,
          }
        : undefined,
    });
  }
};

// Combined endpoint: Superadmin creates a gym and generates a gym_owner invite code
exports.createGymAndOwnerInvite = async (req, res) => {
  try {
    const { gymName, ownerEmail } = req.body;
    const superadmin = req.user;
    console.log('🔔 Superadmin creating gym and owner invite:', { gymName, ownerEmail });

    if (!gymName || !ownerEmail) {
      console.error('❌ gymName and ownerEmail are required');
      return res.status(400).json({ error: 'gymName and ownerEmail are required.' });
    }

    // Create the gym
    const newGym = new Gym({ gymName, email: ownerEmail });
    await newGym.save();
    console.log('✅ New gym created:', newGym);

    // Generate gym_owner invite code
    const code = Math.random().toString(36).substring(2, 10).toUpperCase();
    const invite = new InviteCode({
      code,
      role: 'gym_owner',
      gymId: newGym._id,
      gymName: newGym.gymName,
    });
    await invite.save();
    console.log('✅ Gym owner invite code generated:', invite);

    res.status(201).json({
      message: 'Gym and gym_owner invite code created.',
      gym: { gymName: newGym.gymName, _id: newGym._id },
      inviteCode: code
    });
  } catch (err) {
    console.error('❌ Error creating gym and owner invite:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
};
