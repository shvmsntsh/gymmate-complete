const Conversation = require('../models/Conversation');
const TrainerAssignment = require('../models/TrainerAssignment');
const User = require('../models/User');
const {
  loadMealPlanForMember,
  loadWorkoutPlanForMember,
} = require('./planController');
const {
  buildClientSummary,
  buildSevenDaySeries,
  dateKeyFromDate,
  ensureOwnerTrainerConversation,
  getOwnerForGym,
  getRecentLogsForMembers,
  getUnreadCountsByConversation,
  shortDayLabel,
} = require('../services/coachingService');
const { hasRole } = require('../utils/roles');

async function loadTrainerContext(trainerId, gymId) {
  const [assignments, owner] = await Promise.all([
    TrainerAssignment.find({
      trainerId,
      gymId,
      status: 'active',
    }).lean(),
    getOwnerForGym(gymId),
  ]);

  const memberIds = assignments.map((assignment) => assignment.memberId);
  const [members, logsByMember, conversations] = await Promise.all([
    User.find({
      _id: { $in: memberIds },
      role: 'gym_member',
    })
      .select(
        'name email createdAt updatedAt fitnessGoals dietPreferences profile firstChallenge customMealPlan customWorkoutPlan',
      )
      .lean(),
    getRecentLogsForMembers(memberIds, 7),
    Conversation.find({
      gymId,
      type: 'trainer_member',
      trainerId,
      memberId: { $in: memberIds },
    }).lean(),
  ]);

  return {
    assignments,
    owner,
    members,
    logsByMember,
    conversations,
  };
}

function buildAttentionStatus(summary) {
  if (summary.todayCompletion >= 0.9) return 'completed';
  if (summary.lastActivity.hasActivity && summary.todayCompletion >= 0.45) {
    return 'active';
  }
  if (summary.lastActivity.hasActivity) return 'needs_attention';
  return 'inactive';
}

function statusPriority(status) {
  switch (status) {
    case 'needs_attention':
      return 0;
    case 'inactive':
      return 1;
    case 'active':
      return 2;
    case 'completed':
      return 3;
    default:
      return 4;
  }
}

function sortClientSummaries(rows) {
  return [...rows].sort((a, b) => {
    const statusDiff = statusPriority(a.status) - statusPriority(b.status);
    if (statusDiff !== 0) return statusDiff;

    const completionDiff =
      Number(a.todayCompletion || 0) - Number(b.todayCompletion || 0);
    if (completionDiff !== 0) return completionDiff;

    const lastActivityA = a.lastActivity?.date
      ? new Date(a.lastActivity.date).getTime()
      : 0;
    const lastActivityB = b.lastActivity?.date
      ? new Date(b.lastActivity.date).getTime()
      : 0;
    if (lastActivityA !== lastActivityB) {
      return lastActivityA - lastActivityB;
    }

    return String(a.name || '').localeCompare(String(b.name || ''));
  });
}

exports.getTrainerAttendanceProgress = async (req, res) => {
  if (!hasRole(req.user, ['trainer'])) {
    return res.status(403).json({ message: 'Forbidden: trainers only' });
  }

  try {
    const payload = await exports.getTrainerDashboardPayload(req.user);
    return res.status(200).json({
      attendanceProgress: payload.chartSeries.map((point) => ({
        day: point.label,
        count: point.value,
      })),
    });
  } catch (error) {
    console.error('Error fetching trainer attendance/progress:', error);
    return res.status(500).json({ message: 'Error fetching trainer attendance/progress' });
  }
};

