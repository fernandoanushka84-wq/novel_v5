import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onContinue,
    this.onSkipAsReader,
  });

  /// method: google | email | guest
  /// For email, pass email, password, mode (login|register), optional displayName.
  final Future<void> Function(
    String method, {
    String? email,
    String? password,
    String? mode,
    String? displayName,
  }) onContinue;

  final VoidCallback? onSkipAsReader;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEmailAuth({required bool register}) async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var obscure = true;

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        register ? 'Create account' : 'Sign in with email',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        register
                            ? 'Use a password (min 6 characters). This is required — email-only login is disabled for security.'
                            : 'Enter the email and password for your account.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.muted,
                            ),
                      ),
                      const SizedBox(height: 18),
                      if (register) ...[
                        TextFormField(
                          controller: nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Display name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty || !s.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passCtrl,
                        obscureText: obscure,
                        autofillHints: [
                          register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setModal(() => obscure = !obscure),
                          ),
                        ),
                        validator: (v) {
                          if ((v ?? '').length < 6) {
                            return 'At least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: () {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            Navigator.of(context).pop({
                              'email': emailCtrl.text.trim(),
                              'password': passCtrl.text,
                              'mode': register ? 'register' : 'login',
                              'displayName': nameCtrl.text.trim(),
                            });
                          },
                          child: Text(register ? 'Create account' : 'Sign in'),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Future.microtask(
                            () => _openEmailAuth(register: !register),
                          );
                        },
                        child: Text(
                          register
                              ? 'Already have an account? Sign in'
                              : 'Need an account? Register',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    emailCtrl.dispose();
    passCtrl.dispose();
    nameCtrl.dispose();
    if (result == null || !mounted) return;

    await _run(
      () => widget.onContinue(
        'email',
        email: result['email'],
        password: result['password'],
        mode: result['mode'],
        displayName: result['displayName'],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFDF9F3), Color(0xFFEAF5F4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 48),
                        Text(
                          'Inkitt',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                fontSize: 54,
                                fontFamily: 'serif',
                                fontWeight: FontWeight.w700,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Discover Millions of Free Books',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: AppTheme.muted),
                        ),
                        const SizedBox(height: 40),
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        _LoginButton(
                          icon: Icons.g_mobiledata_rounded,
                          label: 'Continue with Google',
                          onPressed: _busy
                              ? null
                              : () => _run(() => widget.onContinue('google')),
                        ),
                        const SizedBox(height: 12),
                        _LoginButton(
                          icon: Icons.email_outlined,
                          label: 'Sign in with Email',
                          onPressed:
                              _busy ? null : () => _openEmailAuth(register: false),
                        ),
                        const SizedBox(height: 12),
                        _LoginButton(
                          icon: Icons.person_add_alt_1_outlined,
                          label: 'Create account with Email',
                          onPressed:
                              _busy ? null : () => _openEmailAuth(register: true),
                        ),
                        const SizedBox(height: 12),
                        _LoginButton(
                          icon: Icons.person_outline,
                          label: 'Continue as Guest',
                          onPressed: _busy
                              ? null
                              : () => _run(() => widget.onContinue('guest')),
                        ),
                        if (widget.onSkipAsReader != null) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _busy ? null : widget.onSkipAsReader,
                            child: const Text(
                              'Browse stories only (read-only, no account)',
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          'Banned or suspended accounts cannot sign in. '
                          'Each Google / email account is separate — '
                          'moderation applies to that account.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.muted,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'By continuing you agree to our Terms of Service and Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.ink,
          side: const BorderSide(color: AppTheme.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: Colors.white,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: const Color(0xFF525252)),
        ),
      ),
    );
  }
}
