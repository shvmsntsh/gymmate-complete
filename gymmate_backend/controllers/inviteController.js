const { InviteCode } = require('../models/InviteCode');
const Gym = require('../models/Gym');
const User = require('../models/User');
const { hasRole } = require('../utils/roles');

exports.listInviteCodes = async (req, res) => {
  try {
    let filter = {};

    if (hasRole(req.user, ['owner'])) {
      const currentGym = req.user.gymId
        ? await Gym.findById(req.user.gymId).select('gymName')
        : null;
      filter = {
        role: { $in: ['gym_member', 'gym_trainer'] },
        $or: [
          { gymId: req.user.gymId || null },
          ...(currentGym?.gymName ? [{ gymName: currentGym.gymName }] : []),
        ],
      };
    } else if (hasRole(req.user, ['admin'])) {
      filter = {};
    } else {
      return res.status(403).json({ message: 'Access denied' });
    }

    const codes = await InviteCode.find(filter).sort({ updatedAt: -1 });
    res.status(200).json({ codes: codes || [] });
  } catch (error) {
    console.error('Error fetching invite codes:', error);
    res.status(500).json({ message: 'Internal server error', error: error.message });
  }
};

// Generate invite code (for gym_owner or superadmin)
exports.generateInviteCode = async (req, res) => {
  try {
    const { role, phone_number, name, email } = req.body;
    const currentUser = req.user;

    if (!role) {
      return res.status(400).json({ message: 'role is required' });
    }

    // Superadmin can only create gym_owner codes
    if (hasRole(currentUser, ['admin']) && role !== 'gym_owner') {
      return res.status(403).json({ message: 'Superadmin can only generate codes for gym_owner' });
    }

    // Gym owner can only create gym_member or gym_trainer codes
    const normalizedRole = typeof role === 'string' ? role.trim().toLowerCase() : '';
    if (hasRole(currentUser, ['owner']) && !['gym_member', 'gym_trainer'].includes(normalizedRole)) {
      return res.status(403).json({ message: 'Gym owner can only generate codes for gym_member or gym_trainer' });
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
      gymId = gym._id;
      gymName = gym.gymName;
    }

    if (phone_number) {
      // Create a user placeholder
      const userExists = await User.findOne({ phone_number });
      if (userExists) {
        return res.status(409).json({ message: 'User with this phone number already exists.' });
      }

      if (!name || !email) {
        return res.status(400).json({ message: 'Name and email are required when providing a phone number.' });
      }

      const newUser = new User({
        name,
        email,
        phone_number,
        role: normalizedRole,
        gymId,
        invited: true,
        registered: false,
      });
      await newUser.save({ validateBeforeSave: false }); // Bypass password requirement
    }

    const code = Math.random().toString(36).substring(2, 10).toUpperCase();
    
    const invite = new InviteCode({
      code,
      role: normalizedRole,
      gymId: gymId,
      gymName: gymName,
      createdBy: currentUser.id
    });
    
    await invite.save();
    res.status(201).json(invite); // Return the full invite object
  } catch (err) {
    console.error('Error generating invite code:', err);
    res.status(500).json({ error: 'Internal server error' });
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
