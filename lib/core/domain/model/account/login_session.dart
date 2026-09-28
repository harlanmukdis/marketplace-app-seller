import '../../../utils/json_parse.dart';

/// One active sign-in — a refresh token not yet revoked or expired.
class LoginSession {
  const LoginSession({
    required this.id,
    this.ipAddress,
    this.userAgent,
    this.createdAt,
    this.expiresAt,
  });

  final int id;
  final String? ipAddress;
  final String? userAgent;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  factory LoginSession.fromJson(Map<String, dynamic> json) => LoginSession(
        id: asInt(json['id']),
        ipAddress: asStringOrNull(json['ip_address']),
        userAgent: asStringOrNull(json['user_agent']),
        createdAt: asCreatedDate(json),
        expiresAt: asDateTime(json['expires_at']),
      );

  /// A readable name for the client that signed in.
  String get clientLabel {
    final ua = (userAgent ?? '').toLowerCase();
    if (ua.isEmpty) return 'Perangkat tidak dikenal';
    if (ua.startsWith('dart/')) return 'Aplikasi Xpedia Partners';
    if (ua.contains('iphone') || ua.contains('ipad')) return 'iPhone / iPad';
    if (ua.contains('android')) return 'Android';
    if (ua.contains('macintosh')) return 'Browser di Mac';
    if (ua.contains('windows')) return 'Browser di Windows';
    if (ua.startsWith('curl/')) return 'Alat developer (curl)';
    if (ua.contains('mozilla')) return 'Browser';
    return userAgent!;
  }
}
