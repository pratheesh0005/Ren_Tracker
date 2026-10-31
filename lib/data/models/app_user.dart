import 'user_role.dart';

class AppUser {
  final String uid;
  final String? email;
  final String? phone;
  final String? name;
  final UserRole role;
  final String? orgId;
  final String? empId;
  final bool isSuspended;

  AppUser({
    required this.uid,
    this.email,
    this.phone,
    this.name,
    required this.role,
    this.orgId,
    this.empId,
    this.isSuspended = false,
  });

  bool get isSuperAdmin => role == UserRole.superAdmin;
  bool get isAdmin => role == UserRole.admin;
  bool get isEmployee => role == UserRole.employee;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email ?? '',
      'phone': phone ?? '',
      'name': name ?? '',
      'role': role.toValue(),
      'orgId': orgId ?? '',
      'empId': empId ?? '',
      'status': isSuspended ? 'suspended' : 'active',
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      name: map['name'] as String?,
      role: UserRole.fromString(map['role'] as String?),
      orgId: map['orgId'] as String?,
      empId: map['empId'] as String?,
      isSuspended: (map['status'] as String? ?? 'active') == 'suspended',
    );
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? orgId,
    String? empId,
    bool? isSuspended,
  }) {
    return AppUser(
      uid: uid,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      role: role ?? this.role,
      orgId: orgId ?? this.orgId,
      empId: empId ?? this.empId,
      isSuspended: isSuspended ?? this.isSuspended,
    );
  }
}

