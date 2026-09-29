import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/data_state.dart';
import '../../../../core/domain/model/notification/app_notification.dart';
import '../../../../core/domain/repositories/staff_repository.dart';
import '../../../../di/injector.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/notification_cubit/notification_cubit.dart';
import 'widgets/notification_preferences_sheet.dart';

/// "Notifikasi Toko" (S-40): the account's notifications, grouped Kritis /
/// Operasional / Promosi & Info (see [NotificationCategory]).
///
/// **Per account, not per store.** An owner of several shops sees one stream,
/// and the payload carries nothing that says which shop a row belongs to — so
/// the screen does not pretend to filter by the active store.
///
/// Since v1.5.0 this is finally worth opening: a new order raises an
/// `order_new` notification to the store owner. Before that the order
/// lifecycle raised nothing at all and the only notification that ever
/// existed was a staff invitation.
class NotificationInboxView extends StatelessWidget {
  const NotificationInboxView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationCubit>(
      create: (_) => NotificationCubit()..load(),
      child: const _NotificationInboxBody(),
    );
  }
}

class _NotificationInboxBody extends StatefulWidget {
  const _NotificationInboxBody();

  @override
  State<_NotificationInboxBody> createState() => _NotificationInboxBodyState();
}

class _NotificationInboxBodyState extends State<_NotificationInboxBody> {
  NotificationCategory? _filter;

  Future<void> _open(BuildContext context, AppNotification notification) async {
    final cubit = NotificationCubit.get(context);
    if (!notification.isRead) await cubit.markRead(notification.id);
    if (!context.mounted) return;

    // `order_new` carries the order id; `staff_invitation` carries the token
    // that joins the inviting store.
    final orderId = notification.orderId;
    if (orderId != null) {
      await context.push(SellerRoutes.orderDetailPath(orderId));
      return;
    }
    final token = notification.invitationToken;
    if (token != null) await _acceptInvitation(context, token);
  }

