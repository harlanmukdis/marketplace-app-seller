/// Result wrapper returned by every repository method.
///
/// Repositories never throw (CLAUDE.md, "Repositories never throw") — they
/// catch, translate, and hand back one of these. Cubits pattern-match on the
/// variant instead of using try/catch for control flow.
sealed class DataState<T> {
  const DataState({this.data, this.error});

  final T? data;
  final DataError? error;
}

/// In flight. Repositories do not return this; cubits emit it before awaiting.
final class DataLoading<T> extends DataState<T> {
  const DataLoading();
}

final class DataSuccess<T> extends DataState<T> {
  const DataSuccess(T data) : super(data: data);

  T get value => data as T;
}

/// The call succeeded but there is nothing to show — an empty collection, or a
/// `200` carrying `data: null` (which several endpoints do instead of 404).
final class DataEmpty<T> extends DataState<T> {
  const DataEmpty();
}

final class DataFailed<T> extends DataState<T> {
  const DataFailed(DataError error) : super(error: error);

  DataError get failure => error!;
}

/// A failure the UI can act on.
///
/// [code] is the backend's `error.code` (`VALIDATION_ERROR`,
/// `GATES_NOT_PASSED`, …) and [details] its `error.details`, which for several
/// endpoints is the only place that says *which* field or gate failed. Both are
/// carried all the way to the screen on purpose — the API doc is explicit that
/// generic error messages are not good enough here.
class DataError {
  const DataError({
    required this.code,
    required this.message,
    this.details,
    this.statusCode,
  });

  final String code;
  final String message;
  final Map<String, dynamic>? details;
  final int? statusCode;

  /// Last-resort wrapper for anything that is not already an [ApiException],
  /// e.g. a bug in a `fromJson`.
  factory DataError.unexpected(Object error) => DataError(
        code: DataErrorCode.unexpected,
        message: error.toString(),
      );

  /// The screen exists but its endpoint does not yet — see
  /// `lib/core/data/demo/`. Rendered as "Menunggu API", never as a failure.
  factory DataError.apiPending(String feature) => DataError(
        code: DataErrorCode.apiPending,
        message: '$feature belum tersedia — menunggu API dari backend.',
      );

  bool get isApiPending => code == DataErrorCode.apiPending;

  bool get isUnauthenticated => code == DataErrorCode.unauthenticated;

  bool get isNoSellerContext => code == DataErrorCode.noSellerContext;

  /// Either flavour of "you cannot do this", so callers do not have to know
  /// which permission layer refused.
  bool get isForbidden =>
      code == DataErrorCode.forbidden || code == DataErrorCode.permissionDenied;

  /// `error.details.missing` on a 422, when present.
  List<String> get missingFields {
    final missing = details?['missing'];
    if (missing is List) {
      return missing.map((e) => e.toString()).toList(growable: false);
    }
    return const <String>[];
  }

  @override
  String toString() => 'DataError($code, $message)';
}

/// Error codes the app branches on. Documented in API doc 1.5; anything not
/// listed here still arrives intact in [DataError.code].
abstract class DataErrorCode {
  /// Client-side: a feature built ahead of its endpoint (see
  /// [DataError.apiPending]).
  static const String apiPending = 'API_PENDING';
  static const String malformedJson = 'MALFORMED_JSON';
  static const String unauthenticated = 'UNAUTHENTICATED';
  static const String forbidden = 'FORBIDDEN';

  /// From the v2.2 group+menu permission system. Distinct from [forbidden],
  /// which means "not yours"; this means "your group is not allowed here".
  /// Both are dead ends for the user, so the UI treats them the same.
  static const String permissionDenied = 'PERMISSION_DENIED';
  static const String noSellerContext = 'NO_SELLER_CONTEXT';
  static const String notFound = 'NOT_FOUND';
  static const String methodNotAllowed = 'METHOD_NOT_ALLOWED';
  static const String invalidTransition = 'INVALID_TRANSITION';
  static const String invalidState = 'INVALID_STATE';
  static const String conflict = 'CONFLICT';
  static const String validationError = 'VALIDATION_ERROR';

  /// Added with the v1.2.0 security audit: the auth endpoints are throttled.
  /// Login allows five attempts per email and twenty per IP over fifteen
  /// minutes, and the counter is incremented **before** the password is
  /// checked — so successful logins count against it as well.
  static const String tooManyRequests = 'TOO_MANY_REQUESTS';
  static const String gatesNotPassed = 'GATES_NOT_PASSED';
  static const String dbError = 'DB_ERROR';

  // v2.4 field-constraint rules (Addendum 1.2).

  /// Total weight exceeds the chosen vehicle's payload (OPS-01).
  static const String fleetPayloadExceeded = 'FLEET_PAYLOAD_EXCEEDED';

  /// Vehicle too large for the delivery address's declared access (FLD-02).
  static const String fleetAccessBlocked = 'FLEET_ACCESS_BLOCKED';

  /// Sample SKUs are capped at 2 pcs per transaction (ORD-16).
  static const String sampleQtyExceeded = 'SAMPLE_QTY_EXCEEDED';

  /// Returned goods cannot be restocked yet (FLD-04); the message says how
  /// many days remain.
  static const String restockWindowNotReached = 'RESTOCK_WINDOW_NOT_REACHED';

  /// This shipment carried no packaging deposit (FLD-07).
  static const String noPackagingDeposit = 'NO_PACKAGING_DEPOSIT';

  static const String alreadyConfirmed = 'ALREADY_CONFIRMED';

  /// The account was suspended — five chat filter violations will do it
  /// (OPS-04), and a suspended account cannot log in.
  static const String accountSuspended = 'ACCOUNT_SUSPENDED';

  /// Client-side only.
  static const String network = 'NETWORK_ERROR';
  static const String timeout = 'TIMEOUT';
  static const String parse = 'PARSE_ERROR';
  static const String unexpected = 'UNEXPECTED';
}
