import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ren_tracker/features/dashboard/admin_dashboard.dart';
import 'package:ren_tracker/features/attendance/admin_attendance.dart';
import 'package:ren_tracker/features/dashboard/admin_employees.dart';
import 'package:ren_tracker/features/reports/admin_salary.dart';
import 'package:ren_tracker/features/dashboard/admin_notifications.dart';
import 'package:ren_tracker/core/constants/env_config.dart';
import 'package:ren_tracker/core/services/auth_service.dart';
import 'package:ren_tracker/data/repositories/firestore_repository.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _selectedIndex = 0;
  String _orgName = 'Ren Tracker';
  String _orgId = EnvConfig.defaultOrgId;
  bool _isSuperAdmin = false;

  final List<Widget> _screens = const [
    AdminDashboard(),
    AdminAttendance(),
    AdminEmployees(),
    AdminSalary(),
    AdminNotifications(),
  ];

  @override
  void initState() {
    super.initState();
    _loadTenantInfo();
  }

  Future<void> _loadTenantInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');
    final org = prefs.getString('org_id') ?? EnvConfig.defaultOrgId;

    setState(() {
      _orgId = org;
      _isSuperAdmin = role == 'super_admin';
    });

    try {
      final fs = FirestoreRepository(orgId: org);
      final details = await fs.getOrganizationDetails();
      if (mounted) {
        setState(() {
          _orgName = details['name'] ?? ((_orgId == 'ren_tracker' || _orgId == 'renish_electronics') ? 'Ren Tracker' : _orgId);
        });
      }
    } catch (_) {}
  }

  void _triggerMigrationDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        bool migrating = false;
        String? resultMessage;

        return StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.sync_alt, color: Color(0xFF1e3a8a)),
                SizedBox(width: 8),
                Text('SaaS Data Migration', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mirrors existing root data into the tenant-isolated organization '
                    '(organizations/$_orgId/) without removing any legacy records.',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (resultMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(resultMessage!, style: const TextStyle(color: Color(0xFF16a34a), fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: migrating
                    ? null
                    : () async {
                        setDialog(() => migrating = true);
                        final fs = FirestoreRepository(orgId: _orgId);
                        final res = await fs.migrateLegacyRenishData();
                        setDialog(() {
                          migrating = false;
                          if (res['success'] == true) {
                            resultMessage = '✅ Success!\n'
                                '• Employees: ${res['employees']}\n'
                                '• Attendance Dates: ${res['attendanceDates']}\n'
                                '• Notifications: ${res['notifications']}';
                          } else {
                            resultMessage = '❌ Error: ${res['error']}';
                          }
                        });
                      },
                child: migrating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Execute Mirror'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _triggerVerifyDbDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        bool checking = true;
        Map<String, dynamic>? report;

        return StatefulBuilder(
          builder: (ctx, setDialog) {
            if (checking && report == null) {
              final fs = FirestoreRepository(orgId: _orgId);
              fs.verifyDatabaseIntegrity().then((res) {
                if (ctx.mounted) {
                  setDialog(() {
                    report = res;
                    checking = false;
                  });
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.verified_outlined, color: Color(0xFF16a34a)),
                  SizedBox(width: 8),
                  Text('Firestore Storage Check', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
              content: checking
                  ? const SizedBox(
                      height: 120,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Checking Firestore collections...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: report?['success'] == true ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: report?['success'] == true ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  report?['success'] == true ? Icons.check_circle : Icons.error,
                                  color: report?['success'] == true ? const Color(0xFF16a34a) : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    report?['status'] ?? report?['error'] ?? 'Check complete',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: report?['success'] == true ? const Color(0xFF16a34a) : Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text('Tenant Storage Status:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          const SizedBox(height: 6),
                          _buildVerifyRow('Organization', report?['orgExists'] == true ? '✅ ${report?['orgName']} (${report?['orgId']})' : '❌ Not Found'),
                          _buildVerifyRow('Employees Stored', '✅ ${report?['tenantEmployees'] ?? 0} staff (${report?['employeesWithDevice'] ?? 0} devices linked)'),
                          _buildVerifyRow('Attendance Stored', '✅ ${report?['tenantAttendanceDates'] ?? 0} dates (${report?['tenantAttendanceRecords'] ?? 0} total records)'),
                          _buildVerifyRow('Announcements', '✅ ${report?['tenantNotifications'] ?? 0} notices in live stream'),
                          _buildVerifyRow('Corrections', '✅ ${report?['tenantCorrections'] ?? 0} requests (${report?['pendingCorrections'] ?? 0} pending)'),
                          if ((_orgId == 'ren_tracker' || _orgId == 'renish_electronics') && report?['legacyEmployees'] != null) ...[
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            const Text('Legacy Mirror Verification:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            const SizedBox(height: 6),
                            _buildVerifyRow('Legacy Employees', '${report?['legacyEmployees']} root → ${report?['tenantEmployees']} tenant'),
                            _buildVerifyRow('Legacy Notices', '${report?['legacyNotifications']} root → ${report?['tenantNotifications']} tenant'),
                            _buildVerifyRow('Legacy Attendance', '${report?['legacyAttendanceDates']} root → ${report?['tenantAttendanceDates']} tenant'),
                            _buildVerifyRow('Mirror Status', report?['isFullyMirrored'] == true ? '✅ Fully Synchronized' : '⚠️ Run Data Migration to mirror'),
                          ],
                        ],
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setDialog(() {
                      checking = true;
                      report = null;
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Re-Check'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildVerifyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 32,
                  height: 32,
                  color: Colors.white24,
                  child: const Icon(Icons.apartment, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_orgName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text(_orgId, style: const TextStyle(fontSize: 10, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  _isSuperAdmin ? Icons.stars : Icons.verified_user,
                  color: _isSuperAdmin ? Colors.amber : Colors.white,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  _isSuperAdmin ? 'SUPER ADMIN' : 'ADMIN',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (val) async {
              if (val == 'logout') {
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              } else if (val == 'verify_db') {
                _triggerVerifyDbDialog();
              } else if (val == 'migrate') {
                _triggerMigrationDialog();
              } else if (val == 'super_admin') {
                Navigator.pushNamed(context, '/super_admin_home');
              }
            },
            itemBuilder: (_) => [
              if (_isSuperAdmin)
                const PopupMenuItem(
                  value: 'super_admin',
                  child: Row(children: [
                    Icon(Icons.stars, size: 18, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('Super Admin Console'),
                  ]),
                ),
              const PopupMenuItem(
                value: 'verify_db',
                child: Row(children: [
                  Icon(Icons.verified_outlined, size: 18, color: Color(0xFF16a34a)),
                  SizedBox(width: 8),
                  Text('Verify Firestore Storage'),
                ]),
              ),
              const PopupMenuItem(
                value: 'migrate',
                child: Row(children: [
                  Icon(Icons.sync, size: 18, color: Color(0xFF1e3a8a)),
                  SizedBox(width: 8),
                  Text('Data Migration'),
                ]),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Sign Out'),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF1e3a8a).withOpacity(0.12),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: 'Attendance'),
          NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Employees'),
          NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments),
              label: 'Salary'),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: 'Notify'),
        ],
      ),
    );
  }
}