  Future<void> _acceptInvitation(BuildContext context, String token) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Terima undangan staf?', style: XText.headingM),
        content: Text(
          'Anda akan bergabung sebagai staf toko ini dengan peran yang '
          'ditetapkan pemiliknya.',
          style: XText.bodyM,
        ),
        actions: <Widget>[
          XButton.ghost(
            label: 'Nanti',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          XButton(
            label: 'Terima',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final result = await injector<StaffRepository>().acceptInvitation(token);
    if (!context.mounted) return;
    if (result is DataFailed<void>) {
      showErrorSnackBar(context, result.failure);
      return;
    }
    // GET /stores lists only stores the account *owns*, so the store just
    // joined cannot be opened from this app yet — say so rather than imply it.
    showSuccessSnackBar(
      context,
      'Undangan diterima. Membuka toko sebagai staf belum didukung server.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: XAppBar(
        title: 'Notifikasi Toko',
        actions: <Widget>[
          Builder(
            builder: (context) => XIconAction(
              icon: Icons.tune_rounded,
              tooltip: 'Pengaturan notifikasi',
              onPressed: () {
                final cubit = NotificationCubit.get(context);
                showNotificationPreferencesSheet(
                  context,
                  load: cubit.preferences,
                  setPreference: cubit.setPreference,
                );
              },
            ),
          ),
        ],
      ),
      body: BlocBuilder<NotificationCubit, NotificationState>(
        builder: (context, state) => switch (state) {
          NotificationInProgress() => const LoadingIndicatorView(),
          NotificationFailure(:final error) => ErrorStateView(
              error: error,
              onRetry: () => NotificationCubit.get(context).load(),
            ),
          NotificationLoaded() => _content(context, state),
        },
      ),
    );
  }

  Widget _content(BuildContext context, NotificationLoaded state) {
    final all = state.notifications;
    final counts = <NotificationCategory, int>{
      for (final c in NotificationCategory.values)
        c: all.where((n) => n.category == c).length,
    };
    final groups = <NotificationCategory>[
      for (final c in NotificationCategory.values)
        if ((_filter == null || _filter == c) && counts[c]! > 0) c,
    ];

    return Column(
      children: <Widget>[
        Container(
          color: XColors.surface,
          padding: const EdgeInsets.fromLTRB(
              XSpace.screen, XSpace.s12, XSpace.screen, XSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _FilterPill(
                      label: 'Semua',
                      count: all.length,
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    for (final c in NotificationCategory.values)
                      _FilterPill(
                        label: c.label,
                        count: counts[c]!,
                        danger: c == NotificationCategory.critical,
                        selected: _filter == c,
                        onTap: () => setState(() => _filter = c),
                      ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: !state.hasUnread || state.isBusy
                      ? null
                      : () => NotificationCubit.get(context).markAllRead(),
                  icon: const Icon(Icons.done_all, size: 18),
                  label: Text(
                    state.hasUnread
                        ? 'Tandai Semua Sudah Dibaca (${state.unreadCount})'
                        : 'Semua sudah dibaca',
                    style: XText.labelM,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: XColors.borderSubtle),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => NotificationCubit.get(context).load(),
            child: all.isEmpty || groups.isEmpty
                ? ListView(
                    children: <Widget>[
                      const SizedBox(height: XSpace.s32),
                      XEmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: all.isEmpty
                            ? 'Belum ada notifikasi'
                            : 'Tidak ada notifikasi ${_filter!.label}',
                        message: all.isEmpty
                            ? 'Pesanan baru yang masuk akan muncul di sini.'
                            : null,
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                        XSpace.screen, XSpace.s12, XSpace.screen, XSpace.s32),
                    children: <Widget>[
                      for (final c in groups) ...<Widget>[
                        _GroupHeader(category: c, count: counts[c]!),
                        for (final n
                            in all.where((n) => n.category == c)) ...<Widget>[
                          _NotificationCard(
                            notification: n,
                            onTap: () => _open(context, n),
                          ),
                          const SizedBox(height: XSpace.s12),
                        ],
                        const SizedBox(height: XSpace.s8),
                      ],
                      if (state.hasMore)
                        Center(
                          child: XButton.secondary(
                            label:
                                state.isBusy ? 'Memuat…' : 'Muat lebih banyak',
                            onPressed: state.isBusy
                                ? null
                                : () =>
                                    NotificationCubit.get(context).loadMore(),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(XSpace.s16),
                          child: Column(
                            children: <Widget>[
                              Icon(Icons.assignment_turned_in_outlined,
                                  color: XColors.textTertiary),
                              const SizedBox(height: XSpace.s4),
                              Text(
                                'Semua notifikasi sudah ditampilkan.',
                                textAlign: TextAlign.center,
                                style: XText.bodyS,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final int count;
  final bool selected;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? XColors.textOnBrand : XColors.textSecondary;
    final badgeBg = selected
        ? Colors.white.withValues(alpha: 0.25)
        : danger && count > 0
            ? XColors.danger
            : XColors.borderSubtle;
    final badgeFg = selected || (danger && count > 0)
        ? XColors.textOnBrand
        : XColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(right: XSpace.s8),
      child: Material(
        color: selected ? XColors.primary : XColors.sunken,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: XSpace.s12,
              vertical: XSpace.s8,
            ),
            child: Row(
              children: <Widget>[
                Text(label, style: XText.labelL.copyWith(color: fg)),
                const SizedBox(width: XSpace.s8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(XRadius.full),
                  ),
                  child: Text(
                    '$count',
                    style: XText.labelS.copyWith(color: badgeFg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.category, required this.count});

  final NotificationCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    final critical = category == NotificationCategory.critical;
    final color = critical ? XColors.dangerStrong : XColors.textTertiary;
    return Padding(
      padding: const EdgeInsets.only(bottom: XSpace.s8),
      child: Row(
        children: <Widget>[
          if (critical) ...<Widget>[
            Icon(Icons.circle, size: 8, color: XColors.danger),
            const SizedBox(width: XSpace.s4),
          ],
          Expanded(
            child: Text(
              category.heading.toUpperCase(),
              style: XText.overline.copyWith(color: color),
            ),
          ),
          Text('$count', style: XText.labelS.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  static String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Baru saja';
    if (d.inMinutes < 60) return '${d.inMinutes} menit lalu';
    if (d.inHours < 24) return '${d.inHours} jam lalu';
    if (d.inDays == 1) return 'Kemarin';
    return formatDate(t);
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final isUnread = !n.isRead;
    final (IconData icon, XTone tone) = switch (n.type) {
      NotificationType.orderNew || NotificationType.orderPaid => (
          Icons.inventory_2_outlined,
          XTone.success
        ),
      NotificationType.staffInvitation => (
          Icons.group_add_outlined,
          XTone.info
        ),
      _ => switch (n.category) {
          NotificationCategory.critical => (Icons.timer_outlined, XTone.danger),
          NotificationCategory.operational => (
              Icons.storefront_outlined,
              XTone.warning
            ),
          NotificationCategory.info => (Icons.campaign_outlined, XTone.info),
        },
    };
    final action = n.isAboutOrder
        ? 'Lihat Pesanan'
        : n.invitationToken != null
            ? 'Terima Undangan'
            : null;

    return Material(
      color:
          isUnread ? XColors.surface : XColors.surface.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(XRadius.md),
        side: BorderSide(
          color: isUnread
              ? XColors.primary.withValues(alpha: 0.35)
              : XColors.borderSubtle,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(XSpace.card),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tone.background,
                  borderRadius: BorderRadius.circular(XRadius.md),
                ),
                child: Icon(icon, size: 20, color: tone.foreground),
              ),
              const SizedBox(width: XSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            NotificationType.label(n.type).toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                XText.overline.copyWith(color: tone.foreground),
                          ),
                        ),
                        Text(_ago(n.createdAt), style: XText.caption),
                        if (isUnread) ...<Widget>[
                          const SizedBox(width: XSpace.s4),
                          Icon(Icons.circle, size: 8, color: XColors.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.title,
                      style: isUnread
                          ? XText.titleM
                          : XText.titleM.copyWith(
                              color: XColors.textSecondary,
                            ),
                    ),
                    if (n.body != null) ...<Widget>[
                      const SizedBox(height: XSpace.s4),
                      Text(n.body!, style: XText.bodyS),
                    ],
                    if (action != null) ...<Widget>[
                      const SizedBox(height: XSpace.s8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: XButton(
                          label: action,
                          size: XButtonSize.small,
                          onPressed: onTap,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
