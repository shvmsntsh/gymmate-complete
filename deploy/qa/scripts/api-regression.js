(async () => {
  const post = (url, body, token) => fetch(url, { method:'POST', headers:{ 'Content-Type':'application/json', ...(token ? { Authorization:`Bearer ${token}` } : {}) }, body: JSON.stringify(body) });
  const get = (url, token) => fetch(url, { headers: token ? { Authorization:`Bearer ${token}` } : {} });

  const results = {};

  const superadmin = await post('http://127.0.0.1:5050/api/auth/login', { email:'qa_superadmin@gymmate.local', password:'QaAdmin123!' }).then(async r => ({ status:r.status, body:await r.json() }));
  results.superadminLogin = { status: superadmin.status, role: superadmin.body.user?.normalizedRole };

  const owner = await post('http://127.0.0.1:5050/api/auth/login', { email:'qa_owner_iron@gymmate.local', password:'QaOwner123!' }).then(async r => ({ status:r.status, body:await r.json() }));
  results.ownerLogin = { status: owner.status, role: owner.body.user?.normalizedRole, gymName: owner.body.user?.gymName };

  const ownerSelf = await get('http://127.0.0.1:5050/api/gym/self', owner.body.token).then(async r => ({ status:r.status, body:await r.json() }));
  results.ownerSelf = { status: ownerSelf.status, name: ownerSelf.body?.gymName || ownerSelf.body?.name, services: ownerSelf.body?.services };

  const ownerInvites = await get('http://127.0.0.1:5050/api/invite/list', owner.body.token).then(async r => ({ status:r.status, body:await r.json() }));
  results.ownerInvites = { status: ownerInvites.status, count: Array.isArray(ownerInvites.body) ? ownerInvites.body.length : -1 };

  const member = await post('http://127.0.0.1:5050/api/auth/login', { email:'qa_member_iron@gymmate.local', password:'QaMember123!' }).then(async r => ({ status:r.status, body:await r.json() }));
  results.memberLogin = { status: member.status, role: member.body.user?.normalizedRole, hasCompletedOnboarding: member.body.user?.hasCompletedOnboarding };

  const memberMe = await get('http://127.0.0.1:5050/api/auth/me', member.body.token).then(async r => ({ status:r.status, body:await r.json() }));
  results.memberMe = { status: memberMe.status, gymName: memberMe.body?.gymName, hasCompletedOnboarding: memberMe.body?.hasCompletedOnboarding };

  const onboarding = await post('http://127.0.0.1:5050/api/auth/complete-onboarding', {
    profile: { age: 28, gender: 'male', height: 178, weight: 78 },
    fitnessGoals: ['muscle_gain'],
    workoutHabits: { currentActivityLevel: 'moderate', daysPerWeek: 4 },
    dietPreferences: { type: 'high_protein', restrictions: [] },
    firstChallenge: { isAccepted: true, type: 'strength' }
  }, member.body.token).then(async r => ({ status:r.status, body:await r.json() }));
  results.completeOnboarding = { status: onboarding.status, success: onboarding.body?.success ?? onboarding.body?.message ?? null };

  console.log(JSON.stringify(results, null, 2));
})();
