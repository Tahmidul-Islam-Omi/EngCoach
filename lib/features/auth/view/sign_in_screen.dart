import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../model/sign_in_state.dart';
import '../viewmodel/sign_in_view_model.dart';

/// Phone-number sign-in.
///
/// The number is both the login and the subscription (bdapps bills the SIM),
/// so there is no password anywhere in this flow — the reset path for one
/// would be the same one-time code, which makes the password pure friction.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(signInViewModelProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageH,
            AppSpacing.xxxl,
            AppSpacing.pageH,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepBar(step: state.step),
              const SizedBox(height: AppSpacing.xxxl + AppSpacing.xs),
              Expanded(
                child: switch (state.step) {
                  SignInStep.phone => const _PhoneStep(),
                  SignInStep.code => const _CodeStep(),
                  SignInStep.done => const _DoneStep(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- progress

/// Numbered circles with connectors — the same vocabulary as the topic
/// overview's path, turned on its side because a phone has more width than
/// height to spare here.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});

  final SignInStep step;

  static const _labels = ['NUMBER', 'CODE', 'READY'];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final at = SignInStep.values.indexOf(step);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          SizedBox(
            width: 62,
            child: Column(
              children: [
                _Dot(number: i + 1, reached: i <= at),
                const SizedBox(height: 7),
                Text(
                  _labels[i],
                  textAlign: TextAlign.center,
                  style: text.labelSmall?.copyWith(
                    color: i <= at
                        ? AppColors.textPrimary
                        : AppColors.controlOutline,
                  ),
                ),
              ],
            ),
          ),
          if (i < _labels.length - 1)
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 15),
                child: Divider(height: 1, color: AppColors.border),
              ),
            ),
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.number, required this.reached});

  final int number;
  final bool reached;

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: reached ? AppColors.primary : Colors.transparent,
      border: Border.all(
        color: reached ? AppColors.primary : AppColors.border,
      ),
      shape: BoxShape.circle,
    ),
    child: Text(
      '$number',
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: reached ? AppColors.onPrimary : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// ------------------------------------------------------------- step 1: phone

class _PhoneStep extends ConsumerWidget {
  const _PhoneStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final state = ref.watch(signInViewModelProvider);
    final model = ref.read(signInViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sign in to start learning', style: text.headlineLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Your mobile number is your login and your subscription. '
          'No password to remember.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xxl + AppSpacing.xs),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('MOBILE NUMBER', style: text.labelSmall),
              const SizedBox(height: AppSpacing.sm + 2),
              Row(
                children: [
                  const _CountryChip(),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      style: text.bodyLarge?.copyWith(fontSize: 15),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(
                          SignInState.phoneLength,
                        ),
                      ],
                      decoration: InputDecoration(
                        hintText: '01XXXXXXXXX',
                        errorText: null,
                        // The message is shown once below, not twice.
                        enabledBorder: state.error != null
                            ? _errorBorder
                            : null,
                      ),
                      onChanged: model.phoneChanged,
                      onSubmitted: (_) => model.sendCode(),
                    ),
                  ),
                ],
              ),
              if (state.error != null) ...[
                const SizedBox(height: AppSpacing.sm + 2),
                _ErrorLine(state.error!),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: state.canSend ? model.sendCode : null,
                child: Text(state.busy ? 'Sending…' : 'Send code'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'By continuing you agree to our Terms and Privacy Policy.',
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
        const Spacer(),
        _Note(
          icon: Icons.smartphone_outlined,
          child: Text.rich(
            TextSpan(
              style: text.bodySmall,
              children: const [
                TextSpan(text: 'Use an active prepaid '),
                TextSpan(
                  text: 'Robi',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(text: ' or '),
                TextSpan(
                  text: 'Airtel',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: ' number — the subscription is charged to it.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static final _errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: const BorderSide(color: AppColors.danger),
  );
}

/// The +88 prefix. Fixed rather than a picker: bdapps only bills Bangladeshi
/// numbers, so offering other countries would only invite a dead end.
class _CountryChip extends StatelessWidget {
  const _CountryChip();

  @override
  Widget build(BuildContext context) => Container(
    height: AppSizes.buttonHeight,
    padding: const EdgeInsets.symmetric(horizontal: 13),
    decoration: BoxDecoration(
      color: AppColors.background,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 14,
          alignment: const Alignment(-0.15, 0),
          decoration: BoxDecoration(
            color: const Color(0xFF0F7A4F),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Container(
            width: 8.2,
            height: 8.2,
            decoration: const BoxDecoration(
              color: Color(0xFFC8102E),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          '+88',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

// -------------------------------------------------------------- step 2: code

class _CodeStep extends ConsumerStatefulWidget {
  const _CodeStep();

  @override
  ConsumerState<_CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends ConsumerState<_CodeStep> {
  late final List<TextEditingController> _boxes = List.generate(
    SignInState.codeLength,
    (_) => TextEditingController(),
  );
  late final List<FocusNode> _focus = List.generate(
    SignInState.codeLength,
    (_) => FocusNode(),
  );

  @override
  void dispose() {
    for (final c in _boxes) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  /// Pushes the six boxes back into the view model as one string, so the
  /// widgets never hold the answer — they only hold the caret.
  void _publish() {
    ref
        .read(signInViewModelProvider.notifier)
        .codeChanged(_boxes.map((c) => c.text).join());
  }

  void _onChanged(int i, String value) {
    if (value.length > 1) {
      // A paste or an autofilled SMS code: spread it across the boxes.
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var j = 0; j < _boxes.length; j++) {
        _boxes[j].text = j < digits.length ? digits[j] : '';
      }
      _publish();
      FocusScope.of(context).unfocus();
      return;
    }
    _publish();
    if (value.isNotEmpty && i < _boxes.length - 1) {
      _focus[i + 1].requestFocus();
    }
  }

  KeyEventResult _onKey(int i, KeyEvent event) {
    // Backspace in an empty box steps back, which is what every OTP field
    // does and what a learner will expect.
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _boxes[i].text.isEmpty &&
        i > 0) {
      _boxes[i - 1].clear();
      _focus[i - 1].requestFocus();
      _publish();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = ref.watch(signInViewModelProvider);
    final model = ref.read(signInViewModelProvider.notifier);

    // A rejected code is cleared by the view model; the boxes follow.
    ref.listen(signInViewModelProvider.select((s) => s.code), (_, code) {
      if (code.isEmpty && _boxes.any((c) => c.text.isNotEmpty)) {
        for (final c in _boxes) {
          c.clear();
        }
        _focus.first.requestFocus();
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enter the code', style: text.headlineLarge),
        const SizedBox(height: AppSpacing.sm),
        Text.rich(
          TextSpan(
            style: text.bodyMedium,
            children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(
                text: state.prettyPhone,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const TextSpan(text: '. '),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: model.changeNumber,
            child: const Text('Change number'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < _boxes.length; i++)
                    _CodeBox(
                      controller: _boxes[i],
                      focusNode: _focus[i],
                      hasError: state.error != null,
                      onChanged: (v) => _onChanged(i, v),
                      onKey: (event) => _onKey(i, event),
                      autofocus: i == 0,
                    ),
                ],
              ),
              if (state.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ErrorLine(state.error!),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: state.canVerify ? model.verify : null,
                child: Text(
                  state.busy ? 'Checking…' : 'Verify and continue',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: state.canResend
                    ? TextButton(
                        onPressed: model.resend,
                        child: const Text('Resend code'),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: Text.rich(
                          TextSpan(
                            style: text.bodyMedium,
                            children: [
                              const TextSpan(text: 'Resend code in '),
                              TextSpan(
                                text: state.clock,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                  fontFeatures: [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Verifying is what subscribes the learner and starts the daily
        // charge, so the price is stated on the screen where they commit to
        // it — not buried in the terms.
        _Note(
          icon: Icons.payments_outlined,
          tone: AppColors.warning,
          background: AppColors.warningSurface,
          border: AppColors.warning,
          child: Text.rich(
            TextSpan(
              style: text.bodyMedium?.copyWith(color: AppColors.warning),
              children: const [
                TextSpan(text: 'Entering this code subscribes you at '),
                TextSpan(
                  text: 'Tk 2.78 per day',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: ', charged from your mobile balance. To stop, send ',
                ),
                TextSpan(
                  text: 'STOP engcoach',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' to 21213.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
    required this.onKey,
    required this.autofocus,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final KeyEventResult Function(KeyEvent) onKey;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 58,
      child: Focus(
        onKeyEvent: (_, event) => onKey(event),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          // Lets the platform drop an SMS code straight in.
          autofillHints: const [AutofillHints.oneTimeCode],
          style: Theme.of(context).textTheme.headlineSmall,
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            enabledBorder: hasError
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.danger),
                  )
                : null,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- step 3: done

class _DoneStep extends ConsumerWidget {
  const _DoneStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final state = ref.watch(signInViewModelProvider);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.successSurface,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 30,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          "You're signed in",
          textAlign: TextAlign.center,
          style: text.headlineLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: 260,
          child: Text(
            '${state.prettyPhone} is now your account. '
            "We won't ask for a code again on this phone.",
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        TextButton(
          onPressed: ref.read(signInViewModelProvider.notifier).restart,
          child: const Text('Run through it again'),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- shared bits

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xl),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadius.xl),
    ),
    child: child,
  );
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 1),
        child: Icon(
          Icons.error_outline_rounded,
          size: 15,
          color: AppColors.danger,
        ),
      ),
      const SizedBox(width: AppSpacing.xs + 2),
      Expanded(
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
        ),
      ),
    ],
  );
}

class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.child,
    this.tone = AppColors.textSecondary,
    this.background = AppColors.surface,
    this.border = AppColors.border,
  });

  final IconData icon;
  final Widget child;
  final Color tone;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg - 2,
      vertical: 13,
    ),
    decoration: BoxDecoration(
      color: background,
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 17, color: tone),
        ),
        const SizedBox(width: AppSpacing.sm + 1),
        Expanded(child: child),
      ],
    ),
  );
}
