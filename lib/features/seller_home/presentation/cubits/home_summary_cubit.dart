import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data_state.dart';
import '../../../../core/domain/model/notification/app_notification.dart';
import '../../../../core/domain/model/wallet/store_wallet.dart';
import '../../../../core/domain/repositories/auth_repository.dart';
import '../../../../core/domain/repositories/notification_repository.dart';
import '../../../../core/domain/repositories/wallet_repository.dart';
import '../../../../di/injector.dart';

/// What Beranda shows besides orders: the wallet balance and the newest
/// notifications. There is no dashboard endpoint on this backend, so each
/// tile is its own call; a failed tile shows a dash rather than failing the
/// whole screen.
class HomeSummary {
  const HomeSummary({
    this.wallet,
    this.notifications = const <AppNotification>[],
    this.loading = true,
  });

  final StoreWallet? wallet;
  final List<AppNotification> notifications;
  final bool loading;

  int get unread => notifications.where((n) => !n.isRead).length;
}

class HomeSummaryCubit extends Cubit<HomeSummary> {
  HomeSummaryCubit() : super(const HomeSummary());

  static HomeSummaryCubit get(BuildContext context) => BlocProvider.of(context);

  Future<void> load() async {
    if (isClosed) return;
    final storeId = injector<AuthRepository>().activeStoreId;
    emit(HomeSummary(
      wallet: state.wallet,
      notifications: state.notifications,
    ));

    final results = await Future.wait<Object?>(<Future<Object?>>[
      if (storeId != null)
        injector<WalletRepository>().getStoreWallet(storeId)
      else
        Future<Object?>.value(),
      injector<NotificationRepository>().getNotifications(page: 1),
    ]);
    if (isClosed) return;

    final wallet = results[0];
    final notifications = results[1];
    emit(HomeSummary(
      wallet: wallet is DataSuccess<StoreWallet> ? wallet.value : null,
      notifications: notifications is DataSuccess<List<AppNotification>>
          ? notifications.value
          : const <AppNotification>[],
      loading: false,
    ));
  }
}
