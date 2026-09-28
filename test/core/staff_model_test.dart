import 'package:flutter_test/flutter_test.dart';
import 'package:navy_wear/core/domain/model/staff/store_staff.dart';

/// Payloads captured from the running marketplace API (v1.28.0).
void main() {
  test('reads a staff row', () {
    final m = StaffMember.fromJson(<String, dynamic>{
      'id': '1',
      'full_name': 'Probe staff',
      'email': 'probe.staff@example.test',
      'role_code': 'customer_service',
      'role_name': 'Customer Service',
      'status': 'invited',
      'joined_at': null,
    });
    expect(m.roleName, 'Customer Service');
    expect(m.isRemoved, isFalse);
    expect(StaffStatus.label(m.status), 'Diundang');
  });

  test('reads a seeded role with no permissions, then one with some', () {
    final seeded = StaffRole.fromJson(<String, dynamic>{
      'id': '122',
      'store_id': '27',
      'code': 'customer_service',
      'name': 'Customer Service',
      'is_custom': '0',
      'permissions': <dynamic>[],
    });
    expect(seeded.permissions, isEmpty);
    expect(seeded.isOwner, isFalse);

    final granted = StaffRole.fromJson(<String, dynamic>{
      'id': '122',
      'code': 'customer_service',
      'name': 'Customer Service',
      'is_custom': '0',
      'permissions': <dynamic>[
        <String, dynamic>{'permission_code': 'order.view'},
        <String, dynamic>{'permission_code': 'review.reply'},
      ],
    });
    expect(granted.permissions, <String>['order.view', 'review.reply']);
  });

  test('the permission catalogue has no duplicate codes', () {
    final codes = <String>[
      for (final g in StaffPermissions.groups.values)
        for (final (code, _) in g) code,
    ];
    expect(codes.toSet().length, codes.length);
    expect(codes, contains('order.ship'));
  });
}
