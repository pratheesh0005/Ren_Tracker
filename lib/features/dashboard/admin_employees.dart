import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ren_tracker/core/constants/env_config.dart';
import 'package:ren_tracker/data/repositories/firestore_repository.dart';

class AdminEmployees extends StatefulWidget {
  const AdminEmployees({super.key});
  @override
  State<AdminEmployees> createState() => _AdminEmployeesState();
}

class _AdminEmployeesState extends State<AdminEmployees> {
  FirestoreRepository _fs = FirestoreRepository();
  String _search = '';
  String _currencySymbol = '₹';
  Future<List<Map<String, dynamic>>>? _employeesFuture;

  @override
  void initState() {
    super.initState();
    _initTenant();
  }

  Future<void> _initTenant() async {
    final prefs = await SharedPreferences.getInstance();
    final org = prefs.getString('org_id') ?? EnvConfig.defaultOrgId;
    final fs = FirestoreRepository(orgId: org);
    final orgModel = await fs.getOrganization();
    if (mounted) {
      setState(() {
        _fs = fs;
        _currencySymbol = orgModel.currencySymbol;
        _employeesFuture = fs.getEmployees();
      });
    }
  }

  void _reloadEmployees() {
    setState(() {
      _employeesFuture = _fs.getEmployees();
    });
  }

  void _showAddDialog() {
    final empIdCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'Emp@123');
    final phoneCtrl = TextEditingController();
    final deptCtrl = TextEditingController();
    final posCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();
    String salaryType = 'monthly';
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text('Add Employee',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1e3a8a))),
                      const Spacer(),
                      IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: _field(empIdCtrl, 'Employee ID', 'EMP001',
                            validator: (v) => v!.isEmpty ? 'Required' : null)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _field(nameCtrl, 'Full Name', 'Sam',
                            validator: (v) => v!.isEmpty ? 'Required' : null)),
                  ]),
                  const SizedBox(height: 12),
                  _field(emailCtrl, 'Employee Email (App Login)', 'employee@company.com',
                      keyboard: TextInputType.emailAddress,
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty && (!v.contains('@') || !v.contains('.'))) {
                          return 'Enter valid email address';
                        }
                        return null;
                      }),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Login Password',
                      hintText: 'Default: Emp@123',
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setModal(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _field(phoneCtrl, 'Phone Number', '+14155552671',
                      keyboard: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().length < 6) ? 'Enter valid phone number' : null),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _field(deptCtrl, 'Department', 'Engineering',
                            validator: (v) => v!.isEmpty ? 'Required' : null)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _field(posCtrl, 'Position', 'Specialist',
                            validator: (v) => v!.isEmpty ? 'Required' : null)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: _field(salaryCtrl, 'Salary ($_currencySymbol)', '15000',
                          keyboard: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Required' : null),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: salaryType,
                        decoration: InputDecoration(
                          labelText: 'Salary Type',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                          DropdownMenuItem(value: 'daily', child: Text('Daily')),
                          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
                        ],
                        onChanged: (v) => setModal(() => salaryType = v!),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModal(() => saving = true);
                            try {
                              await _fs.addEmployee(
                                empId: empIdCtrl.text.trim().toUpperCase(),
                                name: nameCtrl.text.trim(),
                                email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                                password: passCtrl.text.trim().isNotEmpty ? passCtrl.text.trim() : null,
                                phone: phoneCtrl.text.trim(),
                                department: deptCtrl.text.trim(),
                                position: posCtrl.text.trim(),
                                salaryType: salaryType,
                                salary: double.parse(salaryCtrl.text.trim()),
                              );
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                _reloadEmployees();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Employee added with app credentials!'),
                                    backgroundColor: Color(0xFF16a34a),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              setModal(() => saving = false);
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Add Employee',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCredentialsDialog(String empId, String name, String currentEmail) {
    final emailCtrl = TextEditingController(text: currentEmail);
    final passCtrl = TextEditingController(text: 'Emp@123');
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.key, color: Color(0xFF1e3a8a), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('App Login Credentials: $name',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1e3a8a))),
                      ),
                      IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Set the email and password for employee $empId to sign in.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  _field(emailCtrl, 'Employee Email', 'employee@company.com',
                      keyboard: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        if (!v.contains('@') || !v.contains('.')) return 'Enter valid email';
                        return null;
                      }),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Login Password',
                      hintText: 'Default: Emp@123',
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setModal(() => obscure = !obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModal(() => saving = true);
                            final result = await _fs.setEmployeeCredentials(
                              empId: empId,
                              email: emailCtrl.text.trim(),
                              password: passCtrl.text.trim(),
                            );
                            if (ctx.mounted) {
                              setModal(() => saving = false);
                              if (result.containsKey('error')) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(result['error']), backgroundColor: Colors.red),
                                );
                              } else {
                                Navigator.pop(ctx);
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✅ Login credentials set for $name!'),
                                    backgroundColor: const Color(0xFF16a34a),
                                  ),
                                );
                              }
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Save & Provision Login',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String empId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Employee?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Remove $name ($empId) from the system? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFdc2626)),
            onPressed: () async {
              await _fs.deleteEmployee(empId);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                _reloadEmployees();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('$name deleted'),
                    backgroundColor: const Color(0xFFdc2626),
                    behavior: SnackBarBehavior.floating));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search employee by name, department or ID...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _employeesFuture,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data ?? [];
                final filtered = docs.where((data) {
                  final name = (data['name'] as String? ?? '').toLowerCase();
                  final dept = (data['department'] as String? ?? '').toLowerCase();
                  final id = (data['id'] as String? ?? '').toLowerCase();
                  return name.contains(_search) || dept.contains(_search) || id.contains(_search);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('No employees found', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  key: const PageStorageKey('admin_employees_list'),
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (ctx, i) {
                    final data = filtered[i];
                    final id = data['id'] as String? ?? '';
                    final name = data['name'] as String? ?? '';
                    final email = data['email'] as String? ?? '';
                    final dept = data['department'] as String? ?? '';
                    final pos = data['position'] as String? ?? '';
                    final sal = data['salary'];
                    final type = data['salaryType'] as String? ?? 'monthly';
                    final phone = data['phone'] as String? ?? '—';

                    return KeyedSubtree(
                      key: ValueKey(id.isNotEmpty ? id : 'emp_$i'),
                      child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1e3a8a).withOpacity(0.1),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: Color(0xFF1e3a8a), fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$dept • $pos', style: const TextStyle(fontSize: 11)),
                          Text(
                            '${email.isNotEmpty ? "✉️ $email • " : ""}📱 $phone • ID: $id',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$_currencySymbol${sal ?? '—'}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF16a34a),
                                      fontSize: 13)),
                              Text(type,
                                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.key_outlined,
                                color: Color(0xFF1e3a8a), size: 20),
                            tooltip: 'Login Credentials',
                            onPressed: () => _showCredentialsDialog(id, name, email),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Color(0xFFdc2626), size: 20),
                            onPressed: () => _confirmDelete(context, id, name),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ));
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF1e3a8a),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Employee',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