exports.getTrainerDashboardPayload = async (trainer) => {
  const context = await loadTrainerContext(trainer._id, trainer.gymId);
  const ownerConversation = context.owner
    ? await ensureOwnerTrainerConversation({
        gymId: trainer.gymId,
        trainerId: trainer._id,
        ownerId: context.owner._id,
      })
    : null;
  const unreadByConversation = await getUnreadCountsByConversation(
    [
      ...context.conversations.map((conversation) => conversation._id),
      ...(ownerConversation ? [ownerConversation._id] : []),
    ],
    trainer._id,
  );

  const clientSummaries = await Promise.all(
    context.members.map(async (member) => {
      const assignment = context.assignments.find(
        (entry) => String(entry.memberId) === String(member._id),
      );
      const conversation =
        context.conversations.find(
          (entry) =>
            String(entry.memberId) === String(member._id) &&
            entry.status === 'active',
        ) || null;
      return buildClientSummary(
        member,
        assignment,
        context.logsByMember[String(member._id)] || [],
        conversation,
        conversation ? unreadByConversation[String(conversation._id)] || 0 : 0,
      );
    }),
  );
  const clientsWithStatus = sortClientSummaries(
    clientSummaries.map((summary) => ({
      ...summary,
      status: buildAttentionStatus(summary),
    })),
  );

  const todayKey = dateKeyFromDate();
  const chartSeries = Array.from({ length: 7 }, (_, index) => {
    const date = new Date();
    date.setDate(date.getDate() - (6 - index));
    const dateKey = dateKeyFromDate(date);
    const value = clientsWithStatus.filter((summary) =>
      (context.logsByMember[String(summary.memberId)] || []).some((entry) => {
        if (entry.date !== dateKey) return false;
        return (
          Number(entry.completionScore || 0) > 0 ||
          Number(entry.caloriesLogged || 0) > 0 ||
          Number(entry.water || 0) > 0 ||
          Number(entry.steps || 0) > 0
        );
      }),
    ).length;
    return {
      label: shortDayLabel(dateKey),
      value,
      date: dateKey,
    };
  });

  const needsAttention = clientsWithStatus.filter(
    (summary) => summary.status === 'needs_attention' || summary.status === 'inactive',
  );
  const completedToday = clientsWithStatus.filter(
    (summary) => summary.lastActivity.date === todayKey && summary.todayCompletion >= 0.9,
  ).length;

  return {
    assignedClientsCount: clientsWithStatus.length,
    completedTodayCount: completedToday,
    needsAttentionCount: needsAttention.length,
    unreadMessagesCount:
      clientsWithStatus.reduce(
      (sum, summary) => sum + Number(summary.unreadMessages || 0),
      0,
    ) + (ownerConversation ? unreadByConversation[String(ownerConversation._id)] || 0 : 0),
    chartSeries,
    focusClients: clientsWithStatus.slice(0, 2),
    ownerConversationId: ownerConversation?._id || null,
    ownerName: context.owner?.name || 'Gym Owner',
  };
};

exports.getTrainerDashboard = async (req, res) => {
  if (!hasRole(req.user, ['trainer'])) {
    return res.status(403).json({ message: 'Forbidden: trainers only' });
  }

  try {
    const payload = await exports.getTrainerDashboardPayload(req.user);
    return res.status(200).json(payload);
  } catch (error) {
    console.error('Error fetching trainer dashboard:', error);
    return res.status(500).json({ message: 'Error fetching trainer dashboard' });
  }
};

exports.getTrainerClients = async (req, res) => {
  if (!hasRole(req.user, ['trainer'])) {
    return res.status(403).json({ message: 'Forbidden: trainers only' });
  }

  try {
    const context = await loadTrainerContext(req.user._id, req.user.gymId);
    const unreadByConversation = await getUnreadCountsByConversation(
      context.conversations.map((conversation) => conversation._id),
      req.user._id,
    );

    const clients = await Promise.all(
      context.members.map(async (member) => {
        const assignment = context.assignments.find(
          (entry) => String(entry.memberId) === String(member._id),
        );
        const conversation =
          context.conversations.find(
            (entry) =>
              String(entry.memberId) === String(member._id) &&
              entry.status === 'active',
          ) || null;
        const summary = await buildClientSummary(
          member,
          assignment,
          context.logsByMember[String(member._id)] || [],
          conversation,
          conversation ? unreadByConversation[String(conversation._id)] || 0 : 0,
        );
        return {
          ...summary,
          status: buildAttentionStatus(summary),
        };
      }),
    );

    return res.status(200).json({ clients: sortClientSummaries(clients) });
  } catch (error) {
    console.error('Error fetching trainer clients:', error);
    return res.status(500).json({ message: 'Error fetching clients' });
  }
};

