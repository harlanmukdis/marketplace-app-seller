import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/live/live_session.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/live_cubit.dart';

/// "Live Selling Toko" (S-36) — the session list.
///
/// Only sessions created on this device appear: the API has no endpoint that
/// lists a store's sessions, so their ids are remembered locally.
class LiveListView extends StatelessWidget {
  const LiveListView({super.key});

  Future<void> _create(BuildContext context) async {
    final cubit = LiveListCubit.get(context);
    final draft = await showModalBottomSheet<(String, DateTime?)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateSheet(),
    );
    if (draft == null || !context.mounted) return;
    final (error, session) = await cubit.create(draft.$1, draft.$2);
    if (!context.mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    if (session != null) {
      await context.push(SellerRoutes.liveSessionPath(session.id));
      if (context.mounted) await cubit.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LiveListCubit>(
      create: (_) => LiveListCubit()..load(),
      child: BlocBuilder<LiveListCubit, LiveListState>(
        builder: (context, s) => Scaffold(
          backgroundColor: XColors.canvas,
          appBar: const XAppBar(title: 'Live Selling'),
          body: s.loading
              ? const LoadingIndicatorView()
              : RefreshIndicator(
                  onRefresh: LiveListCubit.get(context).load,
                  child: ListView(
                    padding: const EdgeInsets.all(XSpace.screen),
                    children: <Widget>[
                      const XBanner(
                        tone: XTone.info,
                        icon: Icons.videocam_outlined,
                        message: 'Siarkan dari OBS atau encoder lain memakai '
                            'RTMP & stream key yang muncul saat sesi dimulai. '
                            'Pin produk agar pembeli bisa langsung checkout.',
                      ),
                      const SizedBox(height: XSpace.cardGap),
                      if (s.sessions.isEmpty)
                        const XEmptyState(
                          icon: Icons.live_tv_outlined,
                          title: 'Belum ada sesi live',
                          message: 'Sesi yang dibuat dari perangkat ini '
                              'muncul di sini.',
                        )
                      else
                        for (final session in s.sessions) ...<Widget>[
                          _SessionCard(session: session),
                          const SizedBox(height: XSpace.cardGap),
                        ],
                    ],
                  ),
                ),
          bottomNavigationBar: Material(
            color: XColors.surface,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(XSpace.screen),
                child: XButton(
                  label: 'Jadwalkan Live',
                  icon: Icons.video_call_outlined,
                  size: XButtonSize.large,
                  expand: true,
                  loading: s.creating,
                  onPressed: () => _create(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

XTone liveTone(String status) => switch (status) {
      LiveStatus.live => XTone.danger,
      LiveStatus.scheduled => XTone.info,
      _ => XTone.neutral,
    };

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final LiveSession session;

  @override
  Widget build(BuildContext context) {
    return XCard(
      onTap: () async {
        await context.push(SellerRoutes.liveSessionPath(session.id));
        if (context.mounted) await LiveListCubit.get(context).load();
      },
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: liveTone(session.status).background,
              borderRadius: BorderRadius.circular(XRadius.md),
            ),
            child: Icon(
              session.isLive ? Icons.sensors_rounded : Icons.live_tv_outlined,
              color: liveTone(session.status).foreground,
            ),
          ),
          const SizedBox(width: XSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(session.title, style: XText.titleM),
                Text(
                  session.isLive
                      ? 'Mulai ${formatDateTime(session.startedAt)}'
                      : session.isOver
                          ? 'Selesai ${formatDateTime(session.endedAt)}'
                          : session.scheduledAt == null
                              ? 'Belum dijadwalkan'
                              : 'Jadwal ${formatDateTime(session.scheduledAt)}',
                  style: XText.bodyS,
                ),
                Text('${session.products.length} produk', style: XText.caption),
              ],
            ),
          ),
          XChip(
            label: LiveStatus.label(session.status),
            tone: liveTone(session.status),
          ),
        ],
      ),
    );
  }
}

class _CreateSheet extends StatefulWidget {
  const _CreateSheet();

  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  final TextEditingController _title = TextEditingController();
  DateTime? _at;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() => _at =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(XSpace.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Sesi Live Baru', style: XText.headingM),
              const SizedBox(height: XSpace.s12),
              TextField(
                controller: _title,
                maxLength: 200,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Judul live *'),
              ),
              XListGroup(
                children: <Widget>[
                  XListRow(
                    icon: Icons.event_outlined,
                    title: 'Jadwal',
                    subtitle:
                        _at == null ? 'Opsional' : formatDateTime(_at),
                    onTap: _pickTime,
                  ),
                ],
              ),
              const SizedBox(height: XSpace.s16),
              XButton(
                label: 'Buat Sesi',
                size: XButtonSize.large,
                expand: true,
                onPressed: _title.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(context).pop((_title.text.trim(), _at)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
