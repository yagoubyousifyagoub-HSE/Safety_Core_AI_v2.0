import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';

/// Renders as N boxed digits but is driven by a single hidden [TextField],
/// so we get native keyboard/paste/autofill behavior without depending on a
/// third-party OTP package.
class OtpInputField extends StatefulWidget {
  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;

  const OtpInputField({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
  });

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    widget.onChanged(value);
    if (value.length == widget.length) {
      widget.onCompleted?.call(value);
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_controller, _focusNode]),
            builder: (context, _) {
              final text = _controller.text;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(widget.length, (i) => _digitBox(i, text)),
              );
            },
          ),
          // Invisible field that actually owns focus, input, and the keyboard.
          Opacity(
            opacity: 0,
            child: SizedBox(
              width: 1,
              height: 1,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                onChanged: _handleChanged,
                showCursor: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _digitBox(int index, String text) {
    final isFilled = index < text.length;
    final isActive = index == text.length;
    final highlighted = isActive && _focusNode.hasFocus;
    return Container(
      width: 44,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.slate800,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted ? AppColors.accent : (isFilled ? AppColors.slate500 : AppColors.slate700),
          width: highlighted ? 1.6 : 1,
        ),
      ),
      child: Text(
        isFilled ? text[index] : '',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.slate200),
      ),
    );
  }
}
