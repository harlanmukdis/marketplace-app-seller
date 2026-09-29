part of 'verification_cubit.dart';

sealed class VerificationState {
  const VerificationState();
}

final class VerificationInProgress extends VerificationState {
  const VerificationInProgress();
}

final class VerificationNoStore extends VerificationState {
  const VerificationNoStore();
}

final class VerificationFailure extends VerificationState {
  const VerificationFailure(this.error);

  final DataError error;
}

/// The store has never submitted. The screen shows the form.
final class VerificationNotSubmitted extends VerificationState {
  const VerificationNotSubmitted({this.isBusy = false});

  final bool isBusy;
}

/// A request exists. The screen shows where it stands and, while it can still
/// be changed, the documents attached to it.
final class VerificationLoaded extends VerificationState {
  const VerificationLoaded(this.verification, {this.isBusy = false});

  final StoreVerification verification;
  final bool isBusy;

  /// Documents can only be added to a request that is still open. Once it is
  /// approved there is nothing to change, and a rejected one needs a fresh
  /// submission rather than another file on the old request.
  bool get canAttachDocuments => !verification.isApproved;

  /// Resubmitting is only the right move after a rejection: a new request
  /// starts with no documents, so doing it while one is pending throws away
  /// everything already uploaded.
  bool get canResubmit => verification.isRejected;

  VerificationLoaded copyWith(
          {StoreVerification? verification, bool? isBusy}) =>
      VerificationLoaded(
        verification ?? this.verification,
        isBusy: isBusy ?? this.isBusy,
      );
}
