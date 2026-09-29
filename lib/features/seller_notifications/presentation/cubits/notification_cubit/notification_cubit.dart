import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/data_state.dart';
import '../../../../../core/domain/model/notification/app_notification.dart';
import '../../../../../core/domain/model/notification/notification_preference.dart';
import '../../../../../core/domain/repositories/notification_repository.dart';
import '../../../../../di/injector.dart';

part 'notification_state.dart';

/// The account's notification inbox.
///
/// Per user rather than per store, so switching the active store does not
/// change what is listed here — the cubit deliberately does not read
/// `activeStoreId` at all.
class NotificationCubit extends Cubit<NotificationState> {
  NotificationCubit() : super(const NotificationInProgress());

  static NotificationCubit get(BuildContext context) =>
      BlocProvider.of(context);

  final NotificationRepository _notifications =
      injector<NotificationRepository>();

  /// The server pages at twenty and sends no `meta`, so the only way to know
  /// there is more is that the last page came back full.
  static const int _pageSize = 20;

  Future<void> load() async {
    if (isClosed) return;
    emit(const NotificationInProgress());

    final result = await _notifications.getNotifications(page: 1);
    if (isClosed) return;

    switch (result) {
      case DataSuccess<List<AppNotification>>(:final value):
        emit(NotificationLoaded(
          notifications: value,
          hasMore: value.length >= _pageSize,
        ));
      case DataEmpty<List<AppNotification>>():
        emit(const NotificationLoaded(notifications: <AppNotification>[]));
      case DataFailed<List<AppNotification>>(:final failure):
        emit(NotificationFailure(failure));
      default:
        emit(const NotificationFailure(
          DataError(
            code: DataErrorCode.unexpected,
            message: 'Notifikasi tidak bisa dibaca.',
          ),
        ));
    }
  }

  /// Appends the next page. A page that comes back short is the end.
  Future<void> loadMore() async {
    final current = state;
    if (current is! NotificationLoaded || current.isBusy || !current.hasMore) {
      return;
    }

    emit(current.copyWith(isBusy: true));
    final nextPage = current.page + 1;
    final result = await _notifications.getNotifications(page: nextPage);
    if (isClosed) return;

    switch (result) {
      case DataSuccess<List<AppNotification>>(:final value):
        emit(current.copyWith(
          notifications: <AppNotification>[...current.notifications, ...value],
          page: nextPage,
          hasMore: value.length >= _pageSize,
          isBusy: false,
        ));
      case DataEmpty<List<AppNotification>>():
        emit(current.copyWith(hasMore: false, isBusy: false));
      default:
        emit(current.copyWith(isBusy: false));
    }
  }

  /// Marking read re-reads page one, so anything loaded past it is dropped —
  /// acceptable, because the rows that matter are the newest.
  Future<void> markRead(int notificationId) async {
    final current = state;
    if (current is! NotificationLoaded) return;

    emit(current.copyWith(isBusy: true));
    final result = await _notifications.markRead(notificationId);
    if (isClosed) return;
    _applyInbox(result, current);
  }

  Future<void> markAllRead() async {
    final current = state;
    if (current is! NotificationLoaded) return;

    emit(current.copyWith(isBusy: true));
    final result = await _notifications.markAllRead();
    if (isClosed) return;
    _applyInbox(result, current);
  }

  void _applyInbox(
    DataState<List<AppNotification>> result,
    NotificationLoaded previous,
  ) {
    switch (result) {
      case DataSuccess<List<AppNotification>>(:final value):
        emit(NotificationLoaded(
          notifications: value,
          hasMore: value.length >= _pageSize,
        ));
      case DataEmpty<List<AppNotification>>():
        emit(const NotificationLoaded(notifications: <AppNotification>[]));
      default:
        emit(previous.copyWith(isBusy: false));
    }
  }

  // ----------------------------------------------------------- preferences

  Future<List<NotificationPreference>> preferences() async {
    final result = await _notifications.getPreferences();
    return switch (result) {
      DataSuccess<List<NotificationPreference>>(:final value) => value,
      _ => const <NotificationPreference>[],
    };
  }

  /// Sets one switch and returns the list as it stands afterwards. The
  /// endpoint takes a single triple, so a screen flipping several sends
  /// several requests — there is no bulk form.
  Future<(DataError?, List<NotificationPreference>)> setPreference({
    required String type,
    required String channel,
    required bool isEnabled,
  }) async {
    final result = await _notifications.setPreference(
      type: type,
      channel: channel,
      isEnabled: isEnabled,
    );

    return switch (result) {
      DataSuccess<List<NotificationPreference>>(:final value) => (null, value),
      DataEmpty<List<NotificationPreference>>() => (
          null,
          const <NotificationPreference>[]
        ),
      DataFailed<List<NotificationPreference>>(:final failure) => (
          failure,
          const <NotificationPreference>[]
        ),
      _ => (null, const <NotificationPreference>[]),
    };
  }
}
