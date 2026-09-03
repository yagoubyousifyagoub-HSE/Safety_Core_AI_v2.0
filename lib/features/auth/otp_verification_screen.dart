import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/gen/app_localizations.dart';
import '../dashboard/dashboard_screen.dart';
import 'auth_service.dart';
import 'widgets/otp_input_field.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _authService = AuthService();
  String _code = '';
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorText;

  static const int _resendCooldownSeconds = 30;
  int _secondsRemaining = _resendCooldownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _secondsRemaining = _resendCooldownSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsRemaining--);
      if (_secondsRemaining <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context)!;
    if (_code.length != 6) return;

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });
    try {
      await _authService.verifyEmailOtp(email: widget.email, code: _code);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } catch (_) {
      setState(() => _errorText = l10n.invalidOtpCode);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsRemaining > 0) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isResending = true);
    try {
      await _authService.sendEmailOtp(email: widget.email);
      _startCooldown();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.codeResent)));
    } catch (_) {
      setState(() => _errorText = l10n.otpSendFailed);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.verifyEmailTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.accent),
                const SizedBox(height: 14),
                Text(
                  l10n.otpInstructions(widget.email),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.slate500, fontSize: 13),
                ),
                const SizedBox(height: 26),
                OtpInputField(
                  onChanged: (value) => _code = value,
                  onCompleted: (value) {
                    _code = value;
                    _verify();
                  },
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 14),
                  Text(_errorText!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.statusOpen)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isVerifying ? null : _verify,
                  child: _isVerifying
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                      : Text(l10n.verifyCodeButton),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: (_secondsRemaining > 0 || _isResending) ? null : _resend,
                  child: Text(
                    _secondsRemaining > 0 ? l10n.resendCodeIn(_secondsRemaining) : l10n.resendCode,
                    style: const TextStyle(color: AppColors.slate500),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.changeEmail),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
