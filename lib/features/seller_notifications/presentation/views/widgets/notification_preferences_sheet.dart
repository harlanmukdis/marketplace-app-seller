import 'package:flutter/material.dart';

import '../../../../../core/data_state.dart';
import '../../../../../core/domain/model/notification/app_notification.dart';
import '../../../../../core/domain/model/notification/notification_preference.dart';
import '../../../../../core/utils/constant.dart';
import '../../../../../core/utils/extensions.dart';
import '../../../../../core/widgets/state_widgets.dart';
import '../../../../../core/utils/xpedia_tokens.dart';

Future<void> showNotificationPreferencesSheet(
  BuildContext context, {
  required Future<List<NotificationPreference>> Function() load,
  required Future<(DataError?, List<NotificationPreference>)> Function({
    required String type,
    required String channel,
    required bool isEnabled,
  }) setPreference,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _PreferencesSheet(load: load, setPreference: setPreference),
    );

/// Mute switches, per notification type and channel.
///
/// Two things shape this screen. First, the list of types is **derived from
/// what the account has already received** — the server reads it off the
/// inbox — so it is empty for a seller who has had no orders yet, and that
/// has to read as "nothing to configure yet" rather than as a failure.
/// Second, `in_app` is absent on purpose: the server refuses to mute it
/// because it is this app's own inbox and doubles as the history.
class _PreferencesSheet extends StatefulWidget {
  const _PreferencesSheet({required this.load, required this.setPreference});

  final Future<List<NotificationPreference>> Function() load;
  final Future<(DataError?, List<NotificationPreference>)> Function({
    required String type,
    required String channel,
    required bool isEnabled,
  }) setPreference;

  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  List<NotificationPreference>? _preferences;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final preferences = await widget.load();
    if (!mounted) return;
    setState(() => _preferences = preferences);
  }

  Future<void> _toggle(
    NotificationPreference preference,
    String channel,
    bool value,
  ) async {
    // Flip locally first: the endpoint sets one switch per request, and
    // waiting on a round trip per tap makes a row of switches feel broken.
    setState(() {
      _isBusy = true;
      _preferences = <NotificationPreference>[
        for (final entry in _preferences ?? <NotificationPreference>[])
          if (entry.type == preference.type)
            entry.withChannel(channel, value)
          else
            entry,
      ];
    });

    final (error, updated) = await widget.setPreference(
      type: preference.type,
      channel: channel,
      isEnabled: value,
    );
    if (!mounted) return;

    setState(() {
      _isBusy = false;
      if (updated.isNotEmpty) _preferences = updated;
    });

    if (error != null) {
      showErrorSnackBar(context, error);
      // The optimistic flip was wrong, so take the server's word for it.
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = _preferences;

    return SafeArea(
      child: Padding(
        padding: 20.pa,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Pengaturan notifikasi', style: XText.headingM),
            4.sbh,
            Text(
              'Mematikan sebuah channel hanya menghentikan kiriman ke luar. '
              'Notifikasi tetap masuk ke daftar di aplikasi ini — itu '
              'sekaligus riwayatnya, dan server tidak mengizinkannya dimatikan.',
              style: XText.caption.copyWith(color: kLightThirdColor),
            ),
            16.sbh,
            if (preferences == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: LoadingIndicatorView(),
              )
            else if (preferences.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EmptyStateView(
                  icon: Icons.tune_outlined,
                  message: 'Belum ada yang bisa diatur. Pilihannya muncul '
                      'setelah jenis notifikasi itu pernah diterima.',
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: preferences.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final preference = preferences[index];
                    return _PreferenceGroup(
                      preference: preference,
                      isBusy: _isBusy,
                      onToggle: (channel, value) =>
                          _toggle(preference, channel, value),
                    );
                  },
                ),
              ),
            12.sbh,
          ],
        ),
      ),
    );
  }
}

class _PreferenceGroup extends StatelessWidget {
  const _PreferenceGroup({
    required this.preference,
    required this.isBusy,
    required this.onToggle,
  });

  final NotificationPreference preference;
  final bool isBusy;
  final void Function(String channel, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          NotificationType.label(preference.type),
          style: XText.labelL,
        ),
        if (preference.isFullyMuted) ...<Widget>[
          4.sbh,
          Text(
            'Semua channel luar dimatikan — tetap masuk ke daftar di aplikasi.',
            style: XText.caption.copyWith(color: kWarningColor),
          ),
        ],
        8.sbh,
        for (final channel in NotificationChannel.mutable)
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              NotificationChannel.label(channel),
              style: XText.bodyM,
            ),
            value: preference.isEnabled(channel),
            onChanged: isBusy ? null : (value) => onToggle(channel, value),
          ),
      ],
    );
  }
}
