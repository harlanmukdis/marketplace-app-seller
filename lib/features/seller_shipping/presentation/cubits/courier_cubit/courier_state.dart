part of 'courier_cubit.dart';

sealed class CourierState {
  const CourierState();
}

final class CourierInProgress extends CourierState {
  const CourierInProgress();
}

final class CourierNoStore extends CourierState {
  const CourierNoStore();
}

final class CourierFailure extends CourierState {
  const CourierFailure(this.error);

  final DataError error;
}

final class CourierLoaded extends CourierState {
  const CourierLoaded({
    required this.available,
    required this.selectedCodes,
    this.isBusy = false,
    this.isDirty = false,
  });

  /// The platform's active couriers — what can be chosen from.
  final List<Courier> available;

  /// Codes this store ships with. Held as a set because the save replaces the
  /// whole list anyway, so order carries no meaning.
  final Set<String> selectedCodes;

  final bool isBusy;

  /// Something was toggled since the last save. Drives the save button, since
  /// writing an unchanged list would be a pointless replace-all.
  final bool isDirty;

  /// No restriction set. The backend applies this list as a whitelist **only
  /// when it is non-empty**, so an empty one means every active courier is
  /// offered — the opposite of what it looks like.
  bool get hasNone => selectedCodes.isEmpty;

  bool isSelected(String code) => selectedCodes.contains(code);

  /// On for buyers: every courier while unrestricted, else the selected ones.
  bool isOn(String code) => hasNone || isSelected(code);

  int get activeCount => hasNone ? available.length : selectedCodes.length;

  CourierLoaded copyWith({
    List<Courier>? available,
    Set<String>? selectedCodes,
    bool? isBusy,
    bool? isDirty,
  }) =>
      CourierLoaded(
        available: available ?? this.available,
        selectedCodes: selectedCodes ?? this.selectedCodes,
        isBusy: isBusy ?? this.isBusy,
        isDirty: isDirty ?? this.isDirty,
      );
}
