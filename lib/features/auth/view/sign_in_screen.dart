import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../model/sign_in_state.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_line.dart';
import '../../../shared/widgets/note.dart';
import '../viewmodel/sign_in_view_model.dart';

/// Phone-number sign-in.
///
/// The number is both the login and the subscription (bdapps bills the SIM),
/// so there is no password anywhere in this flow — the reset path for one
/// would be the same one-time code, which makes the password pure friction.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  @override
  void initState() {
    super.initState();
    // The view model outlives this screen, so a previous visit that ended
    // in "done" would still be showing "Signing you in…" — which is what an
    // unsubscribe used to land on.
    //
    // Invalidate rather than calling restart(): mutating a notifier from a
    // widget life-cycle is forbidden, while disposing and rebuilding it is
    // exactly what a fresh visit wants.
    ref.invalidate(signInViewModelProvider);
  }

  @override
  Widget build(BuildContext context) {
    // One page throughout. Asking for the code on a screen of its own threw
    // away everything that explained the product, and the learner is still
    // deciding until the moment they are charged — so the pitch stays put
    // and only the card at the bottom changes.
    return const Scaffold(body: SafeArea(child: _Landing()));
  }
}

// ------------------------------------------------------------- the page

/// The first screen anyone sees: what EngCoach is, what it costs, and then
/// the number field.
///
/// Deliberately a landing page rather than a bare form. A cold "enter your
/// mobile number" asks someone to hand over a billable number before they
/// know what they are buying — and bdapps charges on the very next screen,
/// so the price has to be visible before that, not after.
class _Landing extends ConsumerWidget {
  const _Landing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.xl,
        AppSpacing.pageH,
        AppSpacing.xxl,
      ),
      children: [
        const _Hero(),
        const SizedBox(height: AppSpacing.xxl),

        Text("WHAT YOU'LL GET", style: text.labelSmall),
        const SizedBox(height: AppSpacing.md),
        const _Feature(
          icon: Icons.rule_rounded,
          title: 'A check that finds your gaps',
          detail:
              'A few minutes of questions shows exactly which rules you '
              'already know and which you do not.',
        ),
        const _Feature(
          icon: Icons.translate_rounded,
          title: 'Explained in Bangla',
          detail:
              'Every rule and every wrong answer is explained in Bangla, '
              'with the English examples kept in English.',
        ),
        const _Feature(
          icon: Icons.filter_alt_outlined,
          title: 'Only what you need',
          detail:
              'Lessons skip whatever you already got right, so your time '
              'goes on the parts that are actually weak.',
        ),
        const _Feature(
          icon: Icons.trending_up_rounded,
          title: 'Proof that it worked',
          detail:
              'The same topic is tested again afterwards, so improvement is '
              'a number rather than a feeling.',
          last: true,
        ),

        const SizedBox(height: AppSpacing.xxl),
        Text('HOW SIGNING IN WORKS', style: text.labelSmall),
        const SizedBox(height: AppSpacing.md),
        const _HowStep(
          1,
          'Give your number',
          "We'll send a one-time code to your Robi or Airtel number.",
        ),
        const _HowStep(
          2,
          'Enter the code',
          'Six digits, straight from the SMS. No password to remember.',
        ),
        const _HowStep(
          3,
          "That's it",
          'Your number is your account, on any phone.',
          last: true,
        ),

        const SizedBox(height: AppSpacing.xxl),
        const _AuthCard(),
        const SizedBox(height: AppSpacing.lg),
        Note(
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
        const SizedBox(height: AppSpacing.lg),
        Text(
          'A BDApps service. Charges apply for Robi and Airtel customers. '
          'Stop any time by sending STOP engcoach to 21213.',
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
  }

}

/// The pitch, and the price.
///
/// The price sits inside the hero rather than in the small print: bdapps
/// charges on the screen after next, and someone who only discovers the cost
/// from the confirmation SMS has been ambushed.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The real mark, not a stand-in icon: this is the first
              // screen anyone sees, and it is what they will look for on
              // their home screen afterwards.
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Image.asset(
                  'assets/brand/logo_mark.png',
                  width: 38,
                  height: 38,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'EngCoach',
                style: text.titleLarge?.copyWith(color: AppColors.onPrimary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'English that finally makes sense.',
            style: text.headlineLarge?.copyWith(color: AppColors.onPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Grammar taught in Bangla, tested in English — so you can see '
            'what you are getting wrong and fix it.',
            style: text.bodyMedium?.copyWith(color: AppColors.onPrimaryBody),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  size: 16,
                  color: AppColors.onPrimaryMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Tk 2.78 a day, including VAT, SD and SC. '
                    'Robi and Airtel numbers only.',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.onPrimaryBody,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One thing the subscription buys.
class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.detail,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        radius: AppRadius.lg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 18, color: AppColors.textOnMuted),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleLarge),
                  const SizedBox(height: 2),
                  Text(detail, style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One step of the sign-in explanation — the same numbered-circle vocabulary
/// the topic overview uses for its learning path.
class _HowStep extends StatelessWidget {
  const _HowStep(this.number, this.title, this.detail, {this.last = false});

  final int number;
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: text.labelSmall?.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!last)
                Expanded(child: Container(width: 1, color: AppColors.border)),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleLarge),
                  const SizedBox(height: 2),
                  Text(detail, style: text.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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

// ------------------------------------------------------- the changing card

/// The only part of the page that changes.
///
/// Number in, then code in, then gone — the router takes the learner into
/// the app the instant Firebase has a session, so there is no "you're signed
/// in" screen to sit through.
class _AuthCard extends ConsumerStatefulWidget {
  const _AuthCard();

  @override
  ConsumerState<_AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends ConsumerState<_AuthCard> {
  late final List<TextEditingController> _boxes = List.generate(
    SignInState.codeLength,
    (_) => TextEditingController(),
  );
  late final List<FocusNode> _focus = List.generate(
    SignInState.codeLength,
    (_) => FocusNode(),
  );

  static final _errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: const BorderSide(color: AppColors.danger),
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
    final state = ref.watch(signInViewModelProvider);

    // A rejected code is cleared by the view model; the boxes follow.
    ref.listen(signInViewModelProvider.select((s) => s.code), (_, code) {
      if (code.isEmpty && _boxes.any((c) => c.text.isNotEmpty)) {
        for (final c in _boxes) {
          c.clear();
        }
        _focus.first.requestFocus();
      }
    });

    return switch (state.step) {
      SignInStep.phone => _phoneCard(state),
      SignInStep.code => _codeCard(state),
      SignInStep.done => _doneCard(state),
    };
  }

  /// The moment between a Firebase session existing and the router acting
  /// on it — or, if the token exchange failed, the place that says so.
  ///
  /// This showed a bare spinner once, which meant a failed exchange span
  /// forever with the reason sitting unread in the state.
  Widget _doneCard(SignInState state) {
    final text = Theme.of(context).textTheme;
    final model = ref.read(signInViewModelProvider.notifier);

    if (state.error == null) {
      return AppCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.md),
            Text('Signing you in…', style: text.bodyMedium),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ALMOST THERE', style: text.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          // Their subscription is real and already paid for; only the
          // Firebase handshake failed. Say that, rather than implying the
          // whole sign-in did not work.
          Text(state.error!, style: text.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: state.busy ? null : model.retrySession,
            child: Text(state.busy ? 'Trying…' : 'Try again'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: model.restart,
            child: const Text('Start over'),
          ),
        ],
      ),
    );
  }

  Widget _phoneCard(SignInState state) {
    final text = Theme.of(context).textTheme;
    final model = ref.read(signInViewModelProvider.notifier);

    return AppCard(
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
                  style: text.bodyLarge?.copyWith(fontSize: 15),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(SignInState.phoneLength),
                  ],
                  decoration: InputDecoration(
                    hintText: '01XXXXXXXXX',
                    errorText: null,
                    // The message is shown once below, not twice.
                    enabledBorder: state.error != null ? _errorBorder : null,
                  ),
                  onChanged: model.phoneChanged,
                  onSubmitted: (_) => model.sendCode(),
                ),
              ),
            ],
          ),
          if (state.error != null) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            ErrorLine(state.error!),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: state.canSend ? model.sendCode : null,
            child: Text(state.busy ? 'Sending…' : 'Send code'),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            'By continuing you agree to our Terms and Privacy Policy.',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _codeCard(SignInState state) {
    final text = Theme.of(context).textTheme;
    final model = ref.read(signInViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ENTER THE CODE', style: text.labelSmall),
              const SizedBox(height: AppSpacing.xs),
              Text.rich(
                TextSpan(
                  style: text.bodySmall,
                  children: [
                    const TextSpan(text: 'Sent by SMS to '),
                    TextSpan(
                      text: state.prettyPhone,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Six fixed-width boxes overflowed a 360dp screen once card
              // and page padding were taken out. They share whatever width
              // there is instead, so the row fits any phone.
              Row(
                children: [
                  for (var i = 0; i < _boxes.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _CodeBox(
                        controller: _boxes[i],
                        focusNode: _focus[i],
                        hasError: state.error != null,
                        onChanged: (v) => _onChanged(i, v),
                        onKey: (event) => _onKey(i, event),
                        autofocus: i == 0,
                      ),
                    ),
                  ],
                ],
              ),
              if (state.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                ErrorLine(state.error!),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: state.canVerify ? model.verify : null,
                child: Text(state.busy ? 'Checking…' : 'Verify and continue'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: model.changeNumber,
                    child: const Text('Change number'),
                  ),
                  state.canResend
                      ? TextButton(
                          onPressed: model.resend,
                          child: const Text('Resend code'),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Text.rich(
                            TextSpan(
                              style: text.bodySmall,
                              children: [
                                const TextSpan(text: 'Resend in '),
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
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Verifying is what subscribes the learner and starts the daily
        // charge, so the price sits where they commit to it.
        Note(
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
