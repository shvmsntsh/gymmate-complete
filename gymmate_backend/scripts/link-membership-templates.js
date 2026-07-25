/**
 * link-membership-templates.js — Cosmetic fix for launch-gym.js's seed gap.
 *
 * MemberMembership links to MembershipTemplate (not MembershipPlanCatalog),
 * a field launch-gym.js never populated, so the owner-facing Membership
 * page showed "Unknown Plan" for every member. Creates ONE MembershipTemplate
 * ("Monthly") for the gym if it doesn't already exist, and links it to every
 * MemberMembership that currently has no membershipTemplateId. Idempotent
 * and non-destructive - touches only the membershipTemplateId field.
 */
require('dotenv').config();
const mongoose = require('mongoose');
const MembershipTemplate = require('../models/MembershipTemplate');
const MemberMembership = require('../models/MemberMembership');
const Gym = require('../models/Gym');
const User = require('../models/User');

(async () => {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);

  const gym = await Gym.findOne({ gymName: 'Iron Fitness Studio' });
  const owner = await User.findOne({ email: 'owner@ironfitness.in' });
  if (!gym || !owner) {
    console.log('Gym or owner not found - nothing to do.');
    await mongoose.disconnect();
    return;
  }

  let template = await MembershipTemplate.findOne({ gymId: gym._id, name: 'Monthly' });
  if (!template) {
    template = await MembershipTemplate.create({
      gymId: gym._id,
      createdBy: owner._id,
      name: 'Monthly',
      shortDescription: 'Full gym access, billed monthly.',
      durationDays: 30,
      price: 1500,
      active: true,
      visibleToMembers: true,
    });
    console.log('Created template:', template._id);
  } else {
    console.log('Template already exists:', template._id);
  }

  const result = await MemberMembership.updateMany(
    { gymId: gym._id, membershipTemplateId: { $in: [null, undefined] } },
    { $set: { membershipTemplateId: template._id } },
  );
  console.log(`Linked ${result.modifiedCount} membership(s) to "${template.name}".`);

  await mongoose.disconnect();
})();
