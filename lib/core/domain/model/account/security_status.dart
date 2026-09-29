/// Account protections S-44 shows (⏳ no endpoint: the API has no
/// change-password, change-contact, 2FA or biometric support).
class SecurityStatus {
  const SecurityStatus({
    required this.phoneMasked,
    required this.emailMasked,
    this.passwordChangedAt,
    this.phoneVerified = false,
    this.emailVerified = false,
    this.twoFactor = false,
    this.biometric = false,
  });

  final DateTime? passwordChangedAt;
  final String phoneMasked;
  final bool phoneVerified;
  final String emailMasked;
  final bool emailVerified;
  final bool twoFactor;
  final bool biometric;

  /// Out of 3: verified contacts, 2FA, and (assumed) a withdrawal PIN.
  int get protections =>
      (phoneVerified && emailVerified ? 1 : 0) + (twoFactor ? 1 : 0) + 1;

  SecurityStatus copyWith({
    DateTime? passwordChangedAt,
    bool? twoFactor,
    bool? biometric,
  }) =>
      SecurityStatus(
        passwordChangedAt: passwordChangedAt ?? this.passwordChangedAt,
        phoneMasked: phoneMasked,
        phoneVerified: phoneVerified,
        emailMasked: emailMasked,
        emailVerified: emailVerified,
        twoFactor: twoFactor ?? this.twoFactor,
        biometric: biometric ?? this.biometric,
      );
}
