import 'package:flutter/material.dart';

import '../../../config/env/app_config.dart';
import '../../data_state.dart';
import '../../utils/xpedia_tokens.dart';
import '../state_widgets.dart';
import '../xpedia/x_widgets.dart';

/// "Data contoh" — on every figure that comes from sample data, so nobody
/// mistakes it for the store's own. Renders nothing outside demo mode.
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.demoData) return const SizedBox.shrink();
    // Shrink-wraps even inside a stretched Column.
    return const Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      child: XChip(
        label: 'Data contoh',
        tone: XTone.preOrder,
        icon: Icons.science_outlined,
      ),
    );
  }
}

/// A section title with the [DemoBadge] beside it.
class DemoSectionHeader extends StatelessWidget {
  const DemoSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: XSpace.s8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: XSpace.s8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(title, style: XText.headingM),
                    const DemoBadge(),
                  ],
                ),
                if (subtitle != null) Text(subtitle!, style: XText.bodyS),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// What a screen shows for a feature whose endpoint does not exist yet.
class ApiPendingCard extends StatelessWidget {
  const ApiPendingCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return XCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.hourglass_empty_rounded, color: XColors.textTertiary),
          const SizedBox(width: XSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Menunggu API', style: XText.titleM),
                const SizedBox(height: 2),
                Text(message, style: XText.bodyS),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Loads [load] once and renders its result: a spinner, the data, an empty
/// state, [ApiPendingCard] for `API_PENDING`, or the usual error view.
class PendingBuilder<T> extends StatefulWidget {
  const PendingBuilder({
    super.key,
    required this.load,
    required this.builder,
    this.empty,
    this.pending,
    this.compact = false,
  });

  final Future<DataState<T>> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload)
      builder;
  final Widget? empty;

  /// Replaces [ApiPendingCard] when the screen has its own fallback.
  final Widget Function(DataError error)? pending;

  /// Inside a scrolling page: a small spinner rather than a full-page one.
  final bool compact;

  @override
  State<PendingBuilder<T>> createState() => _PendingBuilderState<T>();
}

class _PendingBuilderState<T> extends State<PendingBuilder<T>> {
  DataState<T>? _state;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final result = await widget.load();
    if (mounted) setState(() => _state = result);
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return switch (s) {
      null || DataLoading<T>() => widget.compact
          ? const Padding(
              padding: EdgeInsets.all(XSpace.s16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : const LoadingIndicatorView(),
      DataSuccess<T>(:final value) => widget.builder(context, value, _reload),
      DataEmpty<T>() => widget.empty ?? const SizedBox.shrink(),
      DataFailed<T>(:final failure) when failure.isApiPending =>
        widget.pending?.call(failure) ??
            ApiPendingCard(message: failure.message),
      DataFailed<T>(:final failure) =>
        ErrorStateView(error: failure, onRetry: _reload),
    };
  }
}

/// Feedback for an action run against sample data.
void showDemoActionResult(
  BuildContext context,
  DataError? error,
  String done,
) {
  if (error != null) {
    showErrorSnackBar(context, error);
    return;
  }
  showSuccessSnackBar(
    context,
    AppConfig.demoData ? '$done (simulasi — belum tersambung ke server)' : done,
  );
}
