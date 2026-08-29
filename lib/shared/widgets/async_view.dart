import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// What went wrong, in terms a learner can act on.
///
/// Telling someone to check their connection when the real fault is malformed
/// content is worse than saying nothing — it sends them (and us) looking in
/// the wrong place.
enum _Failure {
  connection,
  content,
  unknown;

  static _Failure from(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return _Failure.connection;
    }
    // Bad or missing content: a malformed topic, a field the model didn't
    // expect, an asset that isn't bundled.
    if (error is FormatException || error is TypeError) {
      return _Failure.content;
    }
    return _Failure.unknown;
  }

  String get title => switch (this) {
        _Failure.connection => "You're offline.",
        _Failure.content => "This content couldn't be opened.",
        _Failure.unknown => 'Something went wrong.',
      };

  String get detail => switch (this) {
        _Failure.connection =>
          'Check your connection and try again.',
        // Said nothing about being reported: there is no error reporting,
        // and "we've been told about it" leaves a learner waiting for a fix
        // nobody knows is needed.
        _Failure.content => 'Please try again.',
        _Failure.unknown => 'Please try again.',
      };

  IconData get icon => switch (this) {
        _Failure.connection => Icons.wifi_off_rounded,
        _Failure.content => Icons.report_gmailerrorred_rounded,
        _Failure.unknown => Icons.error_outline_rounded,
      };
}

/// Renders an [AsyncValue] with consistent loading and error states.
///
/// Every screen in this app waits on something, so the three states are
/// handled in one place rather than re-invented per screen — and the error
/// state offers a retry instead of stranding the learner.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    required this.value,
    required this.data,
    this.onRetry,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _ErrorView(
        failure: _Failure.from(error),
        error: error,
        onRetry: onRetry,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.failure,
    required this.error,
    required this.onRetry,
  });

  final _Failure failure;
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(failure.icon, size: 32, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              failure.title,
              style: text.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              failure.detail,
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),

            // In debug builds, show what actually happened. The friendly
            // message is for learners; this is for whoever is fixing it.
            if (kDebugMode) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.dangerSurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  '$error',
                  style: text.bodySmall?.copyWith(color: AppColors.danger),
                  textAlign: TextAlign.left,
                ),
              ),
            ],

            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
