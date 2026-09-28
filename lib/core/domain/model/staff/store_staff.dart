import '../../../utils/json_parse.dart';

class StaffMember {
  const StaffMember({
    required this.id,
    required this.fullName,
    required this.email,
    required this.roleCode,
    required this.roleName,
    this.status = StaffStatus.invited,
    this.joinedAt,
  });

  final int id;
  final String fullName;
  final String email;
  final String roleCode;
  final String roleName;
  final String status;
  final DateTime? joinedAt;

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
        id: asInt(json['id']),
        fullName: asString(json['full_name']),
        email: asString(json['email']),
        roleCode: asString(json['role_code']),
        roleName: asString(json['role_name']),
        status: asString(json['status'], fallback: StaffStatus.invited),
        joinedAt: asDateTime(json['joined_at']),
      );

  bool get isRemoved => status == StaffStatus.removed;
}

abstract class StaffStatus {
  static const String invited = 'invited';
  static const String active = 'active';
  static const String suspended = 'suspended';
  static const String removed = 'removed';

  static String label(String s) => switch (s) {
        invited => 'Diundang',
        active => 'Aktif',
        suspended => 'Ditangguhkan',
        removed => 'Dikeluarkan',
        _ => s,
      };
}

/// A store role. Six are seeded per store with **no permissions** until the
/// owner grants some; the owner has full access regardless of role.
class StaffRole {
  const StaffRole({
    required this.id,
    required this.code,
    required this.name,
    this.isCustom = false,
    this.permissions = const <String>[],
  });

  final int id;
  final String code;
  final String name;
  final bool isCustom;
  final List<String> permissions;

  factory StaffRole.fromJson(Map<String, dynamic> json) => StaffRole(
        id: asInt(json['id']),
        code: asString(json['code']),
        name: asString(json['name']),
        isCustom: asBool(json['is_custom']),
        permissions: <String>[
          for (final p in asMapList(json['permissions']))
            asString(p['permission_code']),
        ],
      );

  bool get isOwner => code == 'owner';
}

/// The permission codes the API actually checks for store staff — there is
/// no master table; these are collected from its `authorize()` calls.
abstract class StaffPermissions {
  static const Map<String, List<(String, String)>> groups =
      <String, List<(String, String)>>{
    'Pesanan': <(String, String)>[
      ('order.view', 'Lihat pesanan'),
      ('order.pack', 'Kemas pesanan'),
      ('order.ship', 'Cetak resi & kirim'),
      ('order.cancel', 'Tolak / batalkan pesanan'),
      ('order.custom_confirm', 'Konfirmasi custom order'),
      ('refund.approve', 'Setujui refund'),
      ('refund.reject', 'Tolak refund'),
    ],
    'Produk': <(String, String)>[
      ('product.view', 'Lihat produk'),
      ('product.create', 'Tambah produk'),
      ('product.update', 'Ubah produk & Growth'),
      ('product.variant.create', 'Tambah varian'),
      ('product.variant.update', 'Ubah varian'),
      ('product.bundle.create', 'Buat bundel'),
      ('review.reply', 'Balas ulasan'),
    ],
    'Gudang & Stok': <(String, String)>[
      ('warehouse.view', 'Lihat gudang'),
      ('warehouse.create', 'Tambah gudang'),
      ('warehouse.update', 'Ubah gudang'),
      ('inventory.view', 'Lihat stok'),
      ('inventory.adjustment.create', 'Penyesuaian stok'),
      ('inventory.audit.update', 'Isi stock opname'),
      ('inventory.audit.complete', 'Selesaikan stock opname'),
    ],
    'Promosi & Live': <(String, String)>[
      ('voucher.create', 'Buat voucher'),
      ('flash_sale.create', 'Buat flash sale'),
      ('flash_sale.manage', 'Kelola flash sale'),
      ('campaign.product.submit', 'Ikut campaign'),
      ('store.showcase.manage', 'Kelola etalase'),
      ('live.create', 'Buat sesi live'),
      ('live.manage', 'Kelola sesi live'),
    ],
    'Keuangan': <(String, String)>[
      ('wallet.view', 'Lihat wallet'),
      ('wallet.withdraw', 'Tarik dana'),
    ],
    'Toko & Staf': <(String, String)>[
      ('store.update', 'Ubah profil toko'),
      ('store.settings.view', 'Lihat pengaturan'),
      ('store.settings.update', 'Ubah pengaturan'),
      ('store.analytics.view', 'Lihat analitik & performa'),
      ('store.verification.view', 'Lihat verifikasi'),
      ('store.verification.submit', 'Ajukan verifikasi'),
      ('staff.view', 'Lihat staf'),
      ('staff.invite', 'Undang staf'),
      ('staff.update', 'Ubah peran staf'),
      ('staff.remove', 'Keluarkan staf'),
      ('staff.role.view', 'Lihat peran'),
      ('staff.role.create', 'Buat peran'),
      ('staff.role.update', 'Ubah izin peran'),
    ],
  };
}
