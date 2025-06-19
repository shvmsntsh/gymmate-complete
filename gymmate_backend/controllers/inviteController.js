

const { InviteCode } = require('../models/InviteCode');
const Gym = require('../models/Gym');

exports.listInviteCodes = async (req, res) => {
  console.log("🔥 listInviteCodes route hit");
  console.log("🔐 Authenticated user:", req.user);

  try {
    let filter = {};

    if (req.user.role === 'gym_owner') {
      filter = { gymId: req.user.gymId };
    } else if (req.user.role === 'superadmin') {
      filter = {}; // show all codes
    } else {
      return res.status(403).json({ message: "Access denied" });
    }

    console.log("🔎 Filter being used:", filter);

    const codes = await InviteCode.find(filter).sort({ updatedAt: -1 });

    console.log(`✅ Found ${codes.length} invite codes`);
    res.status(200).json({ codes });
  } catch (error) {
    console.error("❌ Error fetching invite codes:", error);
    res.status(500).json({ message: "Internal server error", error: error.message });
  }
};