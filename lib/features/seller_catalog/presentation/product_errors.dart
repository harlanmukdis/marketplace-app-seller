import '../../../core/data_state.dart';

/// Plain-language versions of the product refusals added since API v1.7.0.
///
/// Several of these arrive with no message at all (`CERTIFICATION_REQUIRED`,
/// `RESTRICTION_REVIEW_PENDING` send `null`), so without this the seller would
/// see a bare error code. The server's own wording is kept where it carries
/// something specific — the unlock time of `GROWTH_LOCKED`, the policy text of
/// `PRODUCT_PROHIBITED`.
DataError explainProductError(DataError error) {
  final message = switch (error.code) {
    'SKU_QUOTA_EXCEEDED' => 'Kapasitas katalog toko sudah penuh. Arsipkan '
        'produk lama atau ajukan tambahan kuota lewat Xpedia 911.',
    'PRODUCT_PROHIBITED' => 'Produk ini termasuk barang terlarang di Xpedia'
        '${_suffix(error.message)}',
    'RESTRICTION_REVIEW_PENDING' => 'Produk ini masuk antrean moderasi tim '
        'kurasi Xpedia (kategori terbatas). Produk bisa ditayangkan setelah '
        'disetujui.',
    'CERTIFICATION_REQUIRED' => 'Kategori ini mewajibkan sertifikat yang '
        'sudah terverifikasi sebelum produk bisa ditayangkan.',
    'NATURAL_PERFORMANCE_TOO_LOW' => 'Skor Natural Performance produk ini di '
        'bawah 60, jadi Xpedia Growth belum bisa diaktifkan. Tingkatkan '
        'rating, penjualan, dan ketersediaan stok dulu.',
    'GROWTH_LOCKED' => error.message.isEmpty
        ? 'Pengaturan Growth masih terkunci 7×24 jam sejak perubahan terakhir.'
        : error.message,
    _ => null,
  };
  if (message == null) return error;
  return DataError(code: error.code, message: message, details: error.details);
}

String _suffix(String serverMessage) =>
    serverMessage.isEmpty || serverMessage == 'PRODUCT_PROHIBITED'
        ? '.'
        : ': $serverMessage';
