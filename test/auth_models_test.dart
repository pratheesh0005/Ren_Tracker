import 'package:flutter_test/flutter_test.dart';
import 'package:ren_tracker/data/models/user_role.dart';
import 'package:ren_tracker/data/models/app_user.dart';

void main() {
  group('UserRole Enum Tests', () {
    test('UserRole.fromString correctly parses role strings', () {
      expect(UserRole.fromString('super_admin'), UserRole.superAdmin);
      expect(UserRole.fromString('superadmin'), UserRole.superAdmin);
      expect(UserRole.fromString('SUPER_ADMIN'), UserRole.superAdmin);
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('ADMIN'), UserRole.admin);
      expect(UserRole.fromString('employee'), UserRole.employee);
      expect(UserRole.fromString(null), UserRole.employee);
      expect(UserRole.fromString('unknown_role'), UserRole.employee);
    });

    test('UserRole.toValue returns correct canonical string', () {
      expect(UserRole.superAdmin.toValue(), 'super_admin');
      expect(UserRole.admin.toValue(), 'admin');
      expect(UserRole.employee.toValue(), 'employee');
    });

    test('UserRole.displayName returns human readable title', () {
      expect(UserRole.superAdmin.displayName, 'Super Admin');
      expect(UserRole.admin.displayName, 'Admin');
      expect(UserRole.employee.displayName, 'Employee');
    });
  });

  group('AppUser Model Tests', () {
    test('AppUser converts to and from Map correctly', () {
      final user = AppUser(
        uid: 'user123',
        email: 'test@example.com',
        phone: '+1 555-0100',
        name: 'Test Admin',
        role: UserRole.admin,
        orgId: 'ren_tracker',
        empId: null,
        isSuspended: false,
      );

      final map = user.toMap();
      expect(map['uid'], 'user123');
      expect(map['email'], 'test@example.com');
      expect(map['role'], 'admin');
      expect(map['orgId'], 'ren_tracker');
      expect(map['status'], 'active');

      final reconstructed = AppUser.fromMap(map, 'user123');
      expect(reconstructed.uid, 'user123');
      expect(reconstructed.email, 'test@example.com');
      expect(reconstructed.isAdmin, isTrue);
      expect(reconstructed.isSuperAdmin, isFalse);
      expect(reconstructed.isEmployee, isFalse);
      expect(reconstructed.isSuspended, isFalse);
    });

    test('AppUser parses suspended status correctly', () {
      final map = {
        'email': 'suspended@example.com',
        'role': 'employee',
        'status': 'suspended',
        'empId': 'EMP999',
      };

      final user = AppUser.fromMap(map, 'user_suspended');
      expect(user.isSuspended, isTrue);
      expect(user.isEmployee, isTrue);
      expect(user.empId, 'EMP999');
    });

    test('AppUser copyWith updates fields immutably', () {
      final original = AppUser(
        uid: 'u1',
        email: 'orig@example.com',
        role: UserRole.employee,
      );

      final updated = original.copyWith(
        name: 'New Name',
        role: UserRole.admin,
        orgId: 'new_org',
      );

      expect(updated.uid, 'u1');
      expect(updated.name, 'New Name');
      expect(updated.role, UserRole.admin);
      expect(updated.orgId, 'new_org');
      expect(original.role, UserRole.employee);
    });
  });
}
