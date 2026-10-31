import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ren_tracker/core/constants/env_config.dart';
import 'package:ren_tracker/core/services/auth_service.dart';
import 'package:ren_tracker/data/repositories/firestore_repository.dart';

class SuperAdminHome extends StatefulWidget {
  const SuperAdminHome({super.key});

  @override
  State<SuperAdminHome> createState() => _SuperAdminHomeState();
}

class _SuperAdminHomeState extends State<SuperAdminHome> {
  int _selectedIndex = 0;
  final AuthService _auth = AuthService();

  final List<Widget> _screens = const [
    _SuperAdminDashboard(),
    _SuperAdminOrganizations(),
    _SuperAdminUsers(),
    _SuperAdminProfile(),
  ];

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
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ren Tracker',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text('Super Admin Console',
                    style: TextStyle(fontSize: 10, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.stars, color: Colors.white, size: 13),
                SizedBox(width: 4),
                Text('SUPER ADMIN',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
            tooltip: 'Sign Out',
            onPressed: () async {
              await _auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
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
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business),
            label: 'Organizations',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'All Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  TAB 1: SUPER ADMIN DASHBOARD / OVERVIEW
// ─────────────────────────────────────────────────────────
class _SuperAdminDashboard extends StatefulWidget {
  const _SuperAdminDashboard();

  @override
  State<_SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<_SuperAdminDashboard> {
  final AuthService _auth = AuthService();
  bool _loading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats = await _auth.getPlatformStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0f172a), Color(0xFF1e3a8a)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.security, color: Colors.amber, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'SaaS Platform Control',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Multi-tenant governance, organization orchestration, and account authority.',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('📊 Platform Metrics',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1e3a8a))),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _metricCard('Organizations', '${_stats['totalOrgs'] ?? 0}',
                  const Color(0xFF2563eb), Icons.domain),
              _metricCard('Total Users', '${_stats['totalUsers'] ?? 0}',
                  const Color(0xFF059669), Icons.people_alt),
              _metricCard('Org Admins', '${_stats['admins'] ?? 0}',
                  const Color(0xFFd97706), Icons.shield),
              _metricCard('Employees', '${_stats['employees'] ?? 0}',
                  const Color(0xFF7c3aed), Icons.badge),
            ],
          ),
          const SizedBox(height: 24),
          const Text('⚡ Platform Health & Status',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1e3a8a))),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _healthRow(Icons.check_circle, 'Firestore Database', 'Online (asia-south1)', Colors.green),
                  const Divider(),
                  _healthRow(Icons.verified_user, 'Custom Claims Engine', 'Enabled', Colors.blue),
                  const Divider(),
                  _healthRow(Icons.notifications_active, 'Push Service', 'Configured', Colors.orange),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(count,
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, color: color)),
                Text(title,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _healthRow(IconData icon, String title, String subtitle, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const Spacer(),
        Text(subtitle, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  TAB 2: ORGANIZATIONS MANAGEMENT
// ─────────────────────────────────────────────────────────
class _SuperAdminOrganizations extends StatefulWidget {
  const _SuperAdminOrganizations();

  @override
  State<_SuperAdminOrganizations> createState() => _SuperAdminOrganizationsState();
}

class _SuperAdminOrganizationsState extends State<_SuperAdminOrganizations> {
  final AuthService _auth = AuthService();

  void _showCreateOrgModal() {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'Admin@123');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                      const Text('Create Organization',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1e3a8a))),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: idCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Organization ID',
                      hintText: 'e.g. acme_corp',
                      prefixIcon: Icon(Icons.key),
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Organization Name',
                      hintText: 'e.g. Acme Corporation',
                      prefixIcon: Icon(Icons.business),
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Primary Admin Email',
                      hintText: 'admin@acme.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) => v!.trim().isEmpty || !v.contains('@')
                        ? 'Enter valid email'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Initial Admin Password',
                      hintText: 'Default: Admin@123',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => (v == null || v.trim().length < 6)
                        ? 'Minimum 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModal(() => saving = true);
                            try {
                              await _auth.createOrganization(
                                orgId: idCtrl.text.trim(),
                                name: nameCtrl.text.trim(),
                                adminEmail: emailCtrl.text.trim(),
                                adminPassword: passCtrl.text.trim(),
                              );
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Organization & Admin created!'),
                                    backgroundColor: Color(0xFF16a34a),
                                  ),
                                );
                              }
                            } catch (e) {
                              setModal(() => saving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Provision Organization & Admin',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('organizations').snapshots(),
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
                  Icon(Icons.business_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('No organizations found', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _showCreateOrgModal,
                    icon: const Icon(Icons.add),
                    label: const Text('Provision First Organization'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] as String? ?? doc.id;
              final adminEmail = data['adminEmail'] as String? ?? '—';
              final status = data['status'] as String? ?? 'active';
              final currencySymbol = data['currencySymbol'] as String? ?? '₹';
              final isActive = status == 'active';

              return Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrganizationEmployeesScreen(
                          orgId: doc.id,
                          orgName: name,
                          adminEmail: adminEmail,
                          currencySymbol: currencySymbol,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF1e3a8a).withOpacity(0.1),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'O',
                                style: const TextStyle(
                                    color: Color(0xFF1e3a8a), fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text('Org ID: ${doc.id}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text('Admin: $adminEmail',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isActive ? Colors.green : Colors.red).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: (isActive ? Colors.green : Colors.red).withOpacity(0.3)),
                              ),
                              child: Text(
                                isActive ? 'ACTIVE' : 'SUSPENDED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isActive ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        const Row(
                          children: [
                            Icon(Icons.people_alt_outlined, size: 16, color: Color(0xFF1e3a8a)),
                            SizedBox(width: 6),
                            Text('Click to see all employees',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1e3a8a))),
                            Spacer(),
                            Icon(Icons.chevron_right, color: Color(0xFF1e3a8a), size: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateOrgModal,
        backgroundColor: const Color(0xFF1e3a8a),
        icon: const Icon(Icons.add_business, color: Colors.white),
        label: const Text('New Org',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  TAB 3: ALL PLATFORM USERS & SUSPENSION CONTROL
// ─────────────────────────────────────────────────────────
class _SuperAdminUsers extends StatefulWidget {
  const _SuperAdminUsers();

  @override
  State<_SuperAdminUsers> createState() => _SuperAdminUsersState();
}

class _SuperAdminUsersState extends State<_SuperAdminUsers> {
  final AuthService _auth = AuthService();
  String _search = '';

  void _showAddAdminModal() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'Admin@123');
    String? selectedOrgId;
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    final orgsFuture = _auth.getOrganizations();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                      const Icon(Icons.admin_panel_settings, color: Color(0xFF1e3a8a)),
                      const SizedBox(width: 8),
                      const Text('Add Organization Admin',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1e3a8a))),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Admin Full Name',
                      hintText: 'e.g. John Doe',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Admin Email',
                      hintText: 'e.g. admin@organization.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) => v!.trim().isEmpty || !v.contains('@')
                        ? 'Enter a valid email'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Initial Password',
                      hintText: 'Minimum 6 characters',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => (v == null || v.trim().length < 6)
                        ? 'Minimum 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: orgsFuture,
                    builder: (ctx, orgSnap) {
                      final orgs = orgSnap.data ?? [];
                      if (selectedOrgId == null && orgs.isNotEmpty) {
                        selectedOrgId = orgs.first['orgId'] as String? ?? orgs.first['id'] as String;
                      }
                      return DropdownButtonFormField<String>(
                        value: selectedOrgId,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Organization',
                          prefixIcon: Icon(Icons.business),
                        ),
                        items: orgs.map((o) {
                          final id = o['orgId'] as String? ?? o['id'] as String;
                          final name = o['name'] as String? ?? id;
                          return DropdownMenuItem(
                            value: id,
                            child: Text('$name ($id)'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setModal(() => selectedOrgId = val);
                        },
                        validator: (v) => v == null || v.isEmpty ? 'Select an organization' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModal(() => saving = true);
                            final err = await _auth.createAdminAccount(
                              name: nameCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                              password: passCtrl.text.trim(),
                              orgId: selectedOrgId ?? EnvConfig.defaultOrgId,
                            );
                            if (ctx.mounted) {
                              setModal(() => saving = false);
                              if (err == null) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✅ Admin account created for ${emailCtrl.text.trim()}!'),
                                    backgroundColor: const Color(0xFF16a34a),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Create Admin Account',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAdminModal,
        backgroundColor: const Color(0xFF1e3a8a),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Admin',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search user by email, name or ID...',
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final email = (data['email'] as String? ?? '').toLowerCase();
                  final name = (data['name'] as String? ?? '').toLowerCase();
                  final role = (data['role'] as String? ?? '').toLowerCase();
                  return email.contains(_search) || name.contains(_search) || role.contains(_search);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No users match search'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final doc = filtered[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final email = data['email'] as String? ?? 'No email';
                    final name = data['name'] as String? ?? 'Unnamed';
                    final role = data['role'] as String? ?? 'employee';
                    final orgId = data['orgId'] as String? ?? '—';
                    final isSuspended = (data['status'] as String? ?? '') == 'suspended';

                    final roleColor = role == 'super_admin'
                        ? Colors.amber.shade800
                        : (role == 'admin' ? const Color(0xFF1e3a8a) : Colors.teal);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        onTap: () {
                          if (orgId != '—' && orgId.trim().isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrganizationEmployeesScreen(
                                  orgId: orgId,
                                  orgName: '$name ($orgId)',
                                  adminEmail: email,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('User $name is a $role without an assigned organization.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: roleColor.withOpacity(0.1),
                          child: Icon(
                            role == 'super_admin'
                                ? Icons.stars
                                : (role == 'admin' ? Icons.shield : Icons.person),
                            color: roleColor,
                            size: 18,
                          ),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$email • Org: $orgId', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text('Role: ${role.toUpperCase()}',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: roleColor)),
                                if (orgId != '—' && orgId.trim().isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  const Text('• Click to see all employees',
                                      style: TextStyle(fontSize: 10, color: Color(0xFF1e3a8a), fontWeight: FontWeight.w700)),
                                ],
                              ],
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (role != 'super_admin')
                              IconButton(
                                icon: Icon(
                                  isSuspended ? Icons.block : Icons.check_circle_outline,
                                  color: isSuspended ? Colors.red : Colors.green,
                                ),
                                tooltip: isSuspended ? 'Unsuspend User' : 'Suspend User',
                                onPressed: () async {
                                  await _auth.toggleUserSuspension(
                                    uid: doc.id,
                                    suspend: !isSuspended,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isSuspended ? 'User unsuspended' : 'User suspended'),
                                    ),
                                  );
                                },
                              ),
                            if (orgId != '—' && orgId.trim().isNotEmpty)
                              const Icon(Icons.chevron_right, color: Color(0xFF1e3a8a), size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  TAB 4: SUPER ADMIN PROFILE
// ─────────────────────────────────────────────────────────
class _SuperAdminProfile extends StatelessWidget {
  const _SuperAdminProfile();

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final email = user?.email ?? '';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF1e3a8a).withOpacity(0.1),
            child: const Icon(Icons.stars, size: 40, color: Color(0xFF1e3a8a)),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            user?.displayName ?? 'Super Admin',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        Center(
          child: Text(email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ),
        const SizedBox(height: 28),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.badge, color: Color(0xFF1e3a8a)),
                title: const Text('Access Level'),
                subtitle: const Text('PLATFORM SUPER ADMIN (Global Privileges)'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.verified, color: Colors.green),
                title: const Text('Provisioning Status'),
                subtitle: const Text('Root Authority Provisioned'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFdc2626),
          ),
          onPressed: () async {
            await AuthService().signOut();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
          icon: const Icon(Icons.logout, color: Colors.white),
          label: const Text('Sign Out of Platform Console',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SUPER ADMIN: ORGANIZATION EMPLOYEES EXPLORER
// ══════════════════════════════════════════════════════════════

class OrganizationEmployeesScreen extends StatefulWidget {
  final String orgId;
  final String orgName;
  final String? adminEmail;
  final String? currencySymbol;

  const OrganizationEmployeesScreen({
    super.key,
    required this.orgId,
    required this.orgName,
    this.adminEmail,
    this.currencySymbol,
  });

  @override
  State<OrganizationEmployeesScreen> createState() => _OrganizationEmployeesScreenState();
}

class _OrganizationEmployeesScreenState extends State<OrganizationEmployeesScreen> {
  String _search = '';
  late final FirestoreService _fs;
  String _currency = '₹';

  @override
  void initState() {
    super.initState();
    _fs = FirestoreService(orgId: widget.orgId);
    _currency = widget.currencySymbol ?? '₹';
  }

  void _showAddEmployeeModal() {
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                      const Icon(Icons.person_add, color: Color(0xFF1e3a8a)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Add Employee to ${widget.orgName}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1e3a8a)),
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: empIdCtrl,
                          decoration: const InputDecoration(labelText: 'Employee ID', hintText: 'EMP001'),
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Full Name', hintText: 'John Doe'),
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Employee Email', hintText: 'employee@company.com'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Initial Password',
                      hintText: 'Default: Emp@123',
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setModal(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone Number', hintText: '+91 94895 22609'),
                    validator: (v) => (v == null || v.trim().length < 6) ? 'Enter valid phone number' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: deptCtrl,
                          decoration: const InputDecoration(labelText: 'Department', hintText: 'Engineering'),
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: posCtrl,
                          decoration: const InputDecoration(labelText: 'Position', hintText: 'Specialist'),
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: salaryCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: 'Salary ($_currency)', hintText: '15000'),
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: salaryType,
                          decoration: const InputDecoration(labelText: 'Salary Type'),
                          items: const [
                            DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                            DropdownMenuItem(value: 'daily', child: Text('Daily')),
                            DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
                            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                          ],
                          onChanged: (v) => setModal(() => salaryType = v!),
                        ),
                      ),
                    ],
                  ),
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
                                salary: double.tryParse(salaryCtrl.text.trim()) ?? 0.0,
                              );
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Employee added successfully!'),
                                    backgroundColor: Color(0xFF16a34a),
                                  ),
                                );
                              }
                            } catch (e) {
                              setModal(() => saving = false);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                          },
                    child: saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Add Employee', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(String empId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Employee?'),
        content: Text('Remove $name ($empId) from ${widget.orgName}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFdc2626)),
            onPressed: () async {
              await _fs.deleteEmployee(empId);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name deleted')));
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.orgName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text('Org ID: ${widget.orgId}${widget.adminEmail != null ? " • ${widget.adminEmail}" : ""}',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search employee by name, ID, phone, role...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('organizations')
                  .doc(widget.orgId)
                  .collection('employees')
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['name'] as String? ?? '').toLowerCase();
                  final id = (d.id).toLowerCase();
                  final phone = (data['phone'] as String? ?? '').toLowerCase();
                  final dept = (data['department'] as String? ?? '').toLowerCase();
                  final email = (data['email'] as String? ?? '').toLowerCase();
                  return name.contains(_search) ||
                      id.contains(_search) ||
                      phone.contains(_search) ||
                      dept.contains(_search) ||
                      email.contains(_search);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No employees in ${widget.orgName} yet',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey)),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _showAddEmployeeModal,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add First Employee'),
                        ),
                      ],
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return const Center(child: Text('No employees match search', style: TextStyle(color: Colors.grey)));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final doc = filtered[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final empId = doc.id;
                    final name = data['name'] as String? ?? 'Employee';
                    final phone = data['phone'] as String? ?? '—';
                    final email = data['email'] as String? ?? '';
                    final dept = data['department'] as String? ?? '—';
                    final pos = data['position'] as String? ?? '—';
                    final sal = data['salary'] ?? data['baseSalary'] ?? 0;
                    final salType = data['salaryType'] as String? ?? 'monthly';
                    final status = data['status'] as String? ?? 'active';
                    final isSuspended = status == 'suspended';

                    return Card(
                      elevation: 1,
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
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFdc2626), size: 20),
                                  tooltip: 'Delete Employee',
                                  onPressed: () => _confirmDelete(empId, name),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.phone, size: 13, color: Color(0xFF16A34A)),
                                const SizedBox(width: 4),
                                Text(phone, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                                if (email.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  const Icon(Icons.email, size: 13, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(email,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('$_currency$sal / $salType',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isSuspended ? Colors.red : Colors.green).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isSuspended ? 'SUSPENDED' : 'ACTIVE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isSuspended ? Colors.red : Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEmployeeModal,
        backgroundColor: const Color(0xFF1e3a8a),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Employee', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

