const Conversation = require('../models/Conversation');
const DailyPlanLog = require('../models/DailyPlanLog');
const Message = require('../models/Message');
const TrainerAssignment = require('../models/TrainerAssignment');
const User = require('../models/User');

function dateKeyFromDate(value = new Date()) {
  const date = value instanceof Date ? value : new Date(value);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function startOfDayOffset(daysAgo = 0) {
  const date = new Date();
  date.setHours(0, 0, 0, 0);
  date.setDate(date.getDate() - daysAgo);
  return date;
}

async function getOwnerForGym(gymId) {
  return User.findOne({ gymId, role: 'gym_owner' }).select('name email gymId');
}

async function ensureOwnerTrainerConversation({ gymId, trainerId, ownerId }) {
  let resolvedOwnerId = ownerId;
  if (!resolvedOwnerId) {
    const owner = await getOwnerForGym(gymId);
    resolvedOwnerId = owner?._id;
  }
  if (!resolvedOwnerId) {
    return null;
  }

  let conversation = await Conversation.findOne({
    gymId,
    type: 'owner_trainer',
    trainerId,
    ownerId: resolvedOwnerId,
    status: 'active',
  });

  if (!conversation) {
    conversation = await Conversation.create({
      gymId,
      type: 'owner_trainer',
      trainerId,
      ownerId: resolvedOwnerId,
      status: 'active',
    });
  }

  return conversation;
}

async function ensureTrainerMemberConversation({ gymId, trainerId, memberId }) {
  let conversation = await Conversation.findOne({
    gymId,
    type: 'trainer_member',
    trainerId,
    memberId,
    status: 'active',
  });

  if (!conversation) {
    conversation = await Conversation.create({
      gymId,
      type: 'trainer_member',
      trainerId,
      memberId,
      status: 'active',
    });
  }

  return conversation;
}

async function archiveTrainerMemberConversations({ gymId, memberId, exceptTrainerId = null }) {
  const query = {
    gymId,
    type: 'trainer_member',
    memberId,
    status: 'active',
  };

  if (exceptTrainerId) {
    query.trainerId = { $ne: exceptTrainerId };
  }

  await Conversation.updateMany(query, {
    $set: {
      status: 'archived',
      archivedAt: new Date(),
    },
  });
}

function summarizeLog(log) {
  if (!log) {
    return {
      date: null,
      completionScore: 0,
      caloriesLogged: 0,
      water: 0,
      steps: 0,
      hasActivity: false,
    };
  }

  return {
    date: log.date,
    completionScore: Number(log.completionScore || 0),
    caloriesLogged: Number(log.caloriesLogged || 0),
    water: Number(log.water || 0),
    steps: Number(log.steps || 0),
    hasActivity:
      Number(log.completionScore || 0) > 0 ||
      Number(log.caloriesLogged || 0) > 0 ||
      Number(log.water || 0) > 0 ||
      Number(log.steps || 0) > 0,
  };
}

function hasMeaningfulActivity(log) {
  if (!log) return false;
  return (
    Number(log.completionScore || 0) > 0 ||
    Number(log.caloriesLogged || 0) > 0 ||
    Number(log.water || 0) > 0 ||
    Number(log.steps || 0) > 0 ||
    Object.keys(log.loggedMealItems || {}).length > 0 ||
    Object.keys(log.loggedWorkoutItems || {}).length > 0
  );
}

function challengeLabel(type) {
  switch (type) {
    case 'first_workout':
      return 'First Workout';
    case 'meal_rhythm':
      return 'Meal Rhythm';
    case '7_day_checkin':
    default:
      return '7-Day Check-in';
  }
}

function deriveChallengeSummary(firstChallenge = {}, logs = [], dailyMeals = 3) {
  const type = firstChallenge?.type || '7_day_checkin';
  const activeLogs = logs.filter((entry) => hasMeaningfulActivity(entry));
  const distinctActiveDays = new Set(activeLogs.map((entry) => entry.date)).size;
  const workoutDays = logs.filter(
    (entry) => Object.keys(entry.loggedWorkoutItems || {}).length > 0,
  ).length;
  const fullMealDays = logs.filter((entry) => {
    const loggedMeals = Object.keys(entry.loggedMealItems || {}).length;
    return loggedMeals >= Math.max(1, Number(dailyMeals || 3));
  }).length;

  let current = 0;
  let target = 7;
  let summary = 'Log activity on 7 different days.';
  let nextStep = 'Log something today to move the challenge forward.';

  switch (type) {
    case 'first_workout':
      current = workoutDays > 0 ? 1 : 0;
      target = 1;
      summary = current >= 1 ? 'First workout logged.' : 'Complete your first logged workout.';
      nextStep =
        current >= 1
          ? 'Keep the streak moving with the next session.'
          : 'Finish one workout to complete this challenge.';
      break;
    case 'meal_rhythm':
      current = Math.min(fullMealDays, 3);
      target = 3;
      summary = `${current}/3 full meal days logged.`;
      nextStep =
        current >= target
          ? 'Keep the food rhythm steady.'
          : 'Finish all planned meals on 3 different days.';
      break;
    case '7_day_checkin':
    default:
      current = Math.min(distinctActiveDays, 7);
      target = 7;
      summary = `${current}/7 active days logged.`;
      nextStep =
        current >= target
          ? 'Keep checking in to protect the streak.'
          : 'Log activity on 7 different days.';
      break;
  }

  const progress = Math.max(
    0,
    Math.min(
      100,
      Math.round(
        Math.max(
          Number(firstChallenge?.progress || 0),
          target > 0 ? (current / target) * 100 : 0,
        ),
      ),
    ),
  );
  const isCompleted = Boolean(firstChallenge?.isCompleted) || current >= target;

  return {
    type,
    label: challengeLabel(type),
    current,
    target,
    progress,
    summary,
    nextStep,
    status: isCompleted
      ? 'completed'
      : firstChallenge?.isAccepted
      ? 'in_progress'
      : 'ready',
    statusLabel: isCompleted
      ? 'Completed'
      : firstChallenge?.isAccepted
      ? 'In Progress'
      : 'Ready',
    isAccepted: Boolean(firstChallenge?.isAccepted),
    isCompleted,
    startDate: firstChallenge?.startDate || null,
    completedAt: firstChallenge?.completedAt || null,
  };
}

async function getUnreadCountsByConversation(conversationIds, userId) {
  if (!conversationIds.length) {
    return {};
  }

  const rows = await Message.aggregate([
    {
      $match: {
        conversationId: { $in: conversationIds },
        senderId: { $ne: userId },
        readBy: { $ne: userId },
      },
    },
    {
      $group: {
        _id: '$conversationId',
        count: { $sum: 1 },
      },
    },
  ]);

  return rows.reduce((acc, row) => {
    acc[row._id.toString()] = row.count;
    return acc;
  }, {});
}

async function getRecentLogsForMembers(memberIds, days = 7) {
  if (!memberIds.length) {
    return {};
  }

  const startKey = dateKeyFromDate(startOfDayOffset(days - 1));
  const logs = await DailyPlanLog.find({
    memberId: { $in: memberIds },
    date: { $gte: startKey },
  })
    .sort({ date: 1 })
    .lean();

  return logs.reduce((acc, log) => {
    const key = String(log.memberId);
    if (!acc[key]) {
      acc[key] = [];
    }
    acc[key].push(log);
    return acc;
  }, {});
}

function buildSevenDaySeries(logs, labelBuilder) {
  const dayKeys = Array.from({ length: 7 }, (_, index) =>
    dateKeyFromDate(startOfDayOffset(6 - index)),
  );

  const logMap = new Map(logs.map((entry) => [entry.date, entry]));
  return dayKeys.map((dayKey) => {
    const entry = logMap.get(dayKey);
    return {
      day: labelBuilder(dayKey),
      date: dayKey,
      count: entry ? Number(entry.completionScore || 0) : 0,
      caloriesLogged: entry ? Number(entry.caloriesLogged || 0) : 0,
    };
  });
}

function shortDayLabel(dateKey) {
  const date = new Date(`${dateKey}T00:00:00.000Z`);
  return date.toLocaleDateString('en-US', {
    weekday: 'short',
    timeZone: 'UTC',
  });
}

async function buildClientSummary(member, assignment, logs = [], conversation = null, unreadCount = 0) {
  const latestLog = logs.length ? logs[logs.length - 1] : null;
  const todayKey = dateKeyFromDate();
  const todayLog = logs.find((entry) => entry.date === todayKey) || null;
  const challenge = deriveChallengeSummary(
    member.firstChallenge || {},
    logs,
    member?.dietPreferences?.dailyMeals || 3,
  );

  return {
    memberId: member._id,
    name: member.name,
    email: member.email,
    fitnessGoals: member.fitnessGoals || [],
    dietPreferences: member.dietPreferences || {},
    profile: member.profile || {},
    assignment: {
      id: assignment?._id || null,
      notes: assignment?.notes || '',
      assignedAt: assignment?.assignedAt || null,
      status: assignment?.status || 'active',
    },
    todayCompletion: Number(todayLog?.completionScore || 0),
    lastActivity: summarizeLog(latestLog),
    unreadMessages: unreadCount,
    conversationId: conversation?._id || null,
    challenge,
    hasCustomMealPlan: Boolean(member.customMealPlan),
    hasCustomWorkoutPlan: Boolean(member.customWorkoutPlan),
    needsAttention:
      !latestLog ||
      Number(latestLog.completionScore || 0) < 0.45 ||
      latestLog.date !== todayKey,
    lastPlanUpdateAt:
      member.updatedAt || assignment?.updatedAt || assignment?.assignedAt || null,
  };
}

module.exports = {
  archiveTrainerMemberConversations,
  buildClientSummary,
  buildSevenDaySeries,
  dateKeyFromDate,
  ensureOwnerTrainerConversation,
  ensureTrainerMemberConversation,
  getOwnerForGym,
  getRecentLogsForMembers,
  getUnreadCountsByConversation,
  deriveChallengeSummary,
  shortDayLabel,
  summarizeLog,
};
