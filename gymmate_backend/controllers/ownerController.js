const Conversation = require('../models/Conversation');
const TrainerAssignment = require('../models/TrainerAssignment');
const User = require('../models/User');
const {
  buildClientSummary,
  ensureOwnerTrainerConversation,
  ensureTrainerMemberConversation,
  archiveTrainerMemberConversations,
  getRecentLogsForMembers,
  getUnreadCountsByConversation,
  summarizeLog,
} = require('../services/coachingService');
const { hasRole } = require('../utils/roles');

function sortTrainers(rows) {
  return [...rows].sort((a, b) => {
    const countDiff = Number(b.clientCount || 0) - Number(a.clientCount || 0);
    if (countDiff !== 0) return countDiff;
    return String(a.name || '').localeCompare(String(b.name || ''));
  });
}

function sortMembers(rows) {
  return [...rows].sort((a, b) => {
    const assignmentRankA = a.assignmentStatus === 'unassigned' ? 0 : 1;
    const assignmentRankB = b.assignmentStatus === 'unassigned' ? 0 : 1;
    if (assignmentRankA !== assignmentRankB) {
      return assignmentRankA - assignmentRankB;
    }

    const attentionRankA = a.needsAttention ? 0 : 1;
    const attentionRankB = b.needsAttention ? 0 : 1;
    if (attentionRankA !== attentionRankB) {
      return attentionRankA - attentionRankB;
    }

    const lastActivityA = a.lastActivity?.date
      ? new Date(a.lastActivity.date).getTime()
      : 0;
    const lastActivityB = b.lastActivity?.date
      ? new Date(b.lastActivity.date).getTime()
      : 0;
    if (lastActivityA !== lastActivityB) {
      return lastActivityB - lastActivityA;
    }

    return String(a.name || '').localeCompare(String(b.name || ''));
  });
}

async function buildOwnerWorkspace(owner) {
  const gymId = owner.gymId;
  const [trainers, members, assignments, conversations, trainerMemberConversations] =
    await Promise.all([
    User.find({ gymId, role: 'gym_trainer' })
      .select('name email createdAt updatedAt')
      .lean(),
    User.find({ gymId, role: 'gym_member' })
      .select(
        'name email createdAt updatedAt fitnessGoals dietPreferences profile customMealPlan customWorkoutPlan',
      )
      .lean(),
    TrainerAssignment.find({ gymId, status: 'active' }).lean(),
    Conversation.find({
      gymId,
      type: 'owner_trainer',
      ownerId: owner._id,
      status: 'active',
    }).lean(),
    Conversation.find({
      gymId,
      type: 'trainer_member',
      status: 'active',
    }).lean(),
  ]);

  const assignmentByMember = assignments.reduce((acc, assignment) => {
    acc[String(assignment.memberId)] = assignment;
    return acc;
  }, {});
  const assignmentCountByTrainer = assignments.reduce((acc, assignment) => {
    const key = String(assignment.trainerId);
    acc[key] = (acc[key] || 0) + 1;
    return acc;
  }, {});

  const logsByMember = await getRecentLogsForMembers(
    members.map((member) => member._id),
    7,
  );
  const unreadByConversation = await getUnreadCountsByConversation(
    conversations.map((conversation) => conversation._id),
    owner._id,
  );
  const trainerMemberConversationByMember = trainerMemberConversations.reduce(
    (acc, conversation) => {
      acc[String(conversation.memberId)] = conversation;
      return acc;
    },
    {},
  );

  const trainerRows = sortTrainers(trainers.map((trainer) => {
    const conversation =
      conversations.find(
        (entry) => String(entry.trainerId) === String(trainer._id),
      ) || null;

    return {
      id: trainer._id,
      name: trainer.name,
      email: trainer.email,
      clientCount: assignmentCountByTrainer[String(trainer._id)] || 0,
      unreadMessages: conversation
        ? unreadByConversation[String(conversation._id)] || 0
        : 0,
      conversationId: conversation?._id || null,
      updatedAt: trainer.updatedAt || trainer.createdAt,
    };
  }));

  const memberRows = sortMembers(await Promise.all(
    members.map(async (member) => {
      const assignment = assignmentByMember[String(member._id)] || null;
      const logs = logsByMember[String(member._id)] || [];
      const conversation =
        trainerMemberConversationByMember[String(member._id)] || null;
      const summary = await buildClientSummary(
        member,
        assignment,
        logs,
        conversation,
        0,
      );
      const assignedTrainer = assignment
        ? trainers.find(
            (trainer) => String(trainer._id) === String(assignment.trainerId),
          ) || null
        : null;

      return {
        ...summary,
        id: member._id,
        assignedTrainerId: assignedTrainer?._id || null,
        assignedTrainerName: assignedTrainer?.name || null,
        assignedTrainerEmail: assignedTrainer?.email || null,
        assignmentStatus: assignment ? 'assigned' : 'unassigned',
      };
    }),
  ));

  return {
    trainers: trainerRows,
    members: memberRows,
    summary: {
      assignedCount: memberRows.filter((member) => member.assignmentStatus === 'assigned').length,
      unassignedCount: memberRows.filter((member) => member.assignmentStatus === 'unassigned').length,
      unreadTrainerMessages: trainerRows.reduce(
        (sum, trainer) => sum + Number(trainer.unreadMessages || 0),
        0,
      ),
      trainerCount: trainerRows.length,
      memberCount: memberRows.length,
      trainerWorkload: trainerRows.map((trainer) => ({
        trainerId: trainer.id,
        name: trainer.name,
        clientCount: trainer.clientCount,
      })),
    },
  };
}

