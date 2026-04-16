const DailyPlanLog = require('../models/DailyPlanLog');
const User = require('../models/User');
const { hasRole } = require('../utils/roles');

function dateKeyFromDate(value = new Date()) {
  const date = value instanceof Date ? value : new Date(value);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function normalizeDateKey(value) {
  if (!value) return dateKeyFromDate();
  if (/^\d{4}-\d{2}-\d{2}$/.test(String(value))) {
    return String(value);
  }
  return dateKeyFromDate(value);
}

function coerceNumber(value, fallback = 0) {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
}

exports.getMemberPlanLog = async (req, res) => {
  if (!hasRole(req.user, ['member'])) {
    return res.status(403).json({ message: 'Forbidden: gym_member only' });
  }

  try {
    const date = normalizeDateKey(req.query.date);
    const log = await DailyPlanLog.findOne({
      memberId: req.user._id,
      date,
    }).lean();

    return res.status(200).json({
      log:
        log || {
          memberId: req.user._id,
          gymId: req.user.gymId,
          date,
          loggedMealItems: {},
          loggedWorkoutItems: {},
          water: 0,
          steps: 0,
          caloriesLogged: 0,
          proteinLogged: 0,
          carbsLogged: 0,
          fatLogged: 0,
          completionScore: 0,
        },
    });
  } catch (error) {
    console.error('Error fetching plan log:', error);
    return res.status(500).json({ message: 'Error fetching plan log' });
  }
};

exports.upsertMemberPlanLog = async (req, res) => {
  if (!hasRole(req.user, ['member'])) {
    return res.status(403).json({ message: 'Forbidden: gym_member only' });
  }

  try {
    const date = normalizeDateKey(req.body?.date);
    const payload = req.body || {};
    const member = await User.findById(req.user._id).select('gymId');

    if (!member?.gymId) {
      return res.status(400).json({ message: 'Member is not linked to a gym' });
    }

    const log = await DailyPlanLog.findOneAndUpdate(
      { memberId: req.user._id, date },
      {
        $set: {
          gymId: member.gymId,
          loggedMealItems: payload.loggedMealItems || {},
          loggedWorkoutItems: payload.loggedWorkoutItems || {},
          water: coerceNumber(payload.water, 0),
          steps: coerceNumber(payload.steps, 0),
          caloriesLogged: coerceNumber(payload.caloriesLogged, 0),
          proteinLogged: coerceNumber(payload.proteinLogged, 0),
          carbsLogged: coerceNumber(payload.carbsLogged, 0),
          fatLogged: coerceNumber(payload.fatLogged, 0),
          completionScore: Math.max(
            0,
            Math.min(1, coerceNumber(payload.completionScore, 0)),
          ),
          updatedAt: new Date(),
        },
      },
      {
        upsert: true,
        new: true,
        setDefaultsOnInsert: true,
      },
    ).lean();

    return res.status(200).json({
      message: 'Plan log updated successfully.',
      log,
    });
  } catch (error) {
    console.error('Error updating plan log:', error);
    return res.status(500).json({ message: 'Error updating plan log' });
  }
};
