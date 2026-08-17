import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _institutionCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  String _role = 'student';
  int? _yearOfStudy;
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outlined),
                      ),
                      validator: (v) => v != null && v.isNotEmpty ? null : 'Required',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) =>
                          v != null && v.contains('@') ? null : 'Enter a valid email',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          v != null && v.length >= 6 ? null : 'Min 6 characters',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _role,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'student', child: Text('Student')),
                        DropdownMenuItem(value: 'lecturer', child: Text('Lecturer')),
                        DropdownMenuItem(value: 'researcher', child: Text('Researcher')),
                      ],
                      onChanged: (v) => setState(() => _role = v ?? 'student'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _institutionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Institution',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _departmentCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                    ),
                    if (_role == 'student') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _studentIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Student ID',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _yearOfStudy,
                        decoration: const InputDecoration(
                          labelText: 'Year of Study',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        items: List.generate(
                          7,
                          (i) => DropdownMenuItem(value: i + 1, child: Text('Year ${i + 1}')),
                        ),
                        onChanged: (v) => setState(() => _yearOfStudy = v),
                      ),
                    ],
                    if (auth.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        auth.error!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: auth.isLoading
                          ? null
                          : () async {
                              if (_formKey.currentState!.validate()) {
                                final success = await auth.register(
                                  email: _emailCtrl.text.trim(),
                                  password: _passwordCtrl.text,
                                  fullName: _nameCtrl.text.trim(),
                                  role: _role,
                                  institution: _institutionCtrl.text.isEmpty
                                      ? null
                                      : _institutionCtrl.text,
                                  department: _departmentCtrl.text.isEmpty
                                      ? null
                                      : _departmentCtrl.text,
                                  studentId: _studentIdCtrl.text.isEmpty
                                      ? null
                                      : _studentIdCtrl.text,
                                  yearOfStudy: _yearOfStudy,
                                );
                                if (success && context.mounted) {
                                  context.go('/');
                                }
                              }
                            },
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Create Account'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Already have an account? Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _institutionCtrl.dispose();
    _departmentCtrl.dispose();
    _studentIdCtrl.dispose();
    super.dispose();
  }
}