exports.getTrainerClientSummary = async (req, res) => {
  if (!hasRole(req.user, ['trainer'])) {
    return res.status(403).json({ message: 'Forbidden: trainers only' });
  }

  try {
    const { memberId } = req.params;
    const assignment = await TrainerAssignment.findOne({
      trainerId: req.user._id,
      gymId: req.user.gymId,
      memberId,
      status: 'active',
    }).lean();

    if (!assignment) {
      return res.status(404).json({ message: 'Client not assigned to this trainer' });
    }

    const [member, conversations, logsByMember] = await Promise.all([
      User.findOne({
        _id: memberId,
        gymId: req.user.gymId,
        role: 'gym_member',
      })
        .select(
          'name email createdAt updatedAt fitnessGoals dietPreferences profile firstChallenge customMealPlan customWorkoutPlan',
        )
        .lean(),
      Conversation.find({
        gymId: req.user.gymId,
        type: 'trainer_member',
        trainerId: req.user._id,
        memberId,
      }).lean(),
      getRecentLogsForMembers([memberId], 7),
    ]);

    if (!member) {
      return res.status(404).json({ message: 'Client not found' });
    }

    const conversation =
      conversations.find((entry) => entry.status === 'active') || null;
    const unreadByConversation = await getUnreadCountsByConversation(
      conversation ? [conversation._id] : [],
      req.user._id,
    );
    const logs = logsByMember[String(memberId)] || [];
    const summary = await buildClientSummary(
      member,
      assignment,
      logs,
      conversation,
      conversation ? unreadByConversation[String(conversation._id)] || 0 : 0,
    );
    const [mealPlan, workoutPlan] = await Promise.all([
      loadMealPlanForMember(member),
      loadWorkoutPlanForMember(member),
    ]);
    const status = buildAttentionStatus(summary);

    return res.status(200).json({
      client: {
        ...summary,
        status,
      },
      challenge: summary.challenge,
      activitySeries: buildSevenDaySeries(logs, shortDayLabel).map((entry) => ({
        ...entry,
        value: Math.round(Number(entry.count || 0) * 100),
      })),
      mealPlan,
      workoutPlan,
    });
  } catch (error) {
    console.error('Error fetching trainer client summary:', error);
    return res.status(500).json({ message: 'Error fetching client summary' });
  }
};

exports.getTrainerClientActivity = async (req, res) => {
  if (!hasRole(req.user, ['trainer'])) {
    return res.status(403).json({ message: 'Forbidden: trainers only' });
  }

  try {
    const { memberId } = req.params;
    const assignment = await TrainerAssignment.findOne({
      trainerId: req.user._id,
      gymId: req.user.gymId,
      memberId,
      status: 'active',
    }).lean();

    if (!assignment) {
      return res.status(404).json({ message: 'Client not assigned to this trainer' });
    }

    const days = req.query.range === '7d' ? 7 : 7;
    const logsByMember = await getRecentLogsForMembers([memberId], days);
    const logs = logsByMember[String(memberId)] || [];

    return res.status(200).json({
      activity: logs.map((entry) => ({
        date: entry.date,
        completionScore: Number(entry.completionScore || 0),
        caloriesLogged: Number(entry.caloriesLogged || 0),
        water: Number(entry.water || 0),
        steps: Number(entry.steps || 0),
      })),
      series: buildSevenDaySeries(logs, shortDayLabel).map((entry) => ({
        ...entry,
        value: Math.round(Number(entry.count || 0) * 100),
      })),
    });
  } catch (error) {
    console.error('Error fetching trainer client activity:', error);
    return res.status(500).json({ message: 'Error fetching client activity' });
  }
};