exports.getOwnerTrainers = async (req, res) => {
  if (!hasRole(req.user, ['owner'])) {
    return res.status(403).json({ message: 'Forbidden: gym_owner only' });
  }

  try {
    const workspace = await buildOwnerWorkspace(req.user);
    return res.status(200).json({
      trainers: workspace.trainers,
      summary: workspace.summary,
    });
  } catch (error) {
    console.error('Error fetching owner trainers:', error);
    return res.status(500).json({ message: 'Error fetching trainers' });
  }
};

exports.getOwnerAssignments = async (req, res) => {
  if (!hasRole(req.user, ['owner'])) {
    return res.status(403).json({ message: 'Forbidden: gym_owner only' });
  }

  try {
    const workspace = await buildOwnerWorkspace(req.user);
    return res.status(200).json(workspace);
  } catch (error) {
    console.error('Error fetching owner assignments:', error);
    return res.status(500).json({ message: 'Error fetching assignments' });
  }
};

exports.assignMemberToTrainer = async (req, res) => {
  if (!hasRole(req.user, ['owner'])) {
    return res.status(403).json({ message: 'Forbidden: gym_owner only' });
  }

  try {
    const gymId = req.user.gymId;
    const { memberId } = req.params;
    const { trainerId, notes = '' } = req.body || {};

    if (!trainerId) {
      return res.status(400).json({ message: 'trainerId is required' });
    }

    const [member, trainer] = await Promise.all([
      User.findOne({ _id: memberId, gymId, role: 'gym_member' }),
      User.findOne({ _id: trainerId, gymId, role: 'gym_trainer' }),
    ]);

    if (!member) {
      return res.status(404).json({ message: 'Member not found in this gym' });
    }
    if (!trainer) {
      return res.status(404).json({ message: 'Trainer not found in this gym' });
    }

    const existingAssignment = await TrainerAssignment.findOne({
      gymId,
      memberId,
      status: 'active',
    });

    if (
      existingAssignment &&
      String(existingAssignment.trainerId) === String(trainerId)
    ) {
      existingAssignment.notes = notes;
      await existingAssignment.save();
      await Promise.all([
        ensureOwnerTrainerConversation({
          gymId,
          trainerId,
          ownerId: req.user._id,
        }),
        ensureTrainerMemberConversation({
          gymId,
          trainerId,
          memberId,
        }),
      ]);
      const workspace = await buildOwnerWorkspace(req.user);
      return res.status(200).json({
        message: 'Assignment updated.',
        assignment: existingAssignment,
        workspace,
      });
    }

    if (existingAssignment) {
      existingAssignment.status = 'archived';
      existingAssignment.unassignedAt = new Date();
      await existingAssignment.save();
    }

    await archiveTrainerMemberConversations({
      gymId,
      memberId,
      exceptTrainerId: trainerId,
    });

    const assignment = await TrainerAssignment.create({
      gymId,
      memberId,
      trainerId,
      ownerId: req.user._id,
      notes,
      status: 'active',
      assignedAt: new Date(),
    });

    await Promise.all([
      ensureOwnerTrainerConversation({
        gymId,
        trainerId,
        ownerId: req.user._id,
      }),
      ensureTrainerMemberConversation({
        gymId,
        trainerId,
        memberId,
      }),
    ]);

    const workspace = await buildOwnerWorkspace(req.user);
    return res.status(200).json({
      message: 'Client assigned successfully.',
      assignment,
      workspace,
    });
  } catch (error) {
    console.error('Error assigning member to trainer:', error);
    return res.status(500).json({ message: 'Error assigning member' });
  }
};

exports.unassignMember = async (req, res) => {
  if (!hasRole(req.user, ['owner'])) {
    return res.status(403).json({ message: 'Forbidden: gym_owner only' });
  }

  try {
    const gymId = req.user.gymId;
    const { memberId } = req.params;

    const assignment = await TrainerAssignment.findOne({
      gymId,
      memberId,
      status: 'active',
    });

    if (!assignment) {
      return res.status(404).json({ message: 'No active assignment found' });
    }

    assignment.status = 'archived';
    assignment.unassignedAt = new Date();
    await assignment.save();

    await archiveTrainerMemberConversations({
      gymId,
      memberId,
    });

    const workspace = await buildOwnerWorkspace(req.user);
    return res.status(200).json({
      message: 'Client unassigned successfully.',
      workspace,
    });
  } catch (error) {
    console.error('Error unassigning member:', error);
    return res.status(500).json({ message: 'Error unassigning member' });
  }
};
