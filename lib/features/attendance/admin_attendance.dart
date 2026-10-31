import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:ren_tracker/core/constants/env_config.dart';
import 'package:ren_tracker/data/repositories/firestore_repository.dart';

class AdminAttendance extends StatefulWidget {
  const AdminAttendance({super.key});
  @override
  State<AdminAttendance> createState() => _AdminAttendanceState();
}

class _AdminAttendanceState extends State<AdminAttendance>
    with SingleTickerProviderStateMixin {
  FirestoreRepository _fs = FirestoreRepository();
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _employees = [];
  Map<String, String> _attendance = {};
  bool _loading = true;
  bool _saving = false;
  late TabController _tab;

  // Monthly Compute State
  DateTime _monthFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _monthTo = DateTime.now();
  List<Map<String, dynamic>> _monthlyResults = [];
  bool _monthlyLoading = false;
  bool _monthlyComputed = false;
  String _monthlySearch = '';
  String _orgName = 'Ren Tracker';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      if (mounted) setState(() {});
    });
    _initTenantAndLoad();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _initTenantAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final org = prefs.getString('org_id') ?? EnvConfig.defaultOrgId;
    final fs = FirestoreRepository(orgId: org);
    final orgModel = await fs.getOrganization();
    if (mounted) {
      setState(() {
        _fs = fs;
        _orgName = orgModel.name;
      });
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final emps = await _fs.getEmployees();
    final att = await _fs.getAttendanceForDate(dateStr);
    if (mounted) {
      setState(() {
        _employees = emps;
        _attendance = att;
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _selectedDate = picked;
      await _load();
    }
  }

  void _cycleStatus(String empId) {
    final current = _attendance[empId] ?? '';
    final next = current == ''
        ? 'present'
        : current == 'present'
            ? 'absent'
            : current == 'absent'
                ? 'half_day'
                : '';
    setState(() => _attendance[empId] = next);
  }

  void _setAll(String status) {
    setState(() {
      for (final e in _employees) {
        _attendance[e['id'] as String] = status;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final toSave = Map<String, String>.from(_attendance)
      ..removeWhere((_, v) => v.isEmpty);
    await _fs.saveAllAttendance(dateStr, toSave);
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Attendance saved & audit logged!'),
          backgroundColor: Color(0xFF16a34a),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ══════════════════════════════════════════════════════════
  //  MONTHLY COMPUTE & REPORTING LOGIC
  // ══════════════════════════════════════════════════════════

  Future<void> _pickMonthlyRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _monthFrom, end: _monthTo),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1e3a8a),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() {
        _monthFrom = range.start;
        _monthTo = range.end;
        _monthlyComputed = false;
      });
    }
  }

  Future<void> _computeMonthly() async {
    setState(() {
      _monthlyLoading = true;
      _monthlyComputed = false;
    });
    final from = DateFormat('yyyy-MM-dd').format(_monthFrom);
    final to = DateFormat('yyyy-MM-dd').format(_monthTo);
    final results = await _fs.computeMonthlyAttendance(from, to);
    if (mounted) {
      setState(() {
        _monthlyResults = results;
        _monthlyLoading = false;
        _monthlyComputed = true;
      });
    }
  }

  String _buildFormattedTextReport() {
    final fromStr = DateFormat('MMM d, yyyy').format(_monthFrom);
    final toStr = DateFormat('MMM d, yyyy').format(_monthTo);
    final totalEmps = _monthlyResults.length;
    final totalDays = _monthlyResults.isNotEmpty ? (_monthlyResults.first['totalDays'] as int) : 0;

    final buf = StringBuffer();
    buf.writeln('📋 MONTHLY ATTENDANCE REPORT — $_orgName');
    buf.writeln('📅 Period: $fromStr → $toStr ($totalDays Days)');
    buf.writeln('👥 Total Employees: $totalEmps');
    buf.writeln('══════════════════════════════════════════');
    buf.writeln();

    for (int i = 0; i < _monthlyResults.length; i++) {
      final e = _monthlyResults[i];
      final name = e['name'] as String? ?? 'Employee';
      final empId = e['empId'] as String? ?? '—';
      final phone = e['phone'] as String? ?? '—';
      final dept = e['department'] as String? ?? '—';
      final pos = e['position'] as String? ?? '—';
      final p = e['presentDays'];
      final a = e['absentDays'];
      final h = e['halfDays'];
      final eff = (e['effectiveDays'] as num).toDouble().toStringAsFixed(1);
      final rate = (e['attendanceRate'] as num).toDouble().toStringAsFixed(1);

      buf.writeln('${i + 1}. $name (ID: $empId)');
      buf.writeln('   📱 Mobile: $phone');
      buf.writeln('   🏢 Role: $dept • $pos');
      buf.writeln('   ✅ Present: $p | ❌ Absent: $a | ⏳ Half: $h');
      buf.writeln('   📊 Effective: $eff / $totalDays days ($rate%)');
      buf.writeln('──────────────────────────────────────────');
    }

    buf.writeln();
    buf.writeln('Generated securely via Ren Tracker SaaS Platform');
    return buf.toString();
  }

  String _buildCsvData() {
    final rows = <List<dynamic>>[
      [
        'Employee ID',
        'Full Name',
        'Phone Number',
        'Department',
        'Position',
        'Total Days',
        'Present Days',
        'Absent Days',
        'Half Days',
        'Unmarked Days',
        'Effective Days',
        'Attendance Rate (%)',
      ],
      ..._monthlyResults.map((e) => [
        e['empId'],
        e['name'],
        e['phone'],
        e['department'],
        e['position'],
        e['totalDays'],
        e['presentDays'],
        e['absentDays'],
        e['halfDays'],
        e['unmarkedDays'],
        (e['effectiveDays'] as num).toDouble().toStringAsFixed(1),
        (e['attendanceRate'] as num).toDouble().toStringAsFixed(1),
      ]),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  Future<String?> _saveCsvFile() async {
    try {
      final csvString = _buildCsvData();
      final from = DateFormat('yyyyMMdd').format(_monthFrom);
      final to = DateFormat('yyyyMMdd').format(_monthTo);
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'attendance_report_${from}_$to.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csvString);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  void _showShareOptionsModal() {
    final textReport = _buildFormattedTextReport();
    final csvData = _buildCsvData();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.share, color: Color(0xFF1e3a8a)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Share Attendance Details',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1e3a8a))),
                          Text('$_orgName • ${_monthlyResults.length} Employees',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Option 1: Copy Formatted Summary for WhatsApp/Email
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  tileColor: const Color(0xFFF8FAFC),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFDCFCE7),
                    child: Icon(Icons.chat_bubble_outline, color: Color(0xFF16A34A)),
                  ),
                  title: const Text('Copy Formatted Summary',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Ideal for WhatsApp, Slack, SMS or Email updates',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: const Icon(Icons.copy, size: 20, color: Color(0xFF1e3a8a)),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: textReport));
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📋 Formatted summary copied! Ready to paste into WhatsApp or Email.'),
                          backgroundColor: Color(0xFF16a34a),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),

                // Option 2: Copy CSV Data for Excel/Sheets
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  tileColor: const Color(0xFFF8FAFC),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFDBEAFE),
                    child: Icon(Icons.table_chart_outlined, color: Color(0xFF2563EB)),
                  ),
                  title: const Text('Copy Spreadsheet / CSV Data',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Paste directly into Microsoft Excel or Google Sheets',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: const Icon(Icons.copy, size: 20, color: Color(0xFF2563EB)),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: csvData));
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📊 CSV data copied! Paste directly into Excel or Google Sheets.'),
                          backgroundColor: Color(0xFF2563EB),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),

                // Option 3: Save CSV File to Device
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  tileColor: const Color(0xFFF8FAFC),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEF3C7),
                    child: Icon(Icons.download, color: Color(0xFFD97706)),
                  ),
                  title: const Text('Export .CSV File to Device',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Save file to your app documents directory',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: const Icon(Icons.save_alt, size: 20, color: Color(0xFFD97706)),
                  onTap: () async {
                    final path = await _saveCsvFile();
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(path != null ? '💾 CSV exported to: $path' : 'Failed to export CSV file'),
                          backgroundColor: path != null ? const Color(0xFF16a34a) : Colors.red,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Live Preview Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Preview of Generated Report:',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      Text(
                        textReport.length > 300 ? '${textReport.substring(0, 300)}...\n[Full report contains all employees]' : textReport,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _shareIndividualEmployee(Map<String, dynamic> e) {
    final fromStr = DateFormat('MMM d, yyyy').format(_monthFrom);
    final toStr = DateFormat('MMM d, yyyy').format(_monthTo);
    final name = e['name'] as String? ?? 'Employee';
    final empId = e['empId'] as String? ?? '—';
    final phone = e['phone'] as String? ?? '—';
    final dept = e['department'] as String? ?? '—';
    final pos = e['position'] as String? ?? '—';
    final p = e['presentDays'];
    final a = e['absentDays'];
    final h = e['halfDays'];
    final u = e['unmarkedDays'];
    final eff = (e['effectiveDays'] as num).toDouble().toStringAsFixed(1);
    final rate = (e['attendanceRate'] as num).toDouble().toStringAsFixed(1);
    final total = e['totalDays'];

    final slip = '''
🏢 $_orgName — ATTENDANCE SLIP
👤 Employee: $name
🆔 ID: $empId
📱 Mobile: $phone
🏢 Role: $dept • $pos
📅 Period: $fromStr → $toStr ($total calendar days)

✅ Present Days: $p
❌ Absent Days: $a
⏳ Half Days: $h
⚪ Unmarked Days: $u
📊 Effective Attendance: $eff / $total Days ($rate%)

Generated via Ren Tracker
''';

    Clipboard.setData(ClipboardData(text: slip));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 Attendance slip for $name copied to clipboard!'),
        backgroundColor: const Color(0xFF16a34a),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _statusColor(String s) => s == 'present'
      ? const Color(0xFF16a34a)
      : s == 'absent'
          ? const Color(0xFFdc2626)
          : s == 'half_day'
              ? const Color(0xFFd97706)
              : Colors.grey.shade300;

  String _statusFull(String s) => s == 'present'
      ? 'Present'
      : s == 'absent'
          ? 'Absent'
          : s == 'half_day'
              ? 'Half Day'
              : 'Not Marked';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tab,
            labelColor: const Color(0xFF1e3a8a),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF1e3a8a),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            tabs: const [
              Tab(text: '📅  Mark Daily'),
              Tab(text: '📊  Monthly Details'),
              Tab(text: '⏳  Requests'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildMarkAttendanceTab(),
          _buildMonthlyComputeTab(),
          _buildCorrectionRequestsTab(),
        ],
      ),
      floatingActionButton: _tab.index == 0
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              backgroundColor: const Color(0xFF1e3a8a),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(_saving ? 'Saving...' : 'Save Attendance',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : _tab.index == 1 && _monthlyComputed && _monthlyResults.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: _showShareOptionsModal,
                  backgroundColor: const Color(0xFFea580c),
                  icon: const Icon(Icons.share, color: Colors.white),
                  label: const Text('Share Report',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                )
              : null,
    );
  }

  Widget _buildMarkAttendanceTab() {
    final dateStr = DateFormat('EEE, MMM d, yyyy').format(_selectedDate);
    final p = _attendance.values.where((v) => v == 'present').length;
    final a = _attendance.values.where((v) => v == 'absent').length;
    final h = _attendance.values.where((v) => v == 'half_day').length;

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Date bar
              Container(
                color: const Color(0xFF1e3a8a),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(dateStr,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                    TextButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.edit_calendar, color: Colors.white70, size: 16),
                      label: const Text('Change Date',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ),
                  ],
                ),
              ),

              // Quick stats
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatChip('Present', '$p', const Color(0xFF16a34a)),
                    _StatChip('Absent', '$a', const Color(0xFFdc2626)),
                    _StatChip('Half', '$h', const Color(0xFFd97706)),
                    _StatChip('Unmarked', '${_employees.length - p - a - h}', Colors.grey),
                  ],
                ),
              ),

              // Quick set buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    const Text('Mark all:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 8),
                    _QuickBtn('Present', const Color(0xFF16a34a), () => _setAll('present')),
                    const SizedBox(width: 6),
                    _QuickBtn('Absent', const Color(0xFFdc2626), () => _setAll('absent')),
                    const SizedBox(width: 6),
                    _QuickBtn('Half', const Color(0xFFd97706), () => _setAll('half_day')),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Employee list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _employees.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final e = _employees[i];
                    final id = e['id'] as String;
                    final s = _attendance[id] ?? '';
                    return ListTile(
                      onTap: () => _cycleStatus(id),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1e3a8a).withOpacity(0.1),
                        child: Text(
                          (e['name'] as String? ?? '?')[0].toUpperCase(),
                          style: const TextStyle(
                              color: Color(0xFF1e3a8a), fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(e['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${e['department'] ?? ''} • ${e['id']}',
                          style: const TextStyle(fontSize: 11)),
                      trailing: GestureDetector(
                        onTap: () => _cycleStatus(id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _statusColor(s),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusFull(s),
                            style: TextStyle(
                              color: s.isEmpty ? Colors.black54 : Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
  }

  // ══════════════════════════════════════════════════════════
  //  TAB 2: MONTHLY ATTENDANCE DETAILS & SHARE
  // ══════════════════════════════════════════════════════════

  Widget _buildMonthlyComputeTab() {
    final fromStr = DateFormat('MMM d').format(_monthFrom);
    final toStr = DateFormat('MMM d, yyyy').format(_monthTo);

    final filtered = _monthlyResults.where((e) {
      if (_monthlySearch.isEmpty) return true;
      final q = _monthlySearch.toLowerCase();
      final name = (e['name'] as String? ?? '').toLowerCase();
      final id = (e['empId'] as String? ?? '').toLowerCase();
      final phone = (e['phone'] as String? ?? '').toLowerCase();
      final dept = (e['department'] as String? ?? '').toLowerCase();
      return name.contains(q) || id.contains(q) || phone.contains(q) || dept.contains(q);
    }).toList();

    int totalPresent = 0;
    int totalAbsent = 0;
    int totalHalf = 0;
    double avgRate = 0.0;
    if (_monthlyResults.isNotEmpty) {
      for (final r in _monthlyResults) {
        totalPresent += (r['presentDays'] as int);
        totalAbsent += (r['absentDays'] as int);
        totalHalf += (r['halfDays'] as int);
        avgRate += (r['attendanceRate'] as double);
      }
      avgRate = avgRate / _monthlyResults.length;
    }

    return Column(
      children: [
        // Date range banner & Compute Trigger
        Container(
          color: const Color(0xFF1e3a8a),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickMonthlyRange,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.date_range, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Calculation Period',
                                      style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  Text('$fromStr → $toStr',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                            const Icon(Icons.edit, color: Colors.white70, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFea580c),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _monthlyLoading ? null : _computeMonthly,
                    icon: _monthlyLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.flash_on, color: Colors.white, size: 18),
                    label: Text(_monthlyLoading ? 'Computing...' : 'Compute',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Summary KPI Banner
        if (_monthlyComputed && _monthlyResults.isNotEmpty) ...[
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip('Staff', '${_monthlyResults.length}', const Color(0xFF1e3a8a)),
                _StatChip('Present', '$totalPresent', const Color(0xFF16a34a)),
                _StatChip('Absent', '$totalAbsent', const Color(0xFFdc2626)),
                _StatChip('Half Day', '$totalHalf', const Color(0xFFd97706)),
                _StatChip('Avg Rate', '${avgRate.toStringAsFixed(1)}%', const Color(0xFF2563eb)),
              ],
            ),
          ),
          const Divider(height: 1),

          // Search Bar & Share Button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _monthlySearch = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search by employee name, ID, phone...',
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
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFFea580c)),
                  tooltip: 'Share Options',
                  onPressed: _showShareOptionsModal,
                  icon: const Icon(Icons.share, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ],

        // Content
        if (_monthlyLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (!_monthlyComputed)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 70, color: Colors.blue.shade200),
                  const SizedBox(height: 16),
                  const Text('Compute Monthly Attendance',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1e3a8a))),
                  const SizedBox(height: 6),
                  const Text(
                    'Select a period above and tap "Compute" to calculate\nverified attendance metrics with employee names, IDs and phone numbers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1e3a8a),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _computeMonthly,
                    icon: const Icon(Icons.flash_on, color: Colors.white),
                    label: const Text('Compute Details Now',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          )
        else if (filtered.isEmpty)
          const Expanded(
            child: Center(
              child: Text('No employees found matching search query.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              key: const PageStorageKey('admin_monthly_attendance_list'),
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 80),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final e = filtered[i];
                final name = e['name'] as String? ?? 'Employee';
                final empId = e['empId'] as String? ?? '';
                final phone = e['phone'] as String? ?? '—';
                final dept = e['department'] as String? ?? '—';
                final pos = e['position'] as String? ?? '—';
                final p = e['presentDays'] as int;
                final a = e['absentDays'] as int;
                final h = e['halfDays'] as int;
                final u = e['unmarkedDays'] as int;
                final eff = (e['effectiveDays'] as num).toDouble();
                final rate = (e['attendanceRate'] as num).toDouble();
                final total = e['totalDays'] as int;

                final rateColor = rate >= 85
                    ? const Color(0xFF16a34a)
                    : rate >= 70
                        ? const Color(0xFFd97706)
                        : const Color(0xFFdc2626);

                return KeyedSubtree(
                  key: ValueKey(empId.isNotEmpty ? empId : 'monthly_$i'),
                  child: Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFF1e3a8a).withOpacity(0.1),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                      color: Color(0xFF1e3a8a), fontWeight: FontWeight.w800, fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700, fontSize: 15)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(empId,
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF1D4ED8))),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text('$dept • $pos',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone, size: 12, color: Color(0xFF16A34A)),
                                        const SizedBox(width: 4),
                                        Text(phone,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF16A34A))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.share, size: 18, color: Color(0xFF1e3a8a)),
                                tooltip: 'Share Employee Slip',
                                onPressed: () => _shareIndividualEmployee(e),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (rate / 100).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(rateColor),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Metrics badges
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _BadgeChip('Present: $p', const Color(0xFF16a34a)),
                              _BadgeChip('Absent: $a', const Color(0xFFdc2626)),
                              _BadgeChip('Half: $h', const Color(0xFFd97706)),
                              if (u > 0) _BadgeChip('Unmarked: $u', Colors.grey),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: rateColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${eff.toStringAsFixed(1)}/$total (${rate.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    color: rateColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TAB 3: CORRECTION REQUESTS
  // ══════════════════════════════════════════════════════════

  Widget _buildCorrectionRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _fs.correctionRequestsStream(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade200),
                const SizedBox(height: 12),
                const Text('No attendance correction requests.',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.separated(
          key: const PageStorageKey('admin_correction_requests_list'),
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final name = data['empName'] ?? data['empId'];
            final date = data['dateStr'] ?? '';
            final req = data['requestedStatus'] ?? '';
            final reason = data['reason'] ?? 'No reason provided';
            final status = data['status'] ?? 'pending';
            final isPending = status == 'pending';

            return KeyedSubtree(
              key: ValueKey(doc.id),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF1e3a8a).withOpacity(0.1),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Color(0xFF1e3a8a), fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text('Date: $date • ID: ${data['empId']}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPending
                                  ? Colors.amber.shade100
                                  : status == 'approved'
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isPending
                                    ? Colors.amber.shade900
                                    : status == 'approved'
                                        ? Colors.green.shade900
                                        : Colors.red.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Requested Status: ${req.toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      Text('Reason: $reason', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      if (isPending) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFdc2626)),
                              onPressed: () async {
                                await _fs.reviewCorrectionRequest(
                                  requestId: doc.id,
                                  dateStr: date,
                                  empId: data['empId'],
                                  approvedStatus: req,
                                  approve: false,
                                );
                              },
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Reject'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16a34a)),
                              onPressed: () async {
                                await _fs.reviewCorrectionRequest(
                                  requestId: doc.id,
                                  dateStr: date,
                                  empId: data['empId'],
                                  approvedStatus: req,
                                  approve: true,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Correction approved & attendance updated!')),
                                );
                              },
                              icon: const Icon(Icons.check, size: 16, color: Colors.white),
                              label: const Text('Approve', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;
  const _BadgeChip(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickBtn(this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
