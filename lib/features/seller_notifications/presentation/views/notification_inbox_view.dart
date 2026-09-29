import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/data_state.dart';
import '../../../../core/domain/model/notification/app_notification.dart';
import '../../../../core/domain/repositories/staff_repository.dart';
import '../../../../di/injector.dart';
import '../../../../core/function/custom_app_bar.dart';
import '../../../../core/utils/constant.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../seller_home/presentation/views/widgets/section_card.dart';
import '../cubits/notification_cubit/notification_cubit.dart';
import 'widgets/notification_preferences_sheet.dart';
import '../../../../core/utils/xpedia_tokens.dart';

/// The account's notifications.
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

class _NotificationInboxBody extends StatelessWidget {
  const _NotificationInboxBody();

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
        title: const Text('Terima undangan staf?'),
        content: const Text(
          'Anda akan bergabung sebagai staf toko ini dengan peran yang '
          'ditetapkan pemiliknya.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Terima'),
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
      appBar: customAppBar(
        context,
        'Notifikasi',
        action: Builder(
          builder: (context) => IconButton(
            tooltip: 'Pengaturan notifikasi',
            icon: const Icon(Icons.tune_rounded, size: 20),
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
      ),
      body: SafeArea(
        child: BlocBuilder<NotificationCubit, NotificationState>(
          builder: (context, state) => switch (state) {
            NotificationInProgress() => const LoadingIndicatorView(),
            NotificationFailure(:final error) => ErrorStateView(
                error: error,
                onRetry: () => NotificationCubit.get(context).load(),
              ),
            NotificationLoaded() => _content(context, state),
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, NotificationLoaded state) {
    if (state.notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => NotificationCubit.get(context).load(),
        child: ListView(
          children: <Widget>[
            SizedBox(height: context.screenHeight * 0.15),
            const EmptyStateView(
              icon: Icons.notifications_none_rounded,
              message: 'Belum ada notifikasi. Pesanan baru yang masuk akan '
                  'muncul di sini.',
            ),
          ],
        ),
      );
    }

    return Column(
      children: <Widget>[
        if (state.hasUnread)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${state.unreadCount} belum dibaca',
                    style: XText.bodySPrimary.copyWith(color: kLightThirdColor),
                  ),
                ),
                TextButton(
                  onPressed: state.isBusy
                      ? null
                      : () => NotificationCubit.get(context).markAllRead(),
                  child: const Text('Tandai semua dibaca'),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => NotificationCubit.get(context).load(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: state.notifications.length + (state.hasMore ? 1 : 0),
              separatorBuilder: (_, __) => 12.sbh,
              itemBuilder: (context, index) {
                if (index == state.notifications.length) {
                  return Center(
                    child: TextButton(
                      onPressed: state.isBusy
                          ? null
                          : () => NotificationCubit.get(context).loadMore(),
                      child: Text(
                        state.isBusy ? 'Memuat…' : 'Muat lebih banyak',
                      ),
                    ),
                  );
                }

                final notification = state.notifications[index];
                return _NotificationCard(
                  notification: notification,
                  onTap: () => _open(context, notification),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return SectionCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              // The only affordance that says "new" — the payload has no
              // priority or severity to render.
              color: isUnread ? kLightPrimaryColor : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
          12.sbw,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  notification.title,
                  style: isUnread ? XText.labelL : XText.bodyM,
                ),
                if (notification.body != null) ...<Widget>[
                  4.sbh,
                  Text(
                    notification.body!,
                    style: XText.bodySPrimary.copyWith(color: kLightThirdColor),
                  ),
                ],
                6.sbh,
                Text(
                  <String>[
                    NotificationType.label(notification.type),
                    formatDateTime(notification.createdAt),
                  ].join(' · '),
                  style: XText.caption.copyWith(color: kLightThirdColor),
                ),
              ],
            ),
          ),
          if (notification.isAboutOrder) ...<Widget>[
            8.sbw,
            const Icon(Icons.chevron_right, size: 18),
          ],
        ],
      ),
    );
  }
}
