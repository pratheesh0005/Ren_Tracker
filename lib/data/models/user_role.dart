enum UserRole {
  superAdmin,
  admin,
  employee;

  String toValue() {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.admin:
        return 'admin';
      case UserRole.employee:
        return 'employee';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.employee:
        return 'Employee';
    }
  }

  static UserRole fromString(String? val) {
    final normalized = val?.toLowerCase().trim() ?? '';
    if (normalized == 'super_admin' || normalized == 'superadmin') {
      return UserRole.superAdmin;
    } else if (normalized == 'admin') {
      return UserRole.admin;
    } else {
      return UserRole.employee;
    }
  }
}

