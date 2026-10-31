import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ren_tracker/core/constants/env_config.dart';
import 'package:ren_tracker/data/repositories/firestore_repository.dart';
import 'package:ren_tracker/shared/widgets/stat_card.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  FirestoreRepository _fs = FirestoreRepository();
  bool _loading = true;
  String? _errorMessage;
  int _total = 0, _present = 0, _absent = 0, _half = 0;
  String _orgName = 'Ren Tracker';
  String _orgId = EnvConfig.defaultOrgId;
  List<Map<String, dynamic>> _recentNotifs = [];
  List<Map<String, dynamic>> _todayList = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final org = prefs.getString('org_id') ?? EnvConfig.defaultOrgId;
      _fs = FirestoreRepository(orgId: org);
      final orgDetails = await _fs.getOrganizationDetails();

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final emps = await _fs.getEmployees();
      final att = await _fs.getAttendanceForDate(today);
      final notifs = await _fs.getNotifications(limit: 5);

      int p = 0, a = 0, h = 0;
      final todayList = <Map<String, dynamic>>[];
      for (final e in emps) {
        final s = att[e['id'] as String] ?? '';
        if (s == 'present') p++;
        else if (s == 'absent') a++;
        else if (s == 'half_day') h++;
        todayList.add({...e, 'status': s});
      }

      if (mounted) {
        setState(() {
          _orgId = org;
          _orgName = orgDetails['name'] as String? ?? 'Ren Tracker';
          _total = emps.length;
          _present = p;
          _absent = a;
          _half = h;
          _recentNotifs = notifs;
          _todayList = todayList;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load dashboard: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final rate = _total > 0
        ? ((_present + _half * 0.5) / _total * 100).toStringAsFixed(0)
        : '0';
    final todayStr = DateFormat('EEEE, MMM d').format(DateTime.now());

    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1e3a8a), Color(0xFF1d4ed8)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Good day, Admin! 👋',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text('$_orgName • $_orgId',
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text(todayStr,
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Stats grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,
                  children: [
                    StatCard(
                        label: 'Total Staff',
                        value: '$_total',
                        color: const Color(0xFF2563eb),
                        icon: Icons.people),
                    StatCard(
                        label: 'Present Today',
                        value: '$_present',
                        color: const Color(0xFF16a34a),
                        icon: Icons.check_circle),
                    StatCard(
                        label: 'Half Day',
                        value: '$_half',
                        color: const Color(0xFFd97706),
                        icon: Icons.timelapse),
                    StatCard(
                        label: 'Absent',
                        value: '$_absent',
                        color: const Color(0xFFdc2626),
                        icon: Icons.cancel),
                  ],
                ),
                const SizedBox(height: 8),

                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16a34a).withOpacity(.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF16a34a).withOpacity(.3)),
                    ),
                    child: Text('📊 Today\'s Attendance Rate: $rate%',
                        style: const TextStyle(
                            color: Color(0xFF16a34a), fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 16),

                // Pending Correction Requests Stream (Phase 6)
                StreamBuilder<QuerySnapshot>(
                  stream: _fs.correctionRequestsStream(),
                  builder: (ctx, snap) {
                    final docs = snap.data?.docs ?? [];
                    final pending = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'pending').toList();
                    if (pending.isEmpty) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.pending_actions, color: Colors.amber.shade900, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${pending.length} Pending Correction Requests',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Colors.amber.shade900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pending.length > 3 ? 3 : pending.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final d = pending[i];
                              final data = d.data() as Map<String, dynamic>;
                              final name = data['empName'] ?? data['empId'];
                              final date = data['dateStr'] ?? '';
                              final req = data['requestedStatus'] ?? '';
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text('$name requested "$req" for $date',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                subtitle: Text('Reason: ${data['reason'] ?? 'None'}',
                                    style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check, color: Colors.green, size: 20),
                                      onPressed: () async {
                                        await _fs.reviewCorrectionRequest(
                                          requestId: d.id,
                                          dateStr: date,
                                          empId: data['empId'],
                                          approvedStatus: req,
                                          approve: true,
                                        );
                                        _load();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                      onPressed: () async {
                                        await _fs.reviewCorrectionRequest(
                                          requestId: d.id,
                                          dateStr: date,
                                          empId: data['empId'],
                                          approvedStatus: req,
                                          approve: false,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Today's list
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("📋 Today's Staff Attendance",
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1e3a8a))),
                    Text('${_todayList.length} employees',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 10),
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _todayList.length > 8 ? 8 : _todayList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final e = _todayList[i];
                      final s = e['status'] as String? ?? '';
                      final color = s == 'present'
                          ? const Color(0xFF16a34a)
                          : s == 'absent'
                              ? const Color(0xFFdc2626)
                              : s == 'half_day'
                                  ? const Color(0xFFd97706)
                                  : Colors.grey;
                      final icon = s == 'present'
                          ? '✅'
                          : s == 'absent'
                              ? '❌'
                              : s == 'half_day'
                                  ? '🌓'
                                  : '➖';
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF1e3a8a).withOpacity(0.1),
                          child: Text(
                            (e['name'] as String? ?? '?')[0].toUpperCase(),
                            style: const TextStyle(
                                color: Color(0xFF1e3a8a),
                                fontWeight: FontWeight.w700,
                                fontSize: 12),
                          ),
                        ),
                        title: Text(e['name'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text(e['department'] ?? '—',
                            style: const TextStyle(fontSize: 11)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(icon,
                              style: TextStyle(color: color, fontSize: 14)),
                        ),
                      );
                    },
                  ),
                ),
                if (_todayList.length > 8)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('+${_todayList.length - 8} more',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center),
                  ),
                const SizedBox(height: 20),

                // Recent notifications
                const Text('🔔 Recent Organization Notices',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1e3a8a))),
                const SizedBox(height: 10),
                _recentNotifs.isEmpty
                    ? const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No notifications sent yet.',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center),
                        ),
                      )
                    : Card(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentNotifs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final n = _recentNotifs[i];
                            final ts = n['date'] as Timestamp?;
                            final dt = ts != null
                                ? DateFormat('MMM d, h:mm a').format(ts.toDate())
                                : '';
                            return ListTile(
                              dense: true,
                              leading: const Text('🔔', style: TextStyle(fontSize: 20)),
                              title: Text(n['title'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: Text(dt,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            );
                          },
                        ),
                      ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}

