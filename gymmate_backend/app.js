require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

const authRoutes = require('./routes/authRoutes');
const gymRoutes = require('./routes/gymRoutes');
const inviteRoutes = require('./routes/inviteRoutes');
const onboardingRoutes = require('./routes/onboardingRoutes');
const userRoutes = require('./routes/userRoutes');
const planRoutes = require('./routes/planRoutes');
const memberRoutes = require('./routes/memberRoutes');
const trainerRoutes = require('./routes/trainerRoutes');
const ownerRoutes = require('./routes/ownerRoutes');
const messageRoutes = require('./routes/messageRoutes');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/gymmate';

let mongoConnectionPromise = null;

async function connectToMongo() {
  if (mongoose.connection.readyState === 1) {
    return mongoose.connection;
  }

  if (mongoConnectionPromise) {
    await mongoConnectionPromise;
    return mongoose.connection;
  }

  mongoConnectionPromise = mongoose
    .connect(MONGODB_URI)
    .then((connection) => {
      return connection;
    })
    .catch((error) => {
      mongoConnectionPromise = null;
      throw error;
    });

  await mongoConnectionPromise;
  return mongoose.connection;
}

const allowedOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

const corsOptions = allowedOrigins.length
  ? {
      origin(origin, callback) {
        if (!origin || allowedOrigins.includes(origin)) {
          callback(null, true);
          return;
        }
        callback(new Error('Not allowed by CORS'));
      },
      credentials: true,
    }
  : { origin: true, credentials: true };

const app = express();

app.use(cors(corsOptions));
app.use(express.json({ limit: '10mb' }));

const handleHealthCheck = async (_req, res) => {
  try {
    await connectToMongo();
    res.status(200).json({ ok: true });
  } catch (error) {
    console.error('Health check failed:', error);
    res.status(500).json({ ok: false, error: 'database_unavailable' });
  }
};

app.get('/health', handleHealthCheck);
app.get('/api/health', handleHealthCheck);

app.use(async (_req, _res, next) => {
  try {
    await connectToMongo();
    next();
  } catch (error) {
    console.error('MongoDB connection error:', error);
    next(error);
  }
});

app.use('/api/auth', authRoutes);
app.use('/api/gym', gymRoutes);
app.use('/api/invite', inviteRoutes);
app.use('/api/onboarding', onboardingRoutes);
app.use('/api/user', userRoutes);
app.use('/api/plans', planRoutes);
app.use('/api/member', memberRoutes);
app.use('/api/trainer', trainerRoutes);
app.use('/api/owner', ownerRoutes);
app.use('/api/messages', messageRoutes);

app.use((error, _req, res, _next) => {
  console.error('Unhandled application error:', error);
  res.status(500).json({
    message: 'Internal server error',
    error: error.message,
  });
});

module.exports = {
  app,
  connectToMongo,
};
