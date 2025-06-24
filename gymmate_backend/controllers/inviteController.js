const { InviteCode } = require('../models/InviteCode');
const Gym = require('../models/Gym');
const User = require('../models/User');

exports.listInviteCodes = async (req, res) => {
  console.log("🔥 listInviteCodes route hit");
  console.log("🔐 Authenticated user:", req.user);

  try {
    let filter = {};

    if (req.user.role === 'gym_owner') {
      filter = { gymId: req.user.gymId, role: 'gym_member' };
    } else if (req.user.role === 'superadmin') {
      filter = {}; // show all codes
    } else {
      return res.status(403).json({ message: "Access denied" });
    }

    console.log("🔎 Filter being used:", filter);

    const codes = await InviteCode.find(filter).sort({ updatedAt: -1 });

    console.log(`✅ Found ${codes.length} invite codes`);
    res.status(200).json({ codes: codes || [] });
  } catch (error) {
    console.error("❌ Error fetching invite codes:", error);
    res.status(500).json({ message: "Internal server error", error: error.message });
  }
};

// Generate invite code (for gym_owner or superadmin)
exports.generateInviteCode = async (req, res) => {
  console.log('🔔 Invite code generation attempt by:', req.user.email);
  try {
    const { roleToGenerate } = req.body;
    const currentUser = req.user;

    console.log('Requesting user role:', currentUser.role);
    console.log('Role to generate:', roleToGenerate);

    if (!roleToGenerate) {
      return res.status(400).json({ message: 'roleToGenerate is required' });
    }

    // Superadmin can only create gym_owner codes
    if (currentUser.role === 'superadmin' && roleToGenerate !== 'gym_owner') {
      return res.status(403).json({ message: 'Superadmin can only generate codes for gym_owner' });
    }

    // Gym owner can only create gym_member codes
    if (currentUser.role === 'gym_owner' && roleToGenerate !== 'gym_member') {
      return res.status(403).json({ message: 'Gym owner can only generate codes for gym_member' });
    }
    
    // For a gym_owner creating an invite, we need their gymId
    let gymId = null;
    let gymName = null;
    if(currentUser.role === 'gym_owner') {
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

    const code = Math.random().toString(36).substring(2, 10).toUpperCase();
    
    const invite = new InviteCode({
      code,
      role: roleToGenerate,
      gymId: gymId,
      gymName: gymName,
      createdBy: currentUser.id
    });
    
    await invite.save();
    
    console.log('✅ Invite code generated:', invite);
    res.status(201).json(invite); // Return the full invite object
  } catch (err) {
    console.error('❌ Error generating invite code:', err);
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