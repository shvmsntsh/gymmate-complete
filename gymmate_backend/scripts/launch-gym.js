/**
 * launch-gym.js — Launch ONE real gym with a full staff/member roster.
 *
 * SAFETY: This script is NON-DESTRUCTIVE.
 *   - There is no deleteMany / drop / remove anywhere in this file.
 *   - It is idempotent: re-running upserts the same records by unique email.
 *   - Passwords are set ONLY on first create, so re-runs never clobber a
 *     password the owner has since changed.
 *
 * Usage:
 *   MONGODB_URI="..." JWT_SECRET="..." node scripts/launch-gym.js --dry-run
 *   MONGODB_URI="..." JWT_SECRET="..." node scripts/launch-gym.js
 *
 * Flags:
 *   --dry-run   Print exactly what would be created/updated. Writes NOTHING.
 */

require('dotenv').config();
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { normalizeIndianPhone } = require('../utils/phone');

const User = require('../models/User');
const Gym = require('../models/Gym');
const { InviteCode } = require('../models/InviteCode');
const MembershipPlanCatalog = require('../models/MembershipPlanCatalog');
const MemberMembership = require('../models/MemberMembership');
const PaymentEntry = require('../models/PaymentEntry');
const AttendanceEvent = require('../models/AttendanceEvent');
const TrainerAssignment = require('../models/TrainerAssignment');
const Announcement = require('../models/Announcement');

const DRY_RUN = process.argv.includes('--dry-run');

const MONGODB_URI =
  process.env.MONGODB_URI || process.env.MONGO_URI || '';
const JWT_SECRET = process.env.JWT_SECRET || '';

// Tokens for testing only. Longer than the app's 2h so a full test pass
// doesn't expire halfway through.
const TEST_TOKEN_TTL = '12h';

// ─────────────────────────────────────────────────────────────
// Placeholder identity — rename in Settings after launch.
// All phones are valid Indian mobiles (10 digits, start 6-9).
// ─────────────────────────────────────────────────────────────
const GYM = {
  gymName: 'Iron Fitness Studio',
  email: 'hello@ironfitness.in',
  address: 'Shop 4, Linking Road, Bandra West, Mumbai 400050',
  contactNumber: '9820010000',
  platformPlan: 'growth_1000',
  memberCap: 1000,
};

const SUPERADMIN = {
  name: 'Platform Admin',
  email: 'shivamtih@gmail.com',
  phone_number: '9820010001',
  password: 'ChangeMe#Admin1',
  role: 'superadmin',
};

const OWNER = {
  name: 'Arjun Mehta',
  email: 'owner@ironfitness.in',
  phone_number: '9820011001',
  password: 'ChangeMe#Owner1',
  role: 'gym_owner',
};

// Two staff with DIFFERENT capability sets, so the permission map is
// actually exercised rather than assumed.
const STAFF = [
  {
    name: 'Priya Nair',
    email: 'priya.frontdesk@ironfitness.in',
    phone_number: '9820011002',
    password: 'ChangeMe#Staff1',
    role: 'gym_staff',
    label: 'Full front desk',
    staffCapabilities: {
      'workspace.access': true,
      'members.view': true,
      'members.manage': true,
      'payments.manage': true,
      'receipts.view': true,
      'attendance.manage': true,
      'announcements.manage': true,
      'membership.requests.manage': true,
    },
  },
  {
    name: 'Rohit Desai',
    email: 'rohit.attendance@ironfitness.in',
    phone_number: '9820011003',
    password: 'ChangeMe#Staff2',
    role: 'gym_staff',
    label: 'Attendance only (restricted)',
    staffCapabilities: {
      'workspace.access': true,
      'members.view': true,
      'attendance.manage': true,
    },
  },
];

const TRAINER = {
  name: 'Kavya Iyer',
  email: 'kavya.trainer@ironfitness.in',
  phone_number: '9820011004',
  password: 'ChangeMe#Trainer1',
  role: 'gym_trainer',
};

// 10 members. `state` drives membership dates so every UI state is
// represented in screenshots and testing:
//   active   -> healthy, mid-cycle
//   expiring -> renewal_due in 3 days (tests the reminder path)
//   expired  -> lapsed (tests the blocked/expired UI)
//   unclaimed-> invited but never claimed (tests the claim flow, no password)
// `goal` must be a value from the User.fitnessGoals enum:
//   ['muscle_gain','fat_loss','endurance','flexibility','strength',
//    'general_fitness','weight_maintenance','muscle','performance', null]
// `sex` must be from profile.gender enum: ['male','female','other',
//   'prefer_not_to_say', null]
const MEMBERS = [
  { name: 'Rahul Sharma',   phone_number: '9820012001', state: 'active',    goal: 'muscle_gain',     sex: 'male'   },
  { name: 'Ananya Patel',   phone_number: '9820012002', state: 'active',    goal: 'fat_loss',        sex: 'female' },
  { name: 'Vikram Singh',   phone_number: '9820012003', state: 'active',    goal: 'general_fitness', sex: 'male'   },
  { name: 'Sneha Reddy',    phone_number: '9820012004', state: 'active',    goal: 'fat_loss',        sex: 'female' },
  { name: 'Karan Malhotra', phone_number: '9820012005', state: 'active',    goal: 'performance',     sex: 'male'   },
  { name: 'Divya Menon',    phone_number: '9820012006', state: 'expiring',  goal: 'muscle_gain',     sex: 'female' },
  { name: 'Aditya Rao',     phone_number: '9820012007', state: 'expiring',  goal: 'general_fitness', sex: 'male'   },
  { name: 'Meera Joshi',    phone_number: '9820012008', state: 'expired',   goal: 'fat_loss',        sex: 'female' },
  { name: 'Nikhil Kapoor',  phone_number: '9820012009', state: 'unclaimed', goal: 'muscle_gain',     sex: 'male'   },
  { name: 'Pooja Verma',    phone_number: '9820012010', state: 'unclaimed', goal: 'fat_loss',        sex: 'female' },
];

const PLANS = [
  { name: 'Monthly',   durationDays: 30,  price: 1500, description: 'Full gym access, billed monthly.' },
  { name: 'Quarterly', durationDays: 90,  price: 4000, description: '3 months access. Save Rs 500.' },
  { name: 'Annual',    durationDays: 365, price: 14000, description: '12 months access. Best value.' },
];

// ─────────────────────────────────────────────────────────────
const created = [];
const updated = [];
const skipped = [];
// Emails whose password this run actually SET. Only these can be reported
// with a working password — pre-existing accounts keep their own.
const passwordSet = new Set();

function log(msg) { console.log(msg); }
function note(kind, what) {
  if (kind === 'create') created.push(what);
  else if (kind === 'update') updated.push(what);
  else skipped.push(what);
}

function daysFromNow(n) {
  const d = new Date();
  d.setDate(d.getDate() + n);
  d.setHours(12, 0, 0, 0);
  return d;
}

function randomCode(prefix) {
  // Deterministic-ish readable codes; uniqueness enforced by the DB.
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = '';
  for (let i = 0; i < 5; i += 1) {
    out += chars[Math.floor(Math.random() * chars.length)];
  }
  return `${prefix}${out}`;
}

function profileBundle(goal, sex, idx) {
  // Deterministic per member index so re-runs produce identical values.
  const female = sex === 'female';
  return {
    hasCompletedOnboarding: true,
    onboardingProgress: {
      isCompleted: true,
      currentStep: 7,
      stepsCompleted: [1, 2, 3, 4, 5, 6, 7],
      startedAt: new Date(),
      completedAt: new Date(),
      totalSteps: 7,
    },
    profile: {
      age: 24 + ((idx * 3) % 14),
      gender: sex,                                  // enum: male|female|other
      weight: (female ? 54 : 68) + ((idx * 2) % 14),
      height: (female ? 156 : 168) + ((idx * 3) % 12),
    },
    fitnessGoals: [goal],                           // array of enum STRINGS
  };
}

/**
 * Upsert a user by email. Uses .save() so the pre('save') bcrypt hook fires —
 * an updateOne/insertMany here would store the password in PLAINTEXT.
 * Password is only set on create.
 */
async function upsertUser(spec, gymId, extra = {}, opts = {}) {
  const email = String(spec.email).trim().toLowerCase();
  // Store the SAME canonical +91 format quickLogin's lookup uses
  // (normalizeIndianPhone/indianPhoneVariants) — a bare 10-digit value here
  // would silently fail that lookup, fall through to creating a duplicate
  // user with the same email, and hang the request on the resulting
  // unhandled E11000 error.
  const canonicalPhone = normalizeIndianPhone(spec.phone_number) || spec.phone_number;
  spec = { ...spec, phone_number: canonicalPhone };
  const existing = await User.findOne({ email });

  if (existing) {
    // preserveExisting: the account predates this script and belongs to the
    // operator. Touch nothing — overwriting their name/phone/password would
    // be destructive in spirit even though no document is deleted.
    if (opts.preserveExisting) {
      note('skip', `User  ${email}  (${existing.role}) — pre-existing, left untouched`);
      return existing;
    }
    note('update', `User  ${email}  (${spec.role})`);
    if (DRY_RUN) return existing;
    existing.name = spec.name;
    existing.phone_number = spec.phone_number;
    existing.role = spec.role;
    if (gymId) existing.gymId = gymId;
    if (spec.staffCapabilities) existing.staffCapabilities = spec.staffCapabilities;
    Object.assign(existing, extra);
    await existing.save();
    return existing;
  }

  note('create', `User  ${email}  (${spec.role})`);
  if (spec.password) passwordSet.add(email);

  // Validated even in dry-run, so schema errors surface before a live write.
  return createDoc(User, {
    name: spec.name,
    email,
    phone_number: spec.phone_number,
    role: spec.role,
    accountStatus: 'active',
    ...(gymId ? { gymId } : {}),
    ...(spec.password ? { password: spec.password } : {}),
    ...(spec.staffCapabilities ? { staffCapabilities: spec.staffCapabilities } : {}),
    ...extra,
  }, `User ${email}`);
}

/**
 * Construct + VALIDATE a document, saving only on a live run.
 * Validation runs in dry-run too, so --dry-run genuinely catches schema
 * errors (enum mismatches, missing required fields) before touching prod.
 */
async function createDoc(Model, payload, label) {
  const doc = new Model(payload);
  const err = doc.validateSync();
  if (err) {
    const fields = Object.keys(err.errors || {}).join(', ');
    throw new Error(`${label}: validation failed on [${fields}] — ${err.message}`);
  }
  if (!DRY_RUN) await doc.save();
  return doc;
}

function mintToken(user, gymName) {
  if (!JWT_SECRET) return '(JWT_SECRET not set — cannot mint)';
  return jwt.sign(
    {
      id: user._id,
      email: user.email,
      role: user.role,
      gymId: user.gymId || null,
      gymName: gymName || null,
    },
    JWT_SECRET,
    { expiresIn: TEST_TOKEN_TTL },
  );
}

