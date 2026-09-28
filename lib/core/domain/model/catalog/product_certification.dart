import '../../../utils/json_parse.dart';

/// `product_certifications` — BPOM, Halal or SNI evidence for one product.
///
/// A category can require one before its products may go active
/// (`CERTIFICATION_REQUIRED`); an admin verifies each submission. The server
/// validates **nothing** on submit — a missing field is a PHP warning or 500,
/// and an unknown type is stored as `''` — so every field is checked here.
class ProductCertification {
  const ProductCertification({
    required this.id,
    required this.type,
    required this.number,
    this.documentUrl,
    this.issuedBy,
    this.validUntil,
    this.status = CertificationStatus.submitted,
  });

  final int id;
  final String type;
  final String number;
  final String? documentUrl;
  final String? issuedBy;
  final DateTime? validUntil;
  final String status;

  factory ProductCertification.fromJson(Map<String, dynamic> json) =>
      ProductCertification(
        id: asInt(json['id']),
        type: asString(json['certification_type']),
        number: asString(json['certificate_number']),
        documentUrl: asStringOrNull(json['document_url']),
        issuedBy: asStringOrNull(json['issued_by']),
        validUntil: asDateTime(json['valid_until']),
        status: asString(json['status'], fallback: CertificationStatus.submitted),
      );
}

abstract class CertificationType {
  static const String bpom = 'bpom';
  static const String halal = 'halal';
  static const String sni = 'sni';

  static const List<String> all = <String>[bpom, halal, sni];

  static String label(String t) => switch (t) {
        bpom => 'BPOM',
        halal => 'Halal',
        sni => 'SNI',
        _ => t.isEmpty ? '-' : t,
      };
}

abstract class CertificationStatus {
  static const String submitted = 'submitted';
  static const String verified = 'verified';
  static const String rejected = 'rejected';
  static const String expired = 'expired';

  static String label(String s) => switch (s) {
        submitted => 'Menunggu verifikasi',
        verified => 'Terverifikasi',
        rejected => 'Ditolak',
        expired => 'Kedaluwarsa',
        _ => s,
      };
}
