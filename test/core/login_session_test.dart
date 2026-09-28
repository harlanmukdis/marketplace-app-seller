import 'package:flutter_test/flutter_test.dart';
import 'package:navy_wear/core/domain/model/account/login_session.dart';

/// Payload captured from `GET /me/sessions` (API v1.28.0).
void main() {
  test('reads a session and names its client', () {
    final s = LoginSession.fromJson(<String, dynamic>{
      'id': '35',
      'device_id': null,
      'ip_address': '::1',
      'user_agent': 'curl/8.7.1',
      'created_at': '2026-09-29 06:47:12',
      'expires_at': '2026-10-29 06:47:12',
    });

    expect(s.id, 35);
    expect(s.clientLabel, 'Alat developer (curl)');
    expect(s.expiresAt, DateTime(2026, 10, 29, 6, 47, 12));
  });

  test('the app itself signs in as Dart', () {
    const ua = 'Dart/3.9 (dart:io)';
    expect(LoginSession(id: 1, userAgent: ua).clientLabel,
        'Aplikasi Xpedia Partners');
    expect(const LoginSession(id: 2).clientLabel, 'Perangkat tidak dikenal');
  });
}
