import 'package:flutter/material.dart';

import '../../core/function/components.dart';
import '../data_state.dart';
import '../utils/app_styles.dart';
import '../utils/constant.dart';
import '../utils/extensions.dart';
import '../utils/xpedia_tokens.dart';
import 'xpedia/x_widgets.dart';

class LoadingIndicatorView extends StatelessWidget {
  const LoadingIndicatorView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(
            color: isAppDarkMode() ? kDarkPrimaryColor : kLightPrimaryColor,
          ),
          if (message != null) ...<Widget>[
            16.sbh,
            Text(message!, style: AppStyles.styleMedium14(context)),
          ],
        ],
      ),
    );
  }
}

/// Renders a [DataError] with its backend code intact.
///
/// The API doc is repeatedly explicit that generic messages are not good enough
/// here — a `GATES_NOT_PASSED` carries in `details` the only statement of
/// *which* gate failed, and a 422 carries `details.missing`. Both are shown.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.error,
    this.onRetry,
    this.retryLabel = 'Coba lagi',
  });

  final DataError error;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final details = _detailLines();

    return Center(
      child: SingleChildScrollView(
        padding: 24.pa,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline_rounded,
                size: 48, color: kErrorColor),
            16.sbh,
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: AppStyles.styleMedium16(context),
            ),
            8.sbh,
            Text(
              error.code,
              style: AppStyles.styleRegular12(context)
                  .copyWith(color: kLightThirdColor),
            ),
            if (details.isNotEmpty) ...<Widget>[
              16.sbh,
              Container(
                width: double.infinity,
                padding: 12.pa,
                decoration: BoxDecoration(
                  color: kErrorColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: details
                      .map(
                        (line) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• $line',
                            style: AppStyles.styleRegular12(context),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            if (onRetry != null) ...<Widget>[
              24.sbh,
              XButton.secondary(
                label: retryLabel,
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _detailLines() {
    final details = error.details;
    if (details == null || details.isEmpty) return const <String>[];

    return details.entries.map((entry) {
      final value = entry.value;
      if (value is List) return '${entry.key}: ${value.join(', ')}';
      if (value is Map) return '${entry.key}: ${value.keys.join(', ')}';
      return '${entry.key}: $value';
    }).toList();
  }
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  /// The Xpedia empty state (design.md §4): icon, one line, one action —
  /// never a large illustration.
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: XSpace.s24,
          vertical: XSpace.s32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 32, color: XColors.textTertiary),
            const SizedBox(height: XSpace.s12),
            Text(message, textAlign: TextAlign.center, style: XText.titleM),
            if (action != null) ...<Widget>[
              const SizedBox(height: XSpace.s16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// One place that decides how a failure is announced, so every screen reports
/// errors the same way.
void showErrorSnackBar(BuildContext context, DataError error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: XColors.dangerStrong,
        content: Text('${error.message}\n(${error.code})'),
        duration: const Duration(seconds: 5),
      ),
    );
}

void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: XColors.successStrong,
        content: Text(message),
      ),
    );
}
