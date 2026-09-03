import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/gen/app_localizations.dart';
import '../dashboard/dashboard_screen.dart';
import 'auth_service.dart';
import 'otp_verification_screen.dart';

/// Step 1 of passwordless auth: collect an email and request a one-time
/// code (Step 2 is [OtpVerificationScreen]) — or skip auth entirely via a
/// sandboxed anonymous [AuthService.signInAsGuest] session.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _authService = AuthService();

  bool _isSendingCode = false;
  bool _isContinuingAsGuest = false;
  bool _isEnteringLocalDemo = false;
  String? _errorText;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSendingCode = true;
      _errorText = null;
    });

    final email = _emailCtrl.text.trim();
    try {
      await _authService.sendEmailOtp(email: email);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtpVerificationScreen(email: email)),
      );
    } catch (e) {
      setState(() => _errorText = '${l10n.otpSendFailed}\n$e');
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _continueAsGuest() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isContinuingAsGuest = true;
      _errorText = null;
    });
    try {
      await _authService.signInAsGuest();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      setState(() => _errorText = '${l10n.guestSignInFailed}\n$e');
    } finally {
      if (mounted) setState(() => _isContinuingAsGuest = false);
    }
  }

  /// Skips Supabase entirely — no auth call, no network request of any
  /// kind. Purely for exploring the UI/workflow when the backend is
  /// unreachable (DNS issues, offline, first-run demoing, etc.).
  void _enterLocalDemo() {
    setState(() => _isEnteringLocalDemo = true);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen(localDemo: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final busy = _isSendingCode || _isContinuingAsGuest || _isEnteringLocalDemo;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield_moon_outlined, size: 56, color: AppColors.accent),
                  const SizedBox(height: 12),
                  Text(l10n.appTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    l10n.loginSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.slate500, fontSize: 12),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(labelText: l10n.emailLabel),
                    validator: (v) =>
                        (v == null || !v.contains('@') || !v.contains('.')) ? l10n.emailInvalid : null,
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(_errorText!, style: const TextStyle(color: AppColors.statusOpen)),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: busy ? null : _sendCode,
                    child: _isSendingCode
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                        : Text(l10n.sendCodeButton),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.slate700)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(l10n.orDivider, style: const TextStyle(color: AppColors.slate500, fontSize: 12)),
                      ),
                      const Expanded(child: Divider(color: AppColors.slate700)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _continueAsGuest,
                    icon: _isContinuingAsGuest
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.explore_outlined),
                    label: Text(l10n.continueAsGuest),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.guestDisclaimer,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.slate500, fontSize: 11),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: busy ? null : _enterLocalDemo,
                    icon: const Icon(Icons.phonelink_off_outlined, size: 18),
                    label: Text(l10n.localDemoButton),
                  ),
                  Text(
                    l10n.localDemoDisclaimer,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.slate500, fontSize: 11),
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
