import 'package:edtech/app/app_routes.dart';
import 'package:edtech/global/core/services/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/password_reset_provider.dart';
import '../../../../global/core/widgets/app_back_button.dart';
import '../../../../global/core/widgets/auth_button.dart';
import 'package:edtech/global/core/constants/sizes.dart';

class ResetVerificationScreen extends StatefulWidget {
  const ResetVerificationScreen({super.key});
  static const String name = '/reset-verification';

  @override
  State<ResetVerificationScreen> createState() => _ResetVerificationScreenState();
}

class _ResetVerificationScreenState extends State<ResetVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PasswordResetProvider>().startResendTimer();
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) { controller.dispose(); }
    for (var node in _focusNodes) { node.dispose(); }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    final passwordResetProvider = Provider.of<PasswordResetProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.horizontalPadding),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const AppBackButton(),
                const SizedBox(height: 40),
                _HeaderSection(email: passwordResetProvider.resetEmail ?? ""),
                const SizedBox(height: 40),
                _OtpSection(controllers: _controllers, focusNodes: _focusNodes),
                const SizedBox(height: 24),
                const _ResendTimer(),
                const SizedBox(height: 40),
                AuthButton(
                  text: "Verify",
                  isLoading: passwordResetProvider.isLoading,
                  onPressed: () async {
                    if (_otpCode.length == 6) {
                      final email = passwordResetProvider.resetEmail ?? "";
                      final success = await passwordResetProvider.verifyResetOtp(email, _otpCode);
                      if (context.mounted && success) {
                        Navigator.pushNamed(context, AppRoutes.resetPassword);
                      }
                    } else {
                      ToastService.showError("Please enter the 6-digit code");
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final String email;
  const _HeaderSection({required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Verify Reset Code", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 12),
        Text("Enter the six digit security code we sent to\n$email", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14, height: 1.5)),
      ],
    );
  }
}

class _OtpSection extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  const _OtpSection({required this.controllers, required this.focusNodes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Enter verification code", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return Row(children: [
              _OtpBox(controller: controllers[index], focusNode: focusNodes[index], onChanged: (value) {
                if (value.isNotEmpty && index < 5) { focusNodes[index + 1].requestFocus(); }
                else if (value.isEmpty && index > 0) { focusNodes[index - 1].requestFocus(); }
              }),
              if (index == 2) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text("-", style: TextStyle(color: Theme.of(context).colorScheme.outlineVariant, fontSize: 24))),
            ]);
          }),
        ),
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  const _OtpBox({required this.controller, required this.focusNode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inputFill = Theme.of(context).inputDecorationTheme.fillColor;
    return SizedBox(
      width: 44, height: 56,
      child: TextField(
        controller: controller, focusNode: focusNode,
        textAlign: TextAlign.center, keyboardType: TextInputType.number,
        maxLength: 1, onChanged: onChanged,
        decoration: InputDecoration(
          counterText: "", contentPadding: EdgeInsets.zero,
          filled: true, fillColor: inputFill,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFFEFEFF0), width: 1)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 2)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _ResendTimer extends StatelessWidget {
  const _ResendTimer();

  @override
  Widget build(BuildContext context) {
    return Consumer<PasswordResetProvider>(
      builder: (context, provider, _) {
        return Center(
          child: GestureDetector(
            onTap: provider.canResendCode ? () async { provider.startResendTimer(); await provider.forgotPassword(provider.resetEmail ?? ""); } : null,
            child: Text(provider.canResendCode ? "Resend Code" : "Resend in ${provider.resendTimerSeconds}s",
              style: TextStyle(color: provider.canResendCode ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        );
      },
    );
  }
}
