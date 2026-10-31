import 'dart:async';
import 'package:flutter/material.dart';

import 'package:ren_tracker/core/services/auth_service.dart';
import 'package:ren_tracker/core/constants/countries_data.dart';
import 'package:ren_tracker/l10n/app_localizations.dart';
import 'package:ren_tracker/main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this, initialIndex: 1); // Start on Employee OTP
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _toggleLanguage() {
    final current = appLocaleNotifier.value.languageCode;
    final next = current == 'en' ? const Locale('ta') : const Locale('en');
    appLocaleNotifier.value = next;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLang = appLocaleNotifier.value.languageCode;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0f172a), Color(0xFF1e3a8a)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Language Switcher & Top Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.public, color: Colors.amber, size: 14),
                          SizedBox(width: 6),
                          Text('GLOBAL SAAS',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1)),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: _toggleLanguage,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            Text(currentLang == 'en' ? '🇮🇳 தமிழ்' : '🇺🇸 English',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // App Logo & Title
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3b82f6).withOpacity(0.5),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.bolt, color: Colors.white, size: 36),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(l10n.translate('app_title').toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              const SizedBox(height: 2),
              Text(l10n.translate('app_tagline'),
                  style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
              const SizedBox(height: 16),
              // 3-Way Portal Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      TabBar(
                        controller: _tab,
                        labelColor: const Color(0xFF1e3a8a),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFF1e3a8a),
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        tabs: const [
                          Tab(text: '🏢 Register'),
                          Tab(text: '👤 Employee'),
                          Tab(text: '🔐 Admin'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tab,
                          children: const [
                            _GlobalOrgRegistrationTab(),
                            _GlobalEmployeeLoginTab(),
                            _GlobalAdminLoginTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TAB 1: GLOBAL ORGANIZATION REGISTRATION
// ══════════════════════════════════════════════════════════════

class _GlobalOrgRegistrationTab extends StatefulWidget {
  const _GlobalOrgRegistrationTab();

  @override
  State<_GlobalOrgRegistrationTab> createState() => _GlobalOrgRegistrationTabState();
}

class _GlobalOrgRegistrationTabState extends State<_GlobalOrgRegistrationTab> {
  final _formKey = GlobalKey<FormState>();
  final _orgNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  CountryInfo _selectedCountry = CountriesData.defaultCountry;
  String _selectedBusinessType = 'Manufacturing & Engineering';
  bool _loading = false;
  bool _obscure = true;

  final List<String> _businessTypes = [
    'Manufacturing & Engineering',
    'Technology & IT Services',
    'Retail & Commerce',
    'Healthcare & Medical',
    'Logistics & Transportation',
    'Hospitality & Tourism',
    'Construction & Real Estate',
    'Other Business',
  ];

  @override
  void dispose() {
    _orgNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    setState(() => _loading = true);

    final result = await AuthService().registerOrganization(
      orgName: _orgNameCtrl.text,
      ownerName: _ownerNameCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      country: _selectedCountry.code,
      countryCode: _selectedCountry.dialCode,
      phone: _phoneCtrl.text,
      businessType: _selectedBusinessType,
      currency: _selectedCountry.currencyCode,
      currencySymbol: _selectedCountry.currencySymbol,
      timeZone: _selectedCountry.timeZone,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Organization ${result['orgId']} registered successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacementNamed(context, '/admin_home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Text(l10n.translate('org_registration'),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1e3a8a))),
          const SizedBox(height: 4),
          const Text('Provision a dedicated tenant workspace for your company.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),

          // Country Selector (Sets Currency, Timezone & Dial Code)
          const Text('Country / Region *',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CountryInfo>(
                value: _selectedCountry,
                isExpanded: true,
                items: CountriesData.all.map((c) {
                  return DropdownMenuItem<CountryInfo>(
                    value: c,
                    child: Row(
                      children: [
                        Text(c.flag, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(child: Text('${c.name} (${c.dialCode})')),
                        Text('${c.currencyCode} (${c.currencySymbol})',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (c) {
                  if (c != null) setState(() => _selectedCountry = c);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Org Name
          _field(_orgNameCtrl, l10n.translate('org_name'), Icons.domain, (v) {
            if (v == null || v.trim().length < 2) return 'Enter a valid organization name';
            return null;
          }),
          const SizedBox(height: 12),

          // Owner Name
          _field(_ownerNameCtrl, l10n.translate('owner_name'), Icons.person_outline, (v) {
            if (v == null || v.trim().isEmpty) return 'Enter owner or administrator name';
            return null;
          }),
          const SizedBox(height: 12),

          // Business Email
          _field(_emailCtrl, l10n.translate('business_email'), Icons.email_outlined, (v) {
            if (v == null || !v.contains('@')) return 'Enter a valid business email';
            return null;
          }, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),

          // Mobile Number with country prefix
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n.translate('mobile_number'),
              prefixIcon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.centerLeft,
                width: 70,
                child: Text(_selectedCountry.dialCode,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1e3a8a))),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().length < 6) return 'Enter valid phone number';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Business Type
          const Text('Industry / Business Type',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBusinessType,
                isExpanded: true,
                items: _businessTypes.map((t) {
                  return DropdownMenuItem<String>(
                    value: t,
                    child: Text(t, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (t) {
                  if (t != null) setState(() => _selectedBusinessType = t);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Password
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: l10n.translate('password'),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Confirm Password
          TextFormField(
            controller: _confirmPassCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: l10n.translate('confirm_password'),
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirm your password';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Auto-configured parameters preview card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Workspace configured for ${_selectedCountry.currencyCode} (${_selectedCountry.currencySymbol}) & ${_selectedCountry.timeZone}.',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Register Button
          ElevatedButton(
            onPressed: _loading ? null : _handleRegister,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(l10n.translate('register_org'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon,
    String? Function(String?) validator, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TAB 2: EMPLOYEE LOGIN (EMAIL/PASSWORD & GOOGLE SIGN-IN)
// ══════════════════════════════════════════════════════════════

class _GlobalEmployeeLoginTab extends StatefulWidget {
  const _GlobalEmployeeLoginTab();

  @override
  State<_GlobalEmployeeLoginTab> createState() => _GlobalEmployeeLoginTabState();
}

class _GlobalEmployeeLoginTabState extends State<_GlobalEmployeeLoginTab> {
  final _empEmailCtrl = TextEditingController();
  final _empPassCtrl = TextEditingController();
  final _orgIdCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _emailLoggingIn = false;
  bool _loadingGoogle = false;

  @override
  void dispose() {
    _empEmailCtrl.dispose();
    _empPassCtrl.dispose();
    _orgIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    final email = _empEmailCtrl.text.trim();
    final pass = _empPassCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your employee email and password.')),
      );
      return;
    }

    setState(() => _emailLoggingIn = true);

    final result = await AuthService().signInEmployeeWithEmail(
      email: email,
      password: pass,
      selectedOrgId: _orgIdCtrl.text.trim().isNotEmpty ? _orgIdCtrl.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _emailLoggingIn = false);

    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']), backgroundColor: Colors.red),
      );
    } else if (result['isAdminRedirect'] == true) {
      Navigator.pushReplacementNamed(context, '/admin_home');
    } else {
      Navigator.pushReplacementNamed(
        context,
        '/employee_home',
        arguments: result['empData'],
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loadingGoogle = true);

    final result = await AuthService().signInEmployeeWithGoogle(
      selectedOrgId: _orgIdCtrl.text.trim().isNotEmpty ? _orgIdCtrl.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _loadingGoogle = false);

    if (result == null || result['cancelled'] == true) {
      return;
    }

    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (result['success'] == true) {
      Navigator.pushReplacementNamed(
        context,
        '/employee_home',
        arguments: result['empData'],
      );
    }
  }

  void _showForgotPasswordDialog() {
    final emailResetCtrl = TextEditingController(text: _empEmailCtrl.text.trim());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Employee Password',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your registered employee email address to receive a secure password reset link.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailResetCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Employee Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final em = emailResetCtrl.text.trim();
              if (em.isEmpty) return;
              Navigator.pop(ctx);
              final err = await AuthService().sendPasswordReset(em);
              if (mounted) {
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: Colors.red),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Password reset link sent to $em'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context);

  return ListView(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    children: [
      Text(l10n.translate('employee_login'),
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1e3a8a))),
      const SizedBox(height: 4),
      const Text(
        'Sign in with your registered employee credentials or Google account.',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
      const SizedBox(height: 20),

      // Employee Email
      TextFormField(
        controller: _empEmailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Employee Email',
          hintText: 'e.g. employee@company.com',
          prefixIcon: Icon(Icons.email_outlined),
        ),
      ),
      const SizedBox(height: 14),

      // Password
      TextFormField(
        controller: _empPassCtrl,
        obscureText: _obscurePass,
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscurePass = !_obscurePass),
          ),
        ),
      ),
      const SizedBox(height: 14),

      // Org code (optional)
      TextFormField(
        controller: _orgIdCtrl,
        decoration: const InputDecoration(
          labelText: 'Organization Code (Optional)',
          hintText: 'e.g. ren_tracker',
          prefixIcon: Icon(Icons.apartment_outlined),
        ),
      ),
      const SizedBox(height: 20),

      // Sign In Button
      ElevatedButton(
        onPressed: _emailLoggingIn ? null : _signInWithEmail,
        child: _emailLoggingIn
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Sign In as Employee',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 10),

      // Forgot password
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: _showForgotPasswordDialog,
            child: const Text('Forgot Password?', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      const SizedBox(height: 14),

      // OR Divider
      const Row(
        children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('OR', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          Expanded(child: Divider()),
        ],
      ),
      const SizedBox(height: 16),

      // Google Sign-In for Employee
      OutlinedButton.icon(
        onPressed: _loadingGoogle ? null : _signInWithGoogle,
        icon: _loadingGoogle
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                height: 20,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.account_circle, color: Color(0xFF1e3a8a)),
              ),
        label: const Text('Continue with Google',
            style: TextStyle(
                color: Color(0xFF1e3a8a),
                fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      const SizedBox(height: 20),

      // Info card
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_user_outlined, size: 18, color: Color(0xFF1E40AF)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Security Notice: Your Google or company email must be registered in your organization\'s employee directory. Unregistered accounts will return "Invalid account".',
                style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
}

// ══════════════════════════════════════════════════════════════
//  TAB 3: ADMIN & SUPER ADMIN SECURE PORTAL
// ══════════════════════════════════════════════════════════════

class _GlobalAdminLoginTab extends StatefulWidget {
  const _GlobalAdminLoginTab();

  @override
  State<_GlobalAdminLoginTab> createState() => _GlobalAdminLoginTabState();
}

class _GlobalAdminLoginTabState extends State<_GlobalAdminLoginTab> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _loadingGoogle = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password.')),
      );
      return;
    }

    setState(() => _loading = true);
    final error = await AuthService().signInAdmin(email, pass);
    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      final user = AuthService().currentUser;
      final appUser = await AuthService().getAppUser(user?.uid ?? '');
      if (appUser?.isSuperAdmin == true) {
        Navigator.pushReplacementNamed(context, '/super_admin_home');
      } else {
        Navigator.pushReplacementNamed(context, '/admin_home');
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loadingGoogle = true);
    final result = await AuthService().signInWithGoogle();
    if (!mounted) return;
    setState(() => _loadingGoogle = false);
    if (result == null) return;
    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'])));
      return;
    }
    if (result['isSuperAdmin'] == true) {
      Navigator.pushReplacementNamed(context, '/super_admin_home');
    } else if (result['isAdmin'] == true) {
      Navigator.pushReplacementNamed(context, '/admin_home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access denied. Administrator privileges required.')),
      );
      await AuthService().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        Text(l10n.translate('admin_portal'),
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1e3a8a))),
        const SizedBox(height: 4),
        const Text(
          'Authorized access for Organization Administrators and Super Admins.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 20),

        // Email
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l10n.translate('business_email'),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 14),

        // Password
        TextFormField(
          controller: _passCtrl,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: l10n.translate('password'),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Sign In Button
        ElevatedButton(
          onPressed: _loading ? null : _login,
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(l10n.translate('sign_in'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 20),

        // OR Divider
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('OR', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),

        // Google Sign-In
        OutlinedButton.icon(
          onPressed: _loadingGoogle ? null : _signInWithGoogle,
          icon: _loadingGoogle
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                  height: 20,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.account_circle, color: Color(0xFF1e3a8a)),
                ),
          label: const Text('Continue with Google',
              style: TextStyle(
                  color: Color(0xFF1e3a8a),
                  fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
