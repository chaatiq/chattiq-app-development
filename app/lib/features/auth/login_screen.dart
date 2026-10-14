import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/open_web.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/form_alert.dart';
import 'auth_controller.dart';

/// Same as server loginSchema.
const _minPasswordLength = 8;

/// Copy and layout follow web/app/login/page.jsx.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _showPassword = false;
  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email address or user name and your password.');
      return;
    }
    if (password.length < _minPasswordLength) {
      setState(() => _error = 'Password must be at least $_minPasswordLength characters.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _error = '';
      _loading = true;
    });
    try {
      await ref.read(authControllerProvider.notifier).signIn(email, password);
      // The router moves to the signed-in screens.
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userFacingMessage(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkStyle = AppText.caption.copyWith(color: AppColors.textStrong, decoration: TextDecoration.underline);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s4),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: AutofillGroup(
              child: Column(
                children: [
                  Image.asset('assets/images/logo.png', width: 148, semanticLabel: 'Chattiq'),
                  const SizedBox(height: AppSpacing.s6),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border, width: 1.5),
                      borderRadius: BorderRadius.circular(20), // auth.css .auth-page__form-wrap: 1.25rem
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(header: true, child: Text('Log in', style: AppText.authTitle)),
                        const SizedBox(height: AppSpacing.s5),
                        if (_error.isNotEmpty) ...[FormAlert(message: _error), const SizedBox(height: AppSpacing.s5)],
                        AppTextField(
                          label: 'Email address or user name',
                          controller: _email,
                          enabled: !_loading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        AppTextField(
                          label: 'Password',
                          controller: _password,
                          focusNode: _passwordFocus,
                          enabled: !_loading,
                          obscureText: !_showPassword,
                          textInputAction: TextInputAction.go,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _submit(),
                          suffix: TextButton(
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF555555)),
                            child: Text(
                              _showPassword ? 'Hide' : 'Show',
                              semanticsLabel: _showPassword ? 'Hide password' : 'Show password',
                              style: AppText.label.copyWith(fontSize: 13, color: const Color(0xFF555555)),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text.rich(
                          TextSpan(
                            style: AppText.caption.copyWith(color: const Color(0xFF666666), height: 19 / 12),
                            children: [
                              const TextSpan(text: 'By continuing, you agree to the '),
                              TextSpan(
                                text: 'Terms of use',
                                style: linkStyle,
                                recognizer: TapGestureRecognizer()..onTap = () => openWebPage('/privacy-policy'),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: linkStyle,
                                recognizer: TapGestureRecognizer()..onTap = () => openWebPage('/privacy-policy'),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        AppButton(title: 'Log in', loadingTitle: 'Logging in…', loading: _loading, onPressed: _submit),
                        if (canOpenWeb) ...[
                          const SizedBox(height: AppSpacing.s4),
                          Center(
                            child: TextButton(
                              onPressed: () => openWebPage('/forgot-password'),
                              child: Text(
                                'Forgot your password',
                                style: AppText.body.copyWith(
                                  color: AppColors.textStrong,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Text.rich(
                              TextSpan(
                                style: AppText.body.copyWith(color: const Color(0xFF555555)),
                                children: [
                                  const TextSpan(text: "Don't have an account? "),
                                  TextSpan(
                                    text: 'Sign up',
                                    style: AppText.subheading.copyWith(color: AppColors.textStrong),
                                    recognizer: TapGestureRecognizer()..onTap = () => openWebPage('/register'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
