import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data_state.dart';
import '../../../../core/domain/model/catalog/product.dart';
import '../../../../core/domain/model/live/live_session.dart';
import '../../../../core/domain/model/promotion/store_voucher.dart';
import '../../../../core/domain/repositories/auth_repository.dart';
import '../../../../core/domain/repositories/catalog_repository.dart';
import '../../../../core/domain/repositories/live_repository.dart';
import '../../../../core/domain/repositories/promotion_repository.dart';
import '../../../../di/injector.dart';

/// The store's live sessions — the ones this device created, because the
/// API has no list (`GET /stores/{id}/live-sessions` answers 405).
class LiveListState {
  const LiveListState({
    this.loading = true,
    this.sessions = const <LiveSession>[],
    this.creating = false,
  });

  final bool loading;
  final List<LiveSession> sessions;
  final bool creating;
}

class LiveListCubit extends Cubit<LiveListState> {
  LiveListCubit() : super(const LiveListState());

  static LiveListCubit get(BuildContext context) => BlocProvider.of(context);

  final LiveRepository _live = injector<LiveRepository>();

  int? get _storeId => injector<AuthRepository>().activeStoreId;

  Future<void> load() async {
    final storeId = _storeId;
    if (storeId == null) {
      emit(const LiveListState(loading: false));
      return;
    }
    emit(LiveListState(sessions: state.sessions));
    final ids = _live.rememberedSessionIds(storeId);
    final results = await Future.wait(ids.take(20).map(_live.get));
    if (isClosed) return;
    emit(LiveListState(
      loading: false,
      sessions: <LiveSession>[
        for (final r in results)
          if (r is DataSuccess<LiveSession>) r.value,
      ],
    ));
  }

  Future<(DataError?, LiveSession?)> create(
    String title,
    DateTime? scheduledAt,
  ) async {
    final storeId = _storeId;
    if (storeId == null || title.trim().isEmpty) {
      return (
        const DataError(
          code: 'VALIDATION_ERROR',
          message: 'Judul live wajib diisi.',
        ),
        null,
      );
    }
    emit(LiveListState(
        loading: false, sessions: state.sessions, creating: true));
    final result = await _live.create(
      storeId,
      title: title.trim(),
      scheduledAt: scheduledAt,
    );
    if (isClosed) return (null, null);
    if (result is DataSuccess<LiveSession>) {
      emit(LiveListState(
        loading: false,
        sessions: <LiveSession>[result.value, ...state.sessions],
      ));
      return (null, result.value);
    }
    emit(LiveListState(loading: false, sessions: state.sessions));
    return (
      result is DataFailed<LiveSession> ? result.failure : null,
      null,
    );
  }
}

class LiveSessionState {
  const LiveSessionState({
    this.session,
    this.ingest,
    this.products = const <Product>[],
    this.vouchers = const <LiveVoucher>[],
    this.storeVouchers = const <StoreVoucher>[],
    this.nextSession,
    this.busy = false,
    this.error,
  });

  final LiveSession? session;

  /// Returned by `start`; kept so the encoder settings stay on screen.
  final LiveIngest? ingest;

  /// The store's catalogue, for names and the add-product picker.
  final List<Product> products;
  final List<LiveVoucher> vouchers;
  final List<StoreVoucher> storeVouchers;

  /// The store's next scheduled session other than this one, from the ids
  /// remembered on this device (the API cannot list sessions).
  final LiveSession? nextSession;
  final bool busy;
  final DataError? error;

  Product? productOf(int id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  LiveSessionState copyWith({
    LiveSession? session,
    LiveIngest? ingest,
    List<LiveVoucher>? vouchers,
    bool? busy,
  }) =>
      LiveSessionState(
        session: session ?? this.session,
        ingest: ingest ?? this.ingest,
        products: products,
        vouchers: vouchers ?? this.vouchers,
        storeVouchers: storeVouchers,
        nextSession: nextSession,
        busy: busy ?? this.busy,
        error: error,
      );
}

/// One session: start/end, stream credentials, products and pin, vouchers.
///
/// Every guard is client-side because the server checks none: start works on
/// an ended session (verified), products from any store can be added, and
/// duplicates are accepted.
class LiveSessionCubit extends Cubit<LiveSessionState> {
  LiveSessionCubit(this.sessionId) : super(const LiveSessionState());

  static LiveSessionCubit get(BuildContext context) => BlocProvider.of(context);

  final int sessionId;
  final LiveRepository _live = injector<LiveRepository>();

