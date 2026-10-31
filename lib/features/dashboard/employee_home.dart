import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ren_tracker/core/constants/env_config.dart';
import 'package:ren_tracker/data/repositories/firestore_repository.dart';
import 'package:ren_tracker/core/services/auth_service.dart';
import 'package:ren_tracker/core/services/onesignal_service.dart';

class EmployeeHome extends StatefulWidget {
  const EmployeeHome({super.key});
  @override
  State<EmployeeHome> createState() => _EmployeeHomeState();
}

class _EmployeeHomeState extends State<EmployeeHome> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _empData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_empData == null) {
      _empData = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (_empId.isNotEmpty) {
        _syncOneSignal();
      } else {
        _restoreEmpFromPrefs();
      }
    }
  }

  Future<void> _restoreEmpFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefOrg = prefs.getString('org_id') ?? EnvConfig.defaultOrgId;
      final prefEmp = prefs.getString('emp_id') ?? '';
      if (prefEmp.isNotEmpty) {
        final fs = FirestoreService(orgId: prefOrg);
        final emp = await fs.getEmployee(prefEmp);
        if (mounted) {
          setState(() {
            _empData = {'id': prefEmp, 'orgId': prefOrg, ...?emp};
          });
          _syncOneSignal();
        }
      }
    } catch (_) {}
  }

  void _syncOneSignal() {
    if (_empId.isEmpty) return;
    try {
      OneSignal.login(_empId);
      OneSignal.User.addAliases({'empId': _empId, 'orgId': _orgId});
    } catch (_) {}
    OneSignalService.setTenantTags(
      orgId: _orgId,
      role: 'employee',
      empId: _empId,
    );
    OneSignalService().saveEmployeePlayerId(
      orgId: _orgId,
      empId: _empId,
    );
  }

  String get _orgId => (_empData?['orgId'] as String?) ?? EnvConfig.defaultOrgId;
  String get _empId => (_empData?['id'] as String?) ?? (_empData?['empId'] as String?) ?? '';

  List<Widget> get _screens => [
    _EmpDashboard(empData: _empData, orgId: _orgId),
    _EmpAttendance(empData: _empData, orgId: _orgId),
    _EmpSalary(empData: _empData, orgId: _orgId),
    _EmpNotifications(orgId: _orgId, empId: _empId),
    _EmpAllEmployees(orgId: _orgId, currentEmpId: _empId),
    _EmpProfile(empData: _empData),
  ];

  @override
  Widget build(BuildContext context) {
    final name = (_empData?['name'] as String? ?? 'Employee').split(' ').first;
    final orgDisplayName = (_orgId == 'ren_tracker' || _orgId == 'renish_electronics') ? 'Ren Tracker' : _orgId;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hi, $name 👋',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text(orgDisplayName,
                    style: const TextStyle(fontSize: 10, color: Colors.white70)),
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
            child: const Row(
              children: [
                Icon(Icons.badge, color: Colors.white, size: 13),
                SizedBox(width: 4),
                Text('EMPLOYEE',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (val) async {
              if (val == 'logout') {
                await AuthService().signOut();
                if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, size: 18, color: Colors.red),
                  SizedBox(width: 8), Text('Sign Out')
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
        indicatorColor: const Color(0xFF16a34a).withOpacity(0.12),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: 'Attendance'),
          NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments),
              label: 'Salary'),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: 'Notices'),
          NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Team'),
          NavigationDestination(
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  TAB 1: DASHBOARD
// ─────────────────────────────────────────────────────────
class _EmpDashboard extends StatefulWidget {
  final Map<String, dynamic>? empData;
  final String orgId;
  const _EmpDashboard({this.empData, required this.orgId});
  @override
  State<_EmpDashboard> createState() => _EmpDashboardState();
}

class _EmpDashboardState extends State<_EmpDashboard> {
  late FirestoreService _fs;
  bool _loading = true;
  int _present = 0, _absent = 0, _half = 0;
  List<Map<String, dynamic>> _notifs = [];

  @override
  void initState() {
    super.initState();
    _fs = FirestoreService(orgId: widget.orgId);
    _load();
  }

  Future<void> _load() async {
    if (widget.empData == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final empId = widget.empData!['id'] as String;
    final now = DateTime.now();
    final from = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
    final to = DateFormat('yyyy-MM-dd').format(now);
    final records = await _fs.getEmployeeAttendanceRange(empId, from, to);
    final notifs = await _fs.getNotifications(limit: 3);
    int p = 0, a = 0, h = 0;
    for (final r in records) {
      if (r['status'] == 'present') p++;
      else if (r['status'] == 'absent') a++;
      else if (r['status'] == 'half_day') h++;
    }
    if (mounted) {
      setState(() {
        _present = p;
        _absent = a;
        _half = h;
        _notifs = notifs;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final name = widget.empData?['name'] as String? ?? 'Employee';
    final dept = widget.empData?['department'] as String? ?? '';
    final pos = widget.empData?['position'] as String? ?? '';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF16a34a)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      Text('$dept • $pos',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text("📅 This Month's Attendance",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1e3a8a))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _StatBox(
                      'Present', '$_present', const Color(0xFF16a34a), Icons.check_circle)),
              const SizedBox(width: 10),
              Expanded(
                  child: _StatBox('Absent', '$_absent', const Color(0xFFdc2626), Icons.cancel)),
              const SizedBox(width: 10),
              Expanded(
                  child: _StatBox(
                      'Half Day', '$_half', const Color(0xFFd97706), Icons.timelapse)),
            ],
          ),
          const SizedBox(height: 20),
          const Text('🔔 Recent Notices',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1e3a8a))),
          const SizedBox(height: 10),
          ..._notifs.map((n) {
            final ts = n['date'] as Timestamp?;
            final dt = ts != null ? DateFormat('MMM d').format(ts.toDate()) : '';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                leading: const Text('🔔', style: TextStyle(fontSize: 20)),
                title: Text(n['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(n['message'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11)),
                trailing: Text(dt, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            );
          }),
          if (_notifs.isEmpty)
            const Text('No notifications yet.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatBox(this.label, this.value, this.color, this.icon);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  TAB 2: MY ATTENDANCE & CORRECTION REQUESTS
// ─────────────────────────────────────────────────────────
class _EmpAttendance extends StatefulWidget {
  final Map<String, dynamic>? empData;
  final String orgId;
  const _EmpAttendance({this.empData, required this.orgId});
  @override
  State<_EmpAttendance> createState() => _EmpAttendanceState();
}

class _EmpAttendanceState extends State<_EmpAttendance> {
  late FirestoreService _fs;
  bool _loading = true;
  List<Map<String, dynamic>> _records = [];
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    _fs = FirestoreService(orgId: widget.orgId);
    _load();
  }

  Future<void> _load() async {
    if (widget.empData == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final empId = widget.empData!['id'] as String;
    final from = DateFormat('yyyy-MM-dd').format(_month);
    final lastDay = DateTime(_month.year, _month.month + 1, 0);
    final to = DateFormat('yyyy-MM-dd').format(
        lastDay.isAfter(DateTime.now()) ? DateTime.now() : lastDay);
    final records = await _fs.getEmployeeAttendanceRange(empId, from, to);
    if (mounted) {
      setState(() {
        _records = records;
        _loading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
    _load();
  }

  void _showCorrectionDialog(String dateStr, String? currentStatus) {
    String requestedStatus = currentStatus == 'present' ? 'half_day' : 'present';
    final reasonCtrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Request Correction', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: $dateStr', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Current Status: ${currentStatus ?? 'Not Marked'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: requestedStatus,
                decoration: const InputDecoration(labelText: 'Change to Status'),
                items: const [
                  DropdownMenuItem(value: 'present', child: Text('Present')),
                  DropdownMenuItem(value: 'half_day', child: Text('Half Day')),
                  DropdownMenuItem(value: 'absent', child: Text('Absent / Leave')),
                ],
                onChanged: (v) => setDialog(() => requestedStatus = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason for correction',
                  hintText: 'e.g. Missed biometric, approved leave',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (reasonCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please state a reason')),
                        );
                        return;
                      }
                      setDialog(() => submitting = true);
                      await _fs.submitCorrectionRequest(
                        empId: widget.empData!['id'],
                        empName: widget.empData!['name'] ?? '',
                        dateStr: dateStr,
                        requestedStatus: requestedStatus,
                        reason: reasonCtrl.text.trim(),
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Correction request submitted to admin for review.'),
                            backgroundColor: Color(0xFF16a34a),
                          ),
                        );
                      }
                    },
              child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  Color _color(String? s) => s == 'present'
      ? const Color(0xFF16a34a)
      : s == 'absent'
          ? const Color(0xFFdc2626)
          : s == 'half_day'
              ? const Color(0xFFd97706)
              : Colors.grey.shade300;

  String _emoji(String? s) =>
      s == 'present' ? '✅' : s == 'absent' ? '❌' : s == 'half_day' ? '🌓' : '—';

  @override
  Widget build(BuildContext context) {
    final p = _records.where((r) => r['status'] == 'present').length;
    final a = _records.where((r) => r['status'] == 'absent').length;
    final h = _records.where((r) => r['status'] == 'half_day').length;

    return Column(
      children: [
        // Month nav
        Container(
          color: const Color(0xFF1e3a8a),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () => _changeMonth(-1),
              ),
              Expanded(
                child: Text(DateFormat('MMMM yyyy').format(_month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: _month.month == DateTime.now().month &&
                        _month.year == DateTime.now().year
                    ? null
                    : () => _changeMonth(1),
              ),
            ],
          ),
        ),
        // Summary
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MiniStat('Present', '$p', const Color(0xFF16a34a)),
              _MiniStat('Absent', '$a', const Color(0xFFdc2626)),
              _MiniStat('Half Day', '$h', const Color(0xFFd97706)),
            ],
          ),
        ),
        const Divider(height: 1),
        _loading
            ? const Expanded(child: Center(child: CircularProgressIndicator()))
            : Expanded(
                child: ListView.separated(
                  itemCount: _records.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final r = _records[i];
                    final dateStr = r['date'] as String;
                    final dt = DateFormat('EEE, MMM d')
                        .format(DateFormat('yyyy-MM-dd').parse(dateStr));
                    final s = r['status'] as String?;
                    return ListTile(
                      dense: true,
                      onTap: () => _showCorrectionDialog(dateStr, s),
                      leading: Text(_emoji(s), style: const TextStyle(fontSize: 20)),
                      title: Text(dt, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: const Text('Tap to request correction',
                          style: TextStyle(fontSize: 10, color: Colors.grey)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _color(s).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _color(s).withOpacity(0.3)),
                        ),
                        child: Text(
                          s == 'present'
                              ? 'Present'
                              : s == 'absent'
                                  ? 'Absent'
                                  : s == 'half_day'
                                      ? 'Half Day'
                                      : 'No Record',
                          style: TextStyle(
                              color: _color(s), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  TAB 3: MY SALARY (read-only, personal estimate)
// ─────────────────────────────────────────────────────────
class _EmpSalary extends StatefulWidget {
  final Map<String, dynamic>? empData;
  final String orgId;
  const _EmpSalary({this.empData, required this.orgId});
  @override
  State<_EmpSalary> createState() => _EmpSalaryState();
}

class _EmpSalaryState extends State<_EmpSalary> {
  late FirestoreService _fs;
  bool _loading = false;
  double? _earned;
  int _present = 0, _absent = 0, _half = 0;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  String _currencySymbol = '₹';

  @override
  void initState() {
    super.initState();
    _fs = FirestoreService(orgId: widget.orgId);
    _fs.getOrganization().then((org) {
      if (mounted) setState(() => _currencySymbol = org.currencySymbol);
    });
  }

  Future<void> _calculate() async {
    if (widget.empData == null) return;
    setState(() => _loading = true);
    final empId = widget.empData!['id'] as String;
    final from = DateFormat('yyyy-MM-dd').format(_from);
    final to = DateFormat('yyyy-MM-dd').format(_to);
    final records = await _fs.getEmployeeAttendanceRange(empId, from, to);
    int p = 0, a = 0, h = 0;
    for (final r in records) {
      if (r['status'] == 'present') p++;
      else if (r['status'] == 'absent') a++;
      else if (r['status'] == 'half_day') h++;
    }
    final sal = (widget.empData!['salary'] as num?)?.toDouble() ?? 0.0;
    final type = widget.empData!['salaryType'] as String? ?? 'monthly';
    final eff = p + h * 0.5;
    double earned;
    if (type == 'daily') {
      earned = sal * eff;
    } else if (type == 'weekly') {
      earned = (sal / 7) * eff;
    } else {
      earned = (sal / 26) * eff;
    }

    if (mounted) {
      setState(() {
        _present = p;
        _absent = a;
        _half = h;
        _earned = earned;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseSal = (widget.empData?['salary'] as num?)?.toDouble() ?? 0.0;
    final salType = widget.empData?['salaryType'] as String? ?? 'monthly';
    final fmt = DateFormat('MMM d');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1e3a8a), Color(0xFF1d4ed8)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('My Base Salary',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('$_currencySymbol${baseSal.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                    Text(salType.toUpperCase(),
                        style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                      initialDateRange: DateTimeRange(start: _from, end: _to),
                    );
                    if (range != null) {
                      setState(() {
                        _from = range.start;
                        _to = range.end;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('${fmt.format(_from)} → ${fmt.format(_to)}',
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _loading ? null : _calculate,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Calculate'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_earned != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16a34a).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF16a34a).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text('Estimated Earned Salary',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text('$_currencySymbol${_earned!.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF16a34a))),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SalBadge('$_present Present', const Color(0xFF16a34a)),
                      _SalBadge('$_absent Absent', const Color(0xFFdc2626)),
                      _SalBadge('$_half Half', const Color(0xFFd97706)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('* This is an automated estimate based on verified attendance.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _SalBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _SalBadge(this.text, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  TAB 4: NOTIFICATIONS (Filtered by All Staff or Target Employee)
// ─────────────────────────────────────────────────────────
class _EmpNotifications extends StatelessWidget {
  final String orgId;
  final String? empId;
  const _EmpNotifications({required this.orgId, this.empId});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService(orgId: orgId);
    final cleanMyEmpId = (empId ?? '').trim().toLowerCase();

    return StreamBuilder<QuerySnapshot>(
      stream: fs.notificationsStream(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final allDocs = snap.data?.docs ?? [];
        final docs = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final target = (data['target'] as String? ?? 'all').trim().toLowerCase();
          final targetEmpId = (data['targetEmpId'] as String? ?? '').trim().toLowerCase();
          if (target == 'all' || target == 'employees') return true;
          if (cleanMyEmpId.isNotEmpty) {
            return target == cleanMyEmpId || targetEmpId == cleanMyEmpId;
          }
          return false;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('No notifications yet', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.separated(
          key: const PageStorageKey('emp_notifications_history_list'),
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['date'] as Timestamp?;
            final dt = ts != null
                ? DateFormat('MMM d, yyyy  h:mm a').format(ts.toDate())
                : '';
            final target = (data['target'] as String? ?? 'all').trim().toLowerCase();
            final isPersonal = target != 'all' && target != 'employees';

            return KeyedSubtree(
              key: ValueKey(doc.id),
              child: Card(
                elevation: isPersonal ? 3 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: isPersonal
                      ? const BorderSide(color: Color(0xFFF59E0B), width: 1.5)
                      : BorderSide.none,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPersonal
                          ? const Color(0xFFF59E0B).withOpacity(0.15)
                          : const Color(0xFF1e3a8a).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPersonal ? Icons.person_pin : Icons.campaign,
                      color: isPersonal ? const Color(0xFFB45309) : const Color(0xFF1e3a8a),
                      size: 22,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(data['title'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPersonal ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isPersonal ? const Color(0xFFFCD34D) : const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: Text(
                          isPersonal ? '🎯 DIRECT FOR YOU' : '📢 ALL STAFF',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isPersonal ? const Color(0xFFB45309) : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(data['message'] ?? '',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(dt, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          const Spacer(),
                          Text('By: ${data['sentBy'] ?? 'Admin'}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
//  TAB 5: TEAM MEMBERS (Colleague Directory & Search)
// ─────────────────────────────────────────────────────────
class _EmpAllEmployees extends StatefulWidget {
  final String orgId;
  final String? currentEmpId;
  const _EmpAllEmployees({required this.orgId, this.currentEmpId});

  @override
  State<_EmpAllEmployees> createState() => _EmpAllEmployeesState();
}

class _EmpAllEmployeesState extends State<_EmpAllEmployees> {
  String _searchQuery = '';
  late Future<List<Map<String, dynamic>>> _employeesFuture;

  @override
  void initState() {
    super.initState();
    _employeesFuture = FirestoreService(orgId: widget.orgId).getEmployees();
  }

  @override
  void didUpdateWidget(_EmpAllEmployees oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orgId != widget.orgId) {
      _employeesFuture = FirestoreService(orgId: widget.orgId).getEmployees();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _employeesFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final allDocs = snap.data ?? [];
        final docs = allDocs.where((emp) {
          final q = _searchQuery.toLowerCase();
          if (q.isEmpty) return true;
          final name = (emp['name'] as String? ?? '').toLowerCase();
          final dept = (emp['department'] as String? ?? '').toLowerCase();
          final pos = (emp['position'] as String? ?? '').toLowerCase();
          final id = (emp['id'] as String? ?? '').toLowerCase();
          return name.contains(q) || dept.contains(q) || pos.contains(q) || id.contains(q);
        }).toList();

        return Column(
          children: [
            // Search & stats bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people, color: Color(0xFF1e3a8a), size: 20),
                      const SizedBox(width: 8),
                      Text('${allDocs.length} Team Members',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1e3a8a))),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(widget.orgId,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search teammates by name, role or department...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      fillColor: const Color(0xFFF8FAFC),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (docs.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty ? 'No team members matching "$_searchQuery"' : 'No team members found',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Team members added by your administrator will appear here.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  key: const PageStorageKey('emp_all_employees_list'),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (ctx, i) {
                    final data = docs[i];
                    final name = data['name'] as String? ?? '';
                    final dept = data['department'] as String? ?? '';
                    final pos = data['position'] as String? ?? '';
                    final empId = data['id'] as String? ?? '';
                    final email = data['email'] as String? ?? '';
                    final isYou = widget.currentEmpId != null &&
                        widget.currentEmpId!.isNotEmpty &&
                        widget.currentEmpId == empId;

                    return KeyedSubtree(
                      key: ValueKey(empId.isNotEmpty ? empId : 'emp_$i'),
                      child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: CircleAvatar(
                        backgroundColor: isYou
                            ? const Color(0xFF16a34a).withValues(alpha: 0.15)
                            : const Color(0xFF1e3a8a).withValues(alpha: 0.1),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: isYou ? const Color(0xFF16a34a) : const Color(0xFF1e3a8a),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          if (isYou) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('You',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF166534))),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$dept • $pos', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                          if (email.isNotEmpty)
                            Text('✉️ $email', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          empId,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                      ),
                    ));
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
//  TAB 6: MY PROFILE
// ─────────────────────────────────────────────────────────
class _EmpProfile extends StatelessWidget {
  final Map<String, dynamic>? empData;
  const _EmpProfile({this.empData});

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1e3a8a), size: 20),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (empData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No employee profile linked to your account.',
                style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Contact admin to link your account.',
                style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final name = empData!['name'] as String? ?? '—';
    final id = empData!['id'] as String? ?? '—';
    final phone = empData!['phone'] as String? ?? '—';
    final dept = empData!['department'] as String? ?? '—';
    final pos = empData!['position'] as String? ?? '—';
    final sal = empData!['salary'];
    final type = empData!['salaryType'] as String? ?? 'monthly';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          CircleAvatar(
            radius: 42,
            backgroundColor: const Color(0xFF1e3a8a).withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontSize: 36, fontWeight: FontWeight.w800, color: Color(0xFF1e3a8a)),
            ),
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text('$dept • $pos', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  _row(Icons.badge, 'Employee ID', id),
                  const Divider(),
                  _row(Icons.phone, 'Mobile Number', phone),
                  const Divider(),
                  _row(Icons.business, 'Department', dept),
                  const Divider(),
                  _row(Icons.work, 'Position', pos),
                  const Divider(),
                  _row(Icons.payments, 'Base Salary', '${sal ?? '—'} / $type'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Ren Tracker · Multi-tenant SaaS',
              style: TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}

