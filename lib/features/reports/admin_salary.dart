import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ren_tracker/core/constants/env_config.dart';
import 'package:ren_tracker/data/repositories/firestore_repository.dart';

class AdminSalary extends StatefulWidget {
  const AdminSalary({super.key});
  @override
  State<AdminSalary> createState() => _AdminSalaryState();
}

class _AdminSalaryState extends State<AdminSalary> {
  FirestoreService _fs = FirestoreService();
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  bool _calculated = false;
  bool _committing = false;
  String _currencySymbol = '₹';
  String _currencyCode = 'INR';

  @override
  void initState() {
    super.initState();
    _initTenant();
  }

  Future<void> _initTenant() async {
    final prefs = await SharedPreferences.getInstance();
    final org = prefs.getString('org_id') ?? EnvConfig.defaultOrgId;
    final fs = FirestoreService(orgId: org);
    final orgModel = await fs.getOrganization();
    if (mounted) {
      setState(() {
        _fs = fs;
        _currencySymbol = orgModel.currencySymbol;
        _currencyCode = orgModel.currency;
      });
    }
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
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
        _from = range.start;
        _to = range.end;
      });
    }
  }

  Future<void> _calculate() async {
    setState(() {
      _loading = true;
      _calculated = false;
    });
    final from = DateFormat('yyyy-MM-dd').format(_from);
    final to = DateFormat('yyyy-MM-dd').format(_to);
    final results = await _fs.calculateSalary(from, to);
    results.sort((a, b) =>
        (a['name'] as String).compareTo(b['name'] as String));
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
        _calculated = true;
      });
    }
  }

  Future<void> _commitDisbursement() async {
    setState(() => _committing = true);
    final from = DateFormat('yyyy-MM-dd').format(_from);
    final to = DateFormat('yyyy-MM-dd').format(_to);
    await _fs.saveSalaryDisbursement(
      periodFrom: from,
      periodTo: to,
      salaryRows: _results,
    );
    setState(() => _committing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Monthly salary disbursement recorded & approved!'),
          backgroundColor: Color(0xFF16a34a),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    final totalPayable = _results.fold<double>(
        0, (sum, e) => sum + ((e['earnedSalary'] as double?) ?? 0));

    return Scaffold(
      body: Column(
        children: [
          // Date range selector
          Container(
            color: const Color(0xFF1e3a8a),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickRange,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Calculation Period',
                              style: TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text('${fmt.format(_from)} → ${fmt.format(_to)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFea580c),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: _loading ? null : _calculate,
                  icon: const Icon(Icons.calculate, color: Colors.white, size: 18),
                  label: const Text('Calculate',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),

          // Loading / empty / results
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Calculating salaries from attendance records...',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : !_calculated
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payments_outlined,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text('Select date range and tap Calculate',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Total payable banner
                          Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [Color(0xFF16a34a), Color(0xFF15803d)]),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_wallet,
                                    color: Colors.white, size: 28),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Net Payable ($_currencyCode)',
                                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    Text(
                                      '$_currencySymbol${totalPayable.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF16a34a),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: _committing ? null : _commitDisbursement,
                                  icon: const Icon(Icons.check_circle, size: 16),
                                  label: Text(_committing ? 'Saving...' : 'Approve & Save',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          ),

                          // Employee salary list
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _results.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final e = _results[i];
                                final p = e['presentDays'] as int;
                                final a = e['absentDays'] as int;
                                final h = e['halfDays'] as int;
                                final eff = e['effectiveDays'] as double;
                                final earned = e['earnedSalary'] as double;
                                final base = (e['salary'] as num?)?.toDouble() ?? 0;

                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor:
                                                  const Color(0xFF1e3a8a).withOpacity(0.1),
                                              child: Text(
                                                (e['name'] as String? ?? '?')[0].toUpperCase(),
                                                style: const TextStyle(
                                                    color: Color(0xFF1e3a8a),
                                                    fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(e['name'] ?? '',
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight.w700)),
                                                  Text('${e['department']} • ${e['id']}',
                                                      style: const TextStyle(
                                                          fontSize: 11, color: Colors.grey)),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text('$_currencySymbol${earned.toStringAsFixed(0)}',
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.w800,
                                                        color: Color(0xFF16a34a),
                                                        fontSize: 16)),
                                                Text('Base: $_currencySymbol${base.toStringAsFixed(0)} (${e['salaryType']})',
                                                    style: const TextStyle(
                                                        fontSize: 10, color: Colors.grey)),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            _AttBadge('$p P', const Color(0xFF16a34a)),
                                            const SizedBox(width: 6),
                                            _AttBadge('$a A', const Color(0xFFdc2626)),
                                            const SizedBox(width: 6),
                                            _AttBadge('$h H', const Color(0xFFd97706)),
                                            const Spacer(),
                                            Text('${eff.toStringAsFixed(1)} effective days',
                                                style: const TextStyle(
                                                    fontSize: 11, color: Colors.grey)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _AttBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _AttBadge(this.text, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