async function main() {
  if (!MONGODB_URI) {
    console.error('ERROR: MONGODB_URI (or MONGO_URI) is required.');
    process.exit(1);
  }

  log('');
  log('═'.repeat(66));
  log(DRY_RUN
    ? '  DRY RUN — nothing will be written to the database'
    : '  LIVE RUN — writing to the database');
  log('═'.repeat(66));
  log(`  Target: ${MONGODB_URI.replace(/\/\/[^@]*@/, '//***:***@')}`);
  log('');

  await mongoose.connect(MONGODB_URI);

  // ── Gym ────────────────────────────────────────────────────
  let gym = await Gym.findOne({ email: GYM.email.toLowerCase() });
  if (gym) {
    note('update', `Gym   ${GYM.gymName}`);
    if (!DRY_RUN) {
      gym.gymName = GYM.gymName;
      gym.address = GYM.address;
      gym.contactNumber = GYM.contactNumber;
      gym.platformPlan = GYM.platformPlan;
      gym.memberCap = GYM.memberCap;
      gym.status = 'active';
      await gym.save();
    }
  } else {
    note('create', `Gym   ${GYM.gymName}`);
    gym = await createDoc(Gym, {
      gymName: GYM.gymName,
      email: GYM.email.toLowerCase(),
      address: GYM.address,
      contactNumber: GYM.contactNumber,
      platformPlan: GYM.platformPlan,
      memberCap: GYM.memberCap,
      status: 'active',
      role: 'gym_owner',
    }, `Gym ${GYM.gymName}`);
  }
  const gymId = gym._id;

  // ── People ─────────────────────────────────────────────────
  // Platform Admin: never mutated if it already exists.
  const superadmin = await upsertUser(SUPERADMIN, null, {}, { preserveExisting: true });
  const owner = await upsertUser(OWNER, gymId);
  const staff = [];
  for (const s of STAFF) staff.push(await upsertUser(s, gymId));
  const trainer = await upsertUser(TRAINER, gymId);

  // Link gym -> owner
  if (!DRY_RUN && gym.owner?.toString() !== owner._id.toString()) {
    gym.owner = owner._id;
    await gym.save();
  }

  // ── Membership plan catalog ────────────────────────────────
  for (const p of PLANS) {
    const found = await MembershipPlanCatalog.findOne({ gymId, name: p.name });
    if (found) { note('skip', `Plan  ${p.name} (exists)`); continue; }
    note('create', `Plan  ${p.name} — Rs ${p.price} / ${p.durationDays}d`);
    {
      await createDoc(MembershipPlanCatalog, {
        gymId,
        createdBy: owner._id,
        name: p.name,
        durationDays: p.durationDays,
        price: p.price,
        description: p.description,
        active: true,
      });
    }
  }

  // ── Members, memberships, payments, attendance ─────────────
  const inviteRows = [];
  let memberIdx = 0;

  for (const m of MEMBERS) {
    memberIdx += 1;
    const slug = m.name.toLowerCase().replace(/[^a-z]+/g, '.');
    const email = `${slug}@ironfitness.in`;
    const isUnclaimed = m.state === 'unclaimed';

    // Unclaimed members are `invited` so the model's conditional password
    // requirement is satisfied without setting a password.
    const extra = isUnclaimed
      ? { invited: true, registered: false }
      : {
          invited: true,
          registered: true,
          registrationMethod: 'invite_registration',
          registeredFromInviteAt: daysFromNow(-45),
          ...profileBundle(m.goal, m.sex, memberIdx),
        };

    const member = await upsertUser(
      {
        name: m.name,
        email,
        phone_number: m.phone_number,
        role: 'gym_member',
        ...(isUnclaimed ? {} : { password: 'ChangeMe#Member1' }),
      },
      gymId,
      extra,
    );

    // Every member (claimed or not) needs a live invite code:
    //  - unclaimed -> so the passwordless claim flow can be tested
    //  - claimed   -> skipped, they're already in
    if (isUnclaimed) {
      const code = randomCode('MEM');
      inviteRows.push({ role: 'gym_member', name: m.name, phone: m.phone_number, code });
      const existingInvite = await InviteCode.findOne({
        inviteePhone: m.phone_number, role: 'gym_member', used: false,
      });
      if (existingInvite) {
        note('skip', `Invite ${m.name} (unused invite exists: ${existingInvite.code})`);
        inviteRows[inviteRows.length - 1].code = existingInvite.code;
      } else {
        note('create', `Invite ${m.name} -> ${code}`);
        {
          await createDoc(InviteCode, {
            code,
            role: 'gym_member',
            gymId,
            inviteeName: m.name,
            inviteeEmail: email,
            inviteePhone: m.phone_number,
            createdBy: owner._id,
            used: false,
          });
        }
      }
      continue; // no membership/payments for a member who hasn't joined yet
    }

    // Membership dates per state
    let startDate; let endDate; let status;
    if (m.state === 'active')   { startDate = daysFromNow(-20); endDate = daysFromNow(10); status = 'active'; }
    if (m.state === 'expiring') { startDate = daysFromNow(-27); endDate = daysFromNow(3);  status = 'renewal_due'; }
    if (m.state === 'expired')  { startDate = daysFromNow(-60); endDate = daysFromNow(-8); status = 'expired'; }

    const existingMembership = await MemberMembership.findOne({ gymId, memberId: member._id });
    if (existingMembership) {
      note('skip', `Membership ${m.name} (exists)`);
    } else {
      note('create', `Membership ${m.name} — ${status} (ends ${endDate.toDateString()})`);
      {
        await createDoc(MemberMembership, {
          gymId,
          memberId: member._id,
          status,
          paymentStatus: m.state === 'expired' ? 'unpaid' : 'paid',
          paymentMethod: m.state === 'expired' ? null : 'upi',
          startDate,
          endDate,
          nextRenewalDate: endDate,
          isActiveBaseMembership: m.state !== 'expired',
        });
      }
    }

    // One payment for anyone who has paid
    if (m.state !== 'expired') {
      const existingPayment = await PaymentEntry.findOne({ gymId, memberId: member._id });
      if (existingPayment) {
        note('skip', `Payment ${m.name} (exists)`);
      } else {
        note('create', `Payment ${m.name} — Rs 1500`);
        {
          await createDoc(PaymentEntry, {
            gymId,
            memberId: member._id,
            amount: 1500,
            mode: memberIdx % 2 === 0 ? 'upi' : 'cash', // never null: enum forbids it
            recordedBy: staff[0]?._id || owner._id,
            recordedAt: startDate,
            note: 'Membership fee',
          });
        }
      }
    }

    // Attendance — 4 check-ins each.
    // AttendanceEvent has a COMPOUND UNIQUE index on
    // {integrationId, externalEventId}. Both default to null, so a second
    // row with defaults collides (E11000). Every row therefore gets a
    // distinct externalEventId.
    const existingAttendance = await AttendanceEvent.countDocuments({ gymId, memberId: member._id });
    if (existingAttendance > 0) {
      note('skip', `Attendance ${m.name} (${existingAttendance} events exist)`);
    } else {
      note('create', `Attendance ${m.name} — 4 check-ins`);
      {
        for (let d = 1; d <= 4; d += 1) {
          await createDoc(AttendanceEvent, {
            gymId,
            memberId: member._id,
            occurredAt: daysFromNow(-d * 2), // required, no default
            eventType: 'check_in',
            source: 'manual',
            externalEventId: `launch-${member._id}-${d}`, // avoids E11000
          });
        }
      }
    }

    // Assign first 3 claimed members to the trainer
    if (memberIdx <= 3) {
      const existingAssign = await TrainerAssignment.findOne({
        gymId, memberId: member._id, trainerId: trainer._id,
      });
      if (existingAssign) {
        note('skip', `TrainerAssignment ${m.name} (exists)`);
      } else {
        note('create', `TrainerAssignment ${m.name} -> ${TRAINER.name}`);
        {
          await createDoc(TrainerAssignment, {
            gymId,
            memberId: member._id,
            trainerId: trainer._id,
            ownerId: owner._id, // required, easy to miss
            status: 'active',
          });
        }
      }
    }
  }

  // ── Spare trainer invite (passwordless claim flow) ──────────
  const spareTrainerPhone = '9820011005';
  const existingTrainerInvite = await InviteCode.findOne({
    inviteePhone: spareTrainerPhone, role: 'gym_trainer', used: false,
  });
  if (existingTrainerInvite) {
    note('skip', `Invite trainer (unused invite exists: ${existingTrainerInvite.code})`);
    inviteRows.push({ role: 'gym_trainer', name: 'Spare Trainer', phone: spareTrainerPhone, code: existingTrainerInvite.code });
  } else {
    const code = randomCode('TRN');
    inviteRows.push({ role: 'gym_trainer', name: 'Spare Trainer', phone: spareTrainerPhone, code });
    note('create', `Invite Spare Trainer -> ${code}`);
    {
      await createDoc(InviteCode, {
        code,
        role: 'gym_trainer',
        gymId,
        inviteeName: 'Spare Trainer',
        inviteeEmail: 'spare.trainer@ironfitness.in',
        inviteePhone: spareTrainerPhone,
        createdBy: owner._id,
        used: false,
      });
    }
  }

  // ── Announcements ──────────────────────────────────────────
  // status is explicitly 'draft'. The model DEFAULTS to 'sent', which would
  // broadcast to real members on a production run.
  const anns = [
    { title: 'Welcome to Iron Fitness Studio', body: 'Your gym is now on GymMate. Download nothing — just open the link on your phone to see your workout and meal plan.' },
    { title: 'New Year offer: Annual plan Rs 14,000', body: 'Save Rs 4,000 versus monthly billing. Ask at the front desk to upgrade.' },
  ];
  for (const a of anns) {
    const found = await Announcement.findOne({ gymId, title: a.title });
    if (found) { note('skip', `Announcement "${a.title}" (exists)`); continue; }
    note('create', `Announcement "${a.title}" (draft)`);
    {
      await createDoc(Announcement, {
        gymId,
        createdBy: owner._id,
        title: a.title,
        body: a.body,
        type: 'general',
        status: 'draft',
      });
    }
  }

  // ── Report ─────────────────────────────────────────────────
  log('');
  log('─'.repeat(66));
  const verb = DRY_RUN ? "WOULD " : "";
  log(`  ${verb}CREATE: ${created.length}   ${verb}UPDATE: ${updated.length}   SKIP: ${skipped.length}`);
  log('─'.repeat(66));
  created.forEach((c) => log(`  + ${c}`));
  updated.forEach((c) => log(`  ~ ${c}`));
  skipped.forEach((c) => log(`  . ${c}`));

  log('');
  log('═'.repeat(66));
  log('  LOGIN CREDENTIALS');
  log('═'.repeat(66));
  const cred = (label, email, password, suffix = '') => {
    const e = String(email).toLowerCase();
    const shown = passwordSet.has(e)
      ? password
      : '(pre-existing account — your current password is unchanged)';
    log(`  ${label.padEnd(15)} ${e}`);
    log(`  ${''.padEnd(15)} ${shown}${suffix ? `   [${suffix}]` : ''}`);
  };
  cred('Platform Admin', SUPERADMIN.email, SUPERADMIN.password);
  cred('Gym Owner', OWNER.email, OWNER.password);
  STAFF.forEach((s) => cred('Staff', s.email, s.password, s.label));
  cred('Trainer', TRAINER.email, TRAINER.password);
  log(`  ${'Members'.padEnd(15)} <first.last>@ironfitness.in`);
  log(`  ${''.padEnd(15)} ChangeMe#Member1   [claimed members only]`);

  log('');
  log('═'.repeat(66));
  log(`  TEST JWTs (admin web app, ${TEST_TOKEN_TTL})`);
  log('═'.repeat(66));
  const tokenTargets = [
    ['admin',   superadmin],
    ['owner',   owner],
    ['staff1',  staff[0]],
    ['staff2',  staff[1]],
    ['trainer', trainer],
  ];
  tokenTargets.forEach(([label, u]) => {
    if (!u) return;
    log(`  ${label}:`);
    log(`  ${mintToken(u, GYM.gymName)}`);
    log('');
  });

  log('═'.repeat(66));
  log('  PASSWORDLESS INVITE CODES (mobile app claim flow)');
  log('═'.repeat(66));
  inviteRows.forEach((r) => {
    log(`  ${r.role.padEnd(12)} ${r.name.padEnd(16)} phone ${r.phone}  code ${r.code}`);
  });

  log('');
  if (DRY_RUN) {
    log('  DRY RUN COMPLETE — nothing was written.');
    log('  Re-run without --dry-run to apply.');
  } else {
    log('  LAUNCH COMPLETE.');
    log('  Change every ChangeMe# password before real use.');
  }
  log('');

  await mongoose.disconnect();
}

main().catch(async (err) => {
  console.error('');
  console.error('FAILED:', err.message);
  if (err.code === 11000) {
    console.error('Duplicate key — a unique field (email / phone_number / invite code) already exists.');
    console.error('Key:', JSON.stringify(err.keyValue));
  }
  try { await mongoose.disconnect(); } catch (_) {}
  process.exit(1);
});