  Future<void> load() async {
    final storeId = injector<AuthRepository>().activeStoreId;
    final results = await Future.wait<Object>(<Future<Object>>[
      _live.get(sessionId),
      _live.getVouchers(sessionId),
      if (storeId != null)
        injector<CatalogRepository>().getStoreProducts(storeId),
      if (storeId != null)
        injector<PromotionRepository>().getStoreVouchers(storeId),
    ]);
    final next = storeId == null ? null : await _nextSession(storeId);
    if (isClosed) return;
    final session = results[0];
    final vouchers = results[1];
    final products = results.length > 2 ? results[2] : null;
    final storeVouchers = results.length > 3 ? results[3] : null;
    emit(LiveSessionState(
      session: session is DataSuccess<LiveSession> ? session.value : null,
      error: session is DataFailed<LiveSession> ? session.failure : null,
      ingest: state.ingest,
      vouchers: vouchers is DataSuccess<List<LiveVoucher>>
          ? vouchers.value
          : const <LiveVoucher>[],
      products: products is DataSuccess<List<Product>>
          ? products.value
          : const <Product>[],
      storeVouchers: storeVouchers is DataSuccess<List<StoreVoucher>>
          ? storeVouchers.value
          : const <StoreVoucher>[],
      nextSession: next,
    ));
  }

  Future<LiveSession?> _nextSession(int storeId) async {
    final ids = _live
        .rememberedSessionIds(storeId)
        .where((id) => id != sessionId)
        .take(10);
    final results = await Future.wait(ids.map(_live.get));
    final now = DateTime.now();
    LiveSession? next;
    for (final r in results) {
      if (r is! DataSuccess<LiveSession>) continue;
      final s = r.value;
      final at = s.scheduledAt;
      if (!s.canStart || at == null || at.isBefore(now)) continue;
      if (next == null || at.isBefore(next.scheduledAt!)) next = s;
    }
    return next;
  }

  Future<DataError?> start() async {
    final s = state.session;
    if (s == null || !s.canStart) {
      return const DataError(
        code: 'LIVE_STATE_INVALID',
        message: 'Hanya sesi terjadwal yang bisa dimulai.',
      );
    }
    emit(state.copyWith(busy: true));
    final result = await _live.start(sessionId);
    if (isClosed) return null;
    if (result is DataFailed<LiveIngest>) {
      emit(state.copyWith(busy: false));
      return result.failure;
    }
    final ingest = result is DataSuccess<LiveIngest> ? result.value : null;
    final refreshed = await _live.get(sessionId);
    if (isClosed) return null;
    emit(state.copyWith(
      busy: false,
      ingest: ingest,
      session: refreshed is DataSuccess<LiveSession> ? refreshed.value : null,
    ));
    return null;
  }

  Future<DataError?> end() => _sessionAction(
        guard: (s) => s.canEnd,
        refusal: 'Hanya sesi yang sedang live yang bisa diakhiri.',
        action: () => _live.end(sessionId),
      );

  Future<DataError?> addProduct(int productId, int? livePrice) =>
      _sessionAction(
        guard: (s) =>
            !s.isOver && !s.products.any((p) => p.productId == productId),
        refusal: 'Produk sudah ada di sesi ini, atau sesi sudah selesai.',
        action: () => _live.addProduct(sessionId,
            productId: productId, livePrice: livePrice),
      );

  Future<DataError?> pin(int productId) => _sessionAction(
        guard: (s) => s.isLive,
        refusal: 'Produk hanya bisa di-pin saat sesi sedang live.',
        action: () => _live.pin(sessionId, productId),
      );

  Future<DataError?> addVoucher(int voucherId, int quota) async {
    final s = state.session;
    if (s == null || s.isOver || quota <= 0) {
      return const DataError(
        code: 'VALIDATION_ERROR',
        message: 'Kuota wajib lebih dari 0 dan sesi belum selesai.',
      );
    }
    if (state.vouchers.any((v) => v.voucherId == voucherId)) {
      return const DataError(
        code: 'VALIDATION_ERROR',
        message: 'Voucher sudah ditambahkan ke sesi ini.',
      );
    }
    emit(state.copyWith(busy: true));
    final result =
        await _live.addVoucher(sessionId, voucherId: voucherId, quota: quota);
    if (isClosed) return null;
    if (result is DataFailed<List<LiveVoucher>>) {
      emit(state.copyWith(busy: false));
      return result.failure;
    }
    emit(state.copyWith(
      busy: false,
      vouchers: result is DataSuccess<List<LiveVoucher>> ? result.value : null,
    ));
    return null;
  }

  Future<DataError?> _sessionAction({
    required bool Function(LiveSession s) guard,
    required String refusal,
    required Future<DataState<LiveSession>> Function() action,
  }) async {
    final s = state.session;
    if (s == null || !guard(s)) {
      return DataError(code: 'LIVE_STATE_INVALID', message: refusal);
    }
    emit(state.copyWith(busy: true));
    final result = await action();
    if (isClosed) return null;
    if (result is DataFailed<LiveSession>) {
      emit(state.copyWith(busy: false));
      return result.failure;
    }
    emit(state.copyWith(
      busy: false,
      session: result is DataSuccess<LiveSession> ? result.value : null,
    ));
    return null;
  }
}
