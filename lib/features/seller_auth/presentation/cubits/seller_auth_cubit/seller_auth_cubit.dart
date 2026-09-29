import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/data_state.dart';
import '../../../../../core/domain/model/auth/auth_session.dart';
import '../../../../../core/domain/repositories/auth_repository.dart';
import '../../../../../di/injector.dart';

part 'seller_auth_state.dart';

/// Login and registration.
///
/// The action methods return the failure rather than emitting an error state:
/// the view needs to react once (a snackbar, and navigation on success), not
/// rebuild into an error screen that would throw away what was typed.
class SellerAuthCubit extends Cubit<SellerAuthState> {
  SellerAuthCubit() : super(const SellerAuthIdle());

  static SellerAuthCubit get(BuildContext context) => BlocProvider.of(context);

  final AuthRepository _authRepository = injector<AuthRepository>();

  bool get isBusy => state is SellerAuthInProgress;

  Future<DataError?> login({
    required String email,
    required String password,
  }) async {
    emit(const SellerAuthInProgress());
    final result =
        await _authRepository.login(email: email, password: password);
    if (isClosed) return null;

    switch (result) {
      case DataSuccess<AuthSession>(:final value):
        emit(SellerAuthSuccess(value));
        return null;
      case DataFailed<AuthSession>(:final failure):
        emit(const SellerAuthIdle());
        return _explainRateLimit(failure);
      default:
        emit(const SellerAuthIdle());
        return const DataError(
          code: DataErrorCode.unexpected,
          message: 'Server tidak mengembalikan sesi.',
        );
    }
  }

  /// Login is throttled at five attempts per email and twenty per IP, both
  /// over fifteen minutes, and **a successful login counts too** — the check
  /// runs before the password is verified and records every call. The server's
  /// own wording is "coba lagi beberapa saat lagi", which does not say how
  /// long, so the window is named here instead.
  DataError _explainRateLimit(DataError failure) {
    if (failure.code != DataErrorCode.tooManyRequests) return failure;
    return DataError(
      code: failure.code,
      message: 'Terlalu banyak percobaan masuk. Tunggu sekitar 15 menit '
          'sebelum mencoba lagi.',
      details: failure.details,
    );
  }

  /// Registration does not produce a session: the account must verify its
  /// email first. A dev build returns the verification token inline, so this
  /// completes the whole chain — register, verify, log in — in one step rather
  /// than stranding the user at a mailbox that does not exist.
  Future<DataError?> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    emit(const SellerAuthInProgress());

    final registered = await _authRepository.register(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
    );
    if (isClosed) return null;

    if (registered is DataFailed<RegistrationResult>) {
      emit(const SellerAuthIdle());
      return registered.failure;
    }
    if (registered is! DataSuccess<RegistrationResult>) {
      emit(const SellerAuthIdle());
      return const DataError(
        code: DataErrorCode.unexpected,
        message: 'Server tidak mengembalikan akun yang dibuat.',
      );
    }

    final token = registered.value.devVerificationToken;
    if (token == null || token.isEmpty) {
      emit(const SellerAuthIdle());
      return const DataError(
        code: 'EMAIL_VERIFICATION_REQUIRED',
        message: 'Akun dibuat. Cek email untuk tautan verifikasi, lalu masuk.',
      );
    }

    final verified = await _authRepository.verifyEmail(token);
    if (isClosed) return null;
    if (verified is DataFailed<bool>) {
      emit(const SellerAuthIdle());
      return verified.failure;
    }

    return login(email: email, password: password);
  }
}
