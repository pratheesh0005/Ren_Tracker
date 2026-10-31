import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ren_tracker/core/constants/env_config.dart';
import 'package:ren_tracker/data/repositories/firestore_repository.dart';
import 'package:ren_tracker/core/services/onesignal_service.dart';

class AdminNotifications extends StatefulWidget {
  const AdminNotifications({super.key});
  @override
  State<AdminNotifications> createState() => _AdminNotificationsState();
}

class _AdminNotificationsState extends State<AdminNotifications> {
  FirestoreRepository _fs = FirestoreRepository();
  final _os = OneSignalService();
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();

  bool _sending = false;
  String _targetMode = 'all'; // 'all' | 'single'
  List<Map<String, dynamic>> _employees = [];
  Map<String, dynamic>? _selectedEmployee;
  bool _loadingEmployees = false;
  String? _restApiKey;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    final org = prefs.getString('org_id') ?? EnvConfig.defaultOrgId;
    final fs = FirestoreRepository(orgId: org);
    final key = await _os.getRestApiKey(org);

    setState(() {
      _fs = fs;
      _restApiKey = key;
      _loadingEmployees = true;
    });

    try {
      final emps = await fs.getEmployees();
      if (mounted) {
        setState(() {
          _employees = emps;
          if (emps.isNotEmpty) {
            _selectedEmployee = emps.first;
          }
          _loadingEmployees = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingEmployees = false);
    }
  }

  void _showApiKeyDialog() {
    final keyCtrl = TextEditingController(text: _restApiKey ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.key, color: Color(0xFF1e3a8a)),
            SizedBox(width: 8),
            Text('OneSignal Push Settings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your OneSignal REST API Key to deliver background system push notifications to devices.\n\nFound in your OneSignal Dashboard under:\nSettings > Keys & IDs > REST API Key',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(
                labelText: 'OneSignal REST API Key',
                hintText: 'os_v2_app_... or hex key',
                prefixIcon: Icon(Icons.security),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newKey = keyCtrl.text.trim();
              await _os.saveRestApiKey(_fs.orgId, newKey);
              setState(() => _restApiKey = newKey.isNotEmpty ? newKey : null);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ OneSignal REST API Key saved!'),
                    backgroundColor: Color(0xFF16a34a),
                  ),
                );
              }
            },
            child: const Text('Save Key'),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final msg = _msgCtrl.text.trim();
    if (title.isEmpty || msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter announcement title and message body.'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (_targetMode == 'single') {
      if (_selectedEmployee == null && _employees.isNotEmpty) {
        _selectedEmployee = _employees.first;
      }
      final selEmpId = (_selectedEmployee?['id'] as String? ?? '').trim();
      if (selEmpId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an employee to notify.'),
              behavior: SnackBarBehavior.floating),
        );
        return;
      }
    }

    setState(() => _sending = true);
    try {
      final email = FirebaseAuth.instance.currentUser?.email ?? 'Admin';

      final isAll = _targetMode == 'all';
      final empId = isAll ? null : (_selectedEmployee?['id'] as String?)?.trim();
      final empName = isAll ? null : (_selectedEmployee?['name'] as String?)?.trim();
      final playerId = isAll ? null : (_selectedEmployee?['oneSignalPlayerId'] as String?)?.trim();

      // 1. Dispatch through OneSignal Service (Saves to Firestore and sends OneSignal Push)
      final result = await _os.sendTenantNotification(
        title: title,
        body: msg,
        orgId: _fs.orgId,
        adminEmail: email,
        target: isAll ? 'all' : (empId ?? 'single'),
        targetEmpId: empId,
        targetEmpName: empName,
        targetPlayerId: playerId,
        customRestApiKey: _restApiKey,
      );

      _titleCtrl.clear();
      _msgCtrl.clear();

      if (mounted) {
        if (result['pushed'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isAll
                  ? '🔔 Push notification broadcast to All Staff in ${_fs.orgId}!'
                  : '🔔 Personal push notification delivered to $empName ($empId)!'),
              backgroundColor: const Color(0xFF16a34a),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          final pushErr = result['pushError'] as String?;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(pushErr != null && pushErr.contains('REST API Key not configured')
                  ? '✅ Notice posted to stream. (Tip: Tap "OneSignal Setup" to enable real-time background push)'
                  : '✅ Notice posted to stream!'),
              backgroundColor: const Color(0xFF1e3a8a),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  void _confirmDelete(String notifId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Announcement?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Remove "$title" from the notification history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFdc2626)),
            onPressed: () async {
              await _fs.deleteNotification(notifId);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Announcement removed.')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openEmployeePickerModal(List<Map<String, dynamic>> empList) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = empList.where((e) {
              final name = (e['name'] as String? ?? '').toLowerCase();
              final id = (e['id'] as String? ?? '').toLowerCase();
              final dept = (e['department'] as String? ?? '').toLowerCase();
              final q = searchQuery.toLowerCase();
              return name.contains(q) || id.contains(q) || dept.contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.7,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person_pin, color: Color(0xFF1e3a8a)),
                      const SizedBox(width: 8),
                      const Text(
                        'Select Recipient Employee',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by employee name or ID...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => setModalState(() => searchQuery = val),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('No employees found', style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final emp = filtered[i];
                              final id = (emp['id'] as String? ?? '').trim();
                              final name = emp['name'] as String? ?? 'Employee';
                              final dept = emp['department'] as String? ?? '';
                              final hasPlayer = emp['oneSignalPlayerId'] != null &&
                                  (emp['oneSignalPlayerId'] as String).isNotEmpty;
                              final isSelected = _selectedEmployee?['id'] == id;

                              return ListTile(
                                onTap: () {
                                  setState(() {
                                    _selectedEmployee = emp;
                                  });
                                  Navigator.pop(ctx);
                                },
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF1e3a8a).withOpacity(0.1),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: Color(0xFF1e3a8a),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? const Color(0xFF1e3a8a) : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (hasPlayer)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          '📱 Push Active',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Color(0xFF047857),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  dept.isNotEmpty ? 'ID: $id • $dept' : 'ID: $id',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: Color(0xFF16a34a))
                                    : null,
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = _restApiKey != null && _restApiKey!.isNotEmpty;

    // Deduplicate and sanitize employees
    final uniqueMap = <String, Map<String, dynamic>>{};
    for (final e in _employees) {
      final id = (e['id'] as String? ?? '').trim();
      if (id.isNotEmpty && !uniqueMap.containsKey(id)) {
        uniqueMap[id] = e;
      }
    }
    final empList = uniqueMap.values.toList();
    if (_selectedEmployee == null && empList.isNotEmpty) {
      _selectedEmployee = empList.first;
    }

    return Scaffold(
      body: CustomScrollView(
        key: const PageStorageKey('admin_notifications_scroll_view'),
        slivers: [
          // 1. Compose section
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('📢 Send Announcement',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1e3a8a))),
                      ),
                      InkWell(
                        onTap: _showApiKeyDialog,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: hasKey ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: hasKey ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.key, size: 12, color: hasKey ? const Color(0xFF047857) : const Color(0xFFB45309)),
                              const SizedBox(width: 4),
                              Text(
                                hasKey ? 'Push Active' : 'OneSignal Setup',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: hasKey ? const Color(0xFF047857) : const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Recipient Selector: All Staff vs Separate Employee
                  KeyedSubtree(
                    key: const ValueKey('admin_notif_target_toggle_subtree'),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _targetMode = 'all'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _targetMode == 'all' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _targetMode == 'all'
                                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.campaign, size: 16, color: Color(0xFF1e3a8a)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'All Staff (Broadcast)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _targetMode == 'all' ? const Color(0xFF1e3a8a) : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _targetMode = 'single'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _targetMode == 'single' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _targetMode == 'single'
                                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.person, size: 16, color: Color(0xFF1e3a8a)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Specific Employee',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _targetMode == 'single' ? const Color(0xFF1e3a8a) : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Specific Employee Picker Box (Tap to search & select)
                  if (_targetMode == 'single') ...[
                    KeyedSubtree(
                      key: const ValueKey('specific_employee_picker_box'),
                      child: _loadingEmployees
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                            )
                          : (empList.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text('No employees found in this organization.',
                                      style: TextStyle(color: Color(0xFF991B1B), fontSize: 12)),
                                )
                              : InkWell(
                                  onTap: () => _openEmployeePickerModal(empList),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1e3a8a).withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.person, color: Color(0xFF1e3a8a), size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Recipient Employee (Tap to change)',
                                                style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _selectedEmployee != null
                                                    ? '${_selectedEmployee!['name']} (${_selectedEmployee!['id']})'
                                                    : 'Tap to select an employee...',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: _selectedEmployee != null ? const Color(0xFF0F172A) : Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_selectedEmployee != null &&
                                            _selectedEmployee!['oneSignalPlayerId'] != null &&
                                            (_selectedEmployee!['oneSignalPlayerId'] as String).isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(right: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('📱 Push Active',
                                                style: TextStyle(fontSize: 9, color: Color(0xFF047857), fontWeight: FontWeight.w700)),
                                          ),
                                        const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                                      ],
                                    ),
                                  ),
                                )),
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    key: const ValueKey('compose_title_input'),
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Announcement Title',
                      hintText: 'e.g. Salary Credited / Shift Notice',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('compose_msg_input'),
                    controller: _msgCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Message Body',
                      hintText: 'Enter details for employee...',
                      prefixIcon: Icon(Icons.message),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    key: const ValueKey('compose_send_button'),
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send, color: Colors.white),
                    label: Text(
                      _sending
                          ? 'Broadcasting...'
                          : (_targetMode == 'all'
                              ? '🔔 Broadcast to All Staff'
                              : '🔔 Send to ${_selectedEmployee?['name'] ?? "Employee"}'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: Divider(height: 1)),

          // 2. History header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Text('📋 Notification History • ${_fs.orgId}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1e3a8a))),
                  const Spacer(),
                  const Text('Live Stream', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),

          // 3. History list
          StreamBuilder<QuerySnapshot>(
            stream: _fs.notificationsStream(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('No announcements dispatched yet.',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final doc = docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final ts = data['date'] as Timestamp?;
                      final dt = ts != null
                          ? DateFormat('MMM d, yyyy  h:mm a').format(ts.toDate())
                          : '';
                      final target = (data['target'] as String? ?? 'all').trim();
                      final targetEmpName = data['targetEmpName'] as String?;
                      final targetEmpId = data['targetEmpId'] as String?;
                      final isAll = target.toLowerCase() == 'all' || target.toLowerCase() == 'employees';

                      return KeyedSubtree(
                        key: ValueKey(doc.id),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isAll
                                      ? const Color(0xFF1e3a8a).withOpacity(0.1)
                                      : const Color(0xFFF59E0B).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isAll ? Icons.campaign : Icons.person,
                                  color: isAll ? const Color(0xFF1e3a8a) : const Color(0xFFB45309),
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
                                      color: isAll ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isAll ? const Color(0xFFBFDBFE) : const Color(0xFFFCD34D),
                                      ),
                                    ),
                                    child: Text(
                                      isAll ? '📢 ALL STAFF' : '👤 TO: ${targetEmpName ?? targetEmpId ?? target}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isAll ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Text(data['message'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(dt, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                        onPressed: () => _confirmDelete(doc.id, data['title'] ?? 'Notice'),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: docs.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

