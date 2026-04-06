const Conversation = require('../models/Conversation');
const Message = require('../models/Message');
const TrainerAssignment = require('../models/TrainerAssignment');
const User = require('../models/User');
const {
  ensureOwnerTrainerConversation,
  ensureTrainerMemberConversation,
  getOwnerForGym,
  getUnreadCountsByConversation,
} = require('../services/coachingService');
const { hasRole } = require('../utils/roles');

function canAccessConversation(user, conversation) {
  if (hasRole(user, ['owner'])) {
    return (
      conversation.type === 'owner_trainer' &&
      String(conversation.ownerId) === String(user._id)
    );
  }
  if (hasRole(user, ['trainer'])) {
    return String(conversation.trainerId) === String(user._id);
  }
  if (hasRole(user, ['member'])) {
    return (
      conversation.type === 'trainer_member' &&
      String(conversation.memberId) === String(user._id)
    );
  }
  return false;
}

async function formatConversationList(user, conversations) {
  const userIds = new Set();
  conversations.forEach((conversation) => {
    if (conversation.ownerId) userIds.add(String(conversation.ownerId));
    if (conversation.trainerId) userIds.add(String(conversation.trainerId));
    if (conversation.memberId) userIds.add(String(conversation.memberId));
  });

  const users = await User.find({
    _id: { $in: Array.from(userIds) },
  })
    .select('name email role')
    .lean();
  const userById = users.reduce((acc, entry) => {
    acc[String(entry._id)] = entry;
    return acc;
  }, {});
  const unreadByConversation = await getUnreadCountsByConversation(
    conversations.map((conversation) => conversation._id),
    user._id,
  );

  return conversations.map((conversation) => {
    let participant = null;
    let section = 'clients';

    if (conversation.type === 'owner_trainer') {
      section = 'owner';
      if (hasRole(user, ['owner'])) {
        participant = userById[String(conversation.trainerId)] || null;
      } else {
        participant = userById[String(conversation.ownerId)] || null;
      }
    } else {
      section = 'clients';
      if (hasRole(user, ['trainer'])) {
        participant = userById[String(conversation.memberId)] || null;
      } else {
        participant = userById[String(conversation.trainerId)] || null;
      }
    }

    return {
      id: conversation._id,
      type: conversation.type,
      section,
      status: conversation.status,
      participant: participant
        ? {
            id: participant._id,
            name: participant.name,
            email: participant.email,
            role: participant.role,
          }
        : null,
      unreadCount: unreadByConversation[String(conversation._id)] || 0,
      lastMessageAt: conversation.lastMessageAt || conversation.updatedAt,
      lastMessagePreview: conversation.lastMessagePreview || '',
    };
  });
}

exports.getConversations = async (req, res) => {
  try {
    let query = {};

    if (hasRole(req.user, ['owner'])) {
      query = {
        gymId: req.user.gymId,
        type: 'owner_trainer',
        ownerId: req.user._id,
      };
    } else if (hasRole(req.user, ['trainer'])) {
      query = {
        gymId: req.user.gymId,
        trainerId: req.user._id,
      };
    } else if (hasRole(req.user, ['member'])) {
      query = {
        gymId: req.user.gymId,
        type: 'trainer_member',
        memberId: req.user._id,
      };
    } else {
      return res.status(403).json({ message: 'Forbidden' });
    }

    const conversations = await Conversation.find(query)
      .sort({ lastMessageAt: -1, updatedAt: -1 })
      .lean();

    return res.status(200).json({
      conversations: await formatConversationList(req.user, conversations),
    });
  } catch (error) {
    console.error('Error fetching conversations:', error);
    return res.status(500).json({ message: 'Error fetching conversations' });
  }
};

exports.getConversationMessages = async (req, res) => {
  try {
    const { id } = req.params;
    const conversation = await Conversation.findById(id).lean();

    if (!conversation || !canAccessConversation(req.user, conversation)) {
      return res.status(404).json({ message: 'Conversation not found' });
    }

    await Message.updateMany(
      {
        conversationId: conversation._id,
        senderId: { $ne: req.user._id },
        readBy: { $ne: req.user._id },
      },
      {
        $push: { readBy: req.user._id },
      },
    );

    const messages = await Message.find({
      conversationId: conversation._id,
    })
      .sort({ createdAt: 1 })
      .lean();

    return res.status(200).json({
      conversation: (await formatConversationList(req.user, [conversation]))[0],
      messages: messages.map((message) => ({
        id: message._id,
        body: message.body,
        senderId: message.senderId,
        createdAt: message.createdAt,
        isMine: String(message.senderId) === String(req.user._id),
      })),
    });
  } catch (error) {
    console.error('Error fetching messages:', error);
    return res.status(500).json({ message: 'Error fetching messages' });
  }
};

