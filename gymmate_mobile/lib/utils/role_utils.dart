String? normalizeRole(String? role) {
  switch (role?.trim().toLowerCase()) {
    case 'superadmin':
    case 'admin':
      return 'admin';
    case 'gym_owner':
    case 'owner':
      return 'owner';
    case 'gym_trainer':
    case 'trainer':
      return 'trainer';
    case 'gym_member':
    case 'member':
      return 'member';
    default:
      return role;
  }
}

bool isAdminRole(String? role) => normalizeRole(role) == 'admin';
bool isOwnerRole(String? role) => normalizeRole(role) == 'owner';
bool isTrainerRole(String? role) => normalizeRole(role) == 'trainer';
bool isMemberRole(String? role) => normalizeRole(role) == 'member';