exports.postMessage = async (req, res) => {
  try {
    const { id } = req.params;
    const body = String(req.body?.body || '').trim();

    if (!body) {
      return res.status(400).json({ message: 'Message body is required' });
    }

    const conversation = await Conversation.findById(id);
    if (!conversation || !canAccessConversation(req.user, conversation)) {
      return res.status(404).json({ message: 'Conversation not found' });
    }
    if (conversation.status !== 'active') {
      return res.status(409).json({ message: 'Archived conversations are read only' });
    }

    const message = await Message.create({
      conversationId: conversation._id,
      senderId: req.user._id,
      body,
      readBy: [req.user._id],
    });

    conversation.lastMessageAt = message.createdAt;
    conversation.lastMessagePreview = body.slice(0, 280);
    await conversation.save();

    return res.status(201).json({
      message: {
        id: message._id,
        body: message.body,
        senderId: message.senderId,
        createdAt: message.createdAt,
        isMine: true,
      },
    });
  } catch (error) {
    console.error('Error posting message:', error);
    return res.status(500).json({ message: 'Error posting message' });
  }
};

exports.createConversation = async (req, res) => {
  try {
    const { type, trainerId, memberId } = req.body || {};

    if (type !== 'owner_trainer' && type !== 'trainer_member') {
      return res.status(400).json({ message: 'A valid conversation type is required' });
    }

    let conversation = null;

    if (type === 'owner_trainer') {
      if (hasRole(req.user, ['owner'])) {
        if (!trainerId) {
          return res.status(400).json({ message: 'trainerId is required' });
        }
        const trainer = await User.findOne({
          _id: trainerId,
          gymId: req.user.gymId,
          role: 'gym_trainer',
        }).lean();
        if (!trainer) {
          return res.status(404).json({ message: 'Trainer not found' });
        }
        conversation = await ensureOwnerTrainerConversation({
          gymId: req.user.gymId,
          trainerId,
          ownerId: req.user._id,
        });
      } else if (hasRole(req.user, ['trainer'])) {
        const owner = await getOwnerForGym(req.user.gymId);
        if (!owner) {
          return res.status(404).json({ message: 'Owner not found for this gym' });
        }
        conversation = await ensureOwnerTrainerConversation({
          gymId: req.user.gymId,
          trainerId: req.user._id,
          ownerId: owner._id,
        });
      } else {
        return res.status(403).json({ message: 'Forbidden' });
      }
    }

    if (type === 'trainer_member') {
      if (hasRole(req.user, ['trainer'])) {
        if (!memberId) {
          return res.status(400).json({ message: 'memberId is required' });
        }
        const assignment = await TrainerAssignment.findOne({
          trainerId: req.user._id,
          gymId: req.user.gymId,
          memberId,
          status: 'active',
        }).lean();
        if (!assignment) {
          return res.status(403).json({ message: 'Client is not assigned to this trainer' });
        }
        conversation = await ensureTrainerMemberConversation({
          gymId: req.user.gymId,
          trainerId: req.user._id,
          memberId,
        });
      } else if (hasRole(req.user, ['member'])) {
        const assignment = await TrainerAssignment.findOne({
          memberId: req.user._id,
          gymId: req.user.gymId,
          status: 'active',
        }).lean();
        if (!assignment) {
          return res.status(403).json({ message: 'No trainer is assigned to this member' });
        }
        conversation = await ensureTrainerMemberConversation({
          gymId: req.user.gymId,
          trainerId: assignment.trainerId,
          memberId: req.user._id,
        });
      } else {
        return res.status(403).json({ message: 'Forbidden' });
      }
    }

    return res.status(200).json({
      conversation: (await formatConversationList(req.user, [conversation.toObject()]))[0],
    });
  } catch (error) {
    console.error('Error creating conversation:', error);
    return res.status(500).json({ message: 'Error creating conversation' });
  }
};
