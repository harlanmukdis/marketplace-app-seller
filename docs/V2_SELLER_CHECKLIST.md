# Ceklist Implementasi — Blueprint Seller v2.0 (`docs/v2-seller/`)

Dicek: **29 Sep 2026** · API `marketplace-api` **v1.28.0** (branch `main-harlan`, `6546a65`) ·
Aplikasi branch `xpedia-redesign-api-v1.28`, diperbarui 29 Sep 2026 setelah daftar B, layout S-36, dan daftar C nomor 1–6.

Sumber aturan: `marketplace-api/docs/v2-seller/01`–`19`. Brief itu ditulis 23–25 Sep, sebelum tim
backend mengimplementasikan sebagian besarnya, jadi bagian "kondisi repo" di dalamnya **sudah basi**.
Status **API** di bawah ini dicek ulang langsung ke kode (`application/`, `database/schema/`,
`routes.php`), bukan dibaca dari brief. Status **Aplikasi** adalah kondisi app seller ini.

**Legenda**

| Simbol | API | Aplikasi |
|---|---|---|
| ✅ | Ada dan bekerja (diverifikasi) | Ada, mengikuti desain Stitch |
| 🟡 | Sebagian / berbeda dari blueprint | Ada tapi layout lama, atau sebagian |
| ❌ | Belum ada | Belum ada |
| — | Bukan urusan sisi ini (mis. fitur buyer/admin) | Bukan urusan app seller |

Kolom **Layar** merujuk ke `assets/stitch_xpedia_seller_project/`.

---

## Ringkasan

156 fitur dari 18 domain (§2–§19). Kolom — berarti fitur itu bukan urusan sisi tersebut.

| | ✅ | 🟡 | ❌ | — |
|---|---|---|---|---|
| **API** | 81 | 21 | 50 | 4 |
| **Aplikasi** | 77 | 28 | 34 | 17 |

**Yang paling menentukan urutan kerja:**

1. **Butuh API dulu (app tidak bisa jalan tanpanya)** — scan kurir / "first valid logistics scan",
   Custom Request pra-order, Cancellation Request, komplain dengan bukti foto, label pengiriman,
   inbox chat toko, held balance, ganti password/HP/email/2FA, pengumuman seller, global search,
   analytics penjualan, galeri foto produk, MOQ, merek/kondisi/grosir/dimensi. Lihat
   [bagian A](#a-butuh-api-dulu).
2. **API sudah ada, app belum** — pekerjaan app yang bisa langsung dikerjakan. Lihat
   [bagian B](#b-api-sudah-ada-app-belum).

---

## §2 Onboarding & Identitas — brief 01 · Layar S-01 s/d S-10

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Dua tipe partner (Individual / Company) | ✅ | 🟡 | `type` + field PIC wajib untuk `business`. Form app sudah kirim PIC, tapi masih satu halaman lama, bukan alur bertahap. | S-02, S-03, S-03b |
| Anti-duplikasi KTP (1 KTP = 1 akun) | ✅ | 🟡 | `409 DUPLICATE_IDENTITY`. App menampilkan pesan jelas, belum layar khusus. | S-06 |
| Anti-duplikasi HP & email | ✅ | ✅ | `EMAIL_TAKEN` / `PHONE_TAKEN` saat daftar | S-01 |
| Rekening cocok identitas (individual) | ✅ | ✅ | Nama pemilik harus sama `users.full_name`; app mengisi otomatis & mengunci | S-04 |
| Rekening company = nama badan usaha | ❌ | ❌ | API hanya mencocokkan ke nama akun, bukan nama badan usaha | S-04 |
| Logo toko wajib + review admin | ❌ | ❌ | Logo opsional, tanpa antrean moderasi | S-05 |
| Tidak bisa jualan sebelum approval | ✅ | ✅ | Toko `inactive` sampai verifikasi disetujui; Beranda menampilkan status | S-09 |
| Primary status + Xpedia Signature | ✅ | ✅ | `primary_status`, `has_signature_badge`; tampil di header Beranda | S-10 |
| Kapasitas 500 SKU untuk company | ✅ | ✅ | `sku_quota` + bar kapasitas di Daftar Produk | S-26 |
| Ajukan tambahan kuota SKU | ❌ | 🟡 | Hanya admin (`PATCH /admin/stores/{id}/sku-quota`); app mengarahkan ke Xpedia 911 | S-07 |
| Dokumen wajib per tipe (approval ditolak bila kurang) | ❌ | 🟡 | `approve()` tidak menghitung dokumen; app membatasi jenis dokumen di sisi klien | S-08 |
| Unggah dokumen KYC | ✅ | ✅ | Kartu per dokumen, sesuai S-08 | S-08 |
| Status verifikasi | ✅ | ✅ | Hero status, akses fitur, riwayat — sesuai S-09 | S-09 |
| Reason code penolakan | ❌ | 🟡 | Masih teks bebas `rejection_reason` | S-09 |
| Screening produk kimia/berbahaya | ✅ | 🟡 | Antrean fast-track admin ada; seller hanya tahu lewat penolakan tayang | S-28 |
| Audit trail perubahan identitas/rekening | 🟡 | — | Transisi verifikasi dicatat; perubahan rekening tidak | — |

## §3 Storefront Publik — brief 02 · Layar S-34, S-35, S-37

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Partners Performance (rating, order, service, live) | ✅ | ✅ | Plus tier & health score. Toko belum aktif dapat 404 (A #19) | S-35 |
| Member Since | ✅ | ❌ | `opened_at` | S-35 |
| Completed Orders & Successful Orders % | 🟡 | ✅ | `completed_orders`, `success_rate_percent`; definisi "seller-caused" baru sebagian | S-35 |
| Total Units Sold | ❌ | ❌ | `sold_count` tidak pernah di-increment (utang teknis #7) | S-35 |
| Followers | ✅ | ❌ | `follower_count` | S-34 |
| Live Now / Total Live Hours | 🟡 | 🟡 | Jam live tampil di Partners Performance; `online_status` selalu `null` | S-34, S-36 |
| Kelola storefront (banner 1 utama + 2 panel) | 🟡 | 🟡 | Banner utama bisa diganti (`store_banner`); 2 panel mini tidak ada di API | S-34 |
| Etalase buatan seller | ✅ | ✅ | CRUD + seret untuk mengurutkan | S-34 |
| Ulasan produk + balasan seller + laporkan | ✅ | ✅ | Dibaca per produk; foto ulasan & nama pengulas tidak dikirim API | S-37 |
| Tidak ada badge status seller publik | ✅ | ✅ | Sesuai blueprint | — |

## §4 Home / Dashboard — brief 03 · Layar S-11, S-12

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Info & Update resmi Xpedia | ❌ | 🟡 | Tidak ada endpoint pengumuman; app memakai notifikasi akun | S-11 |
| Perlu Tindakan (badge hanya bila actionable) | ❌ | ✅ | Tidak ada endpoint agregasi; app merakit sendiri dari pesanan | S-11 |
| Ringkasan Toko | 🟡 | ✅ | Dirakit dari pesanan + wallet | S-11 |
| Akses cepat | — | ✅ | | S-11 |
| Navigasi bawah 5 tab | — | ✅ | Beranda, Pesanan, Produk, Chat, Akun | S-11 |
| Global search (pesanan, produk, bantuan) | ❌ | ❌ | `/search/*` hanya produk/toko dan butuh Elasticsearch | S-12 |
| Badge counter per menu | ❌ | 🟡 | App menghitung badge Pesanan sendiri; lainnya belum | S-11 |

## §5 Pesanan & Fulfillment — brief 04 · Layar S-13, S05, S-21 s/d S-23

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Tanpa "Terima Pesanan" — dibayar = Processing | ✅ | ✅ | `/accept` dihapus v1.6.0 | S-13, S05 |
| "Cetak Resi" sebagai satu komitmen | ✅ | ✅ | App menjalankan pack → ship | S-21 |
| Nomor resi dibuat otomatis | ❌ | 🟡 | API masih minta `awb_number` dari seller; app menyediakan kolom isian | S-21 |
| Drop-off vs Pickup | ✅ | ✅ | `handover_method` | S-21 |
| Privasi pembeli (nama/HP masked, hanya kota) | ✅ | ✅ | Seller hanya menerima kota + provinsi (tanpa nama sama sekali) | S-13, S05 |
| SLA cetak resi + countdown | 🟡 | ✅ | Server: satu jendela 48 jam kalender (bukan dua SLA hari kerja); app mengikuti server | S-13, S05 |
| Rincian pendapatan 6 baris | ✅ | ✅ | `settlement` setelah Selesai; estimasi 5% sebelumnya | S05 |
| Pre-Order lead time di pesanan | ✅ | ✅ | `estimated_lead_time_days` | S05 |
| Status "Under Logistics" dari first valid scan | ❌ | 🟡 | Tidak ada integrasi/scan kurir; app memakai `shipped` | S-23 |
| Delivered → 3×24 jam → Completed otomatis | 🟡 | — | Worker H+3 ada, tapi **tidak mengkredit wallet seller** (utang teknis #3) | — |
| Pratinjau label pengiriman | ❌ | ❌ | Tidak ada endpoint label | S-22 |
| Monitoring pengiriman (checkpoint) | 🟡 | 🟡 | `/orders/{id}/tracking` hanya satu baris shipment; app menampilkan AWB di detail | S-23 |
| Riwayat status tidak bisa dihapus | ✅ | ✅ | `status_history` → timeline 5 tahap | S05 |

## §6 Custom, Pembatalan, Komplain — brief 05 · Layar S-15 s/d S-20

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Tolak Pesanan (tercatat kesalahan seller) | ✅ | ✅ | `cancellation_fault = seller` | S-15 |
| Konfirmasi Custom Order + lead time (setelah dibayar) | ✅ | ✅ | `/custom-confirm`, auto-cancel 2×24 jam | S-16 |
| **Custom Request sebelum jadi order** (buyer teks+foto, seller approve/reject) | ❌ | ❌ | Yang ada hanya konfirmasi setelah bayar | S-16 |
| Partial fulfillment | ✅ | ✅ | Propose oleh seller, keputusan oleh buyer | S-17 |
| **Permintaan pembatalan buyer setelah diproses** | ❌ | ❌ | Tercatat di `docs/22` #3, belum dibangun | S-18 |
| Komplain/retur dengan foto, maks 3×24 jam setelah Delivered | 🟡 | 🟡 | `refund-request` hanya `reason` + `amount`; tanpa bukti, tanpa batas waktu, bisa dari status apa pun | S-19 |
| Seller setujui/tolak refund | ✅ | 🟡 | Ada di Detail Pesanan; belum layar S-19 | S-19 |
| Final Invoice hanya setelah Selesai | ✅ | ✅ | `/orders/{id}/invoice` | S-20 |

## §7 Secure+ — brief 06 · Layar S-21, S05

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Dipilih pembeli per transaksi | ✅ | — | `insurance/opt-in` tier `secure_plus` | — |
| Biaya 3% + Rp7.500 | ❌ | — | Default premi 0,5% | — |
| Bukti foto + video wajib sebelum serah kurir | ✅ | ✅ | `422 SECURE_PLUS_EVIDENCE_REQUIRED` | S-21 |
| Kode segel | ✅ | ✅ | Dikembalikan sekali saat ship; app menampilkannya | S05 |
| Scan QR/barcode stiker (seller & kurir) | ❌ | ❌ | Kode segel teks saja | S-21 |
| Hard gate "no scan, no delivery" | ✅ | — | Pembeli wajib memasukkan kode segel | — |
| Retensi bukti 100 hari | ✅ | — | | — |
| Lihat bukti yang sudah diunggah | ✅ | ✅ | Kartu bukti di detail pesanan (`/shipment-evidence`) | S05 |
| Penanda Secure+ di pesanan sebelum kirim | ❌ | 🟡 | Tidak ada flag; app mengetahuinya dari penolakan ship | S-13 |

## §8 Pengiriman & Kurir — brief 07 · Layar S-21 s/d S-25

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Pilih kurir aktif toko | ✅ | ✅ | Switch per kurir; tanpa layanan per kurir & jadwal pickup (API hanya kode + nama) | S-24 |
| Cakupan pengiriman per produk (include/exclude kota) | ✅ | ✅ | `/products/{id}/shipping-coverage` | S-27 |
| Gudang maks 3 titik | ✅ | ✅ | Kuota x/3 + sisa lokasi; cakupan kota tetap per produk | S-25 |
| Label tanpa PII pembeli | ❌ | ❌ | Tidak ada endpoint label | S-22 |
| Handover diakui dari first valid scan | ❌ | ❌ | Tidak ada event scan kurir | S-23 |
| Menu Shipping untuk memantau kiriman | 🟡 | ❌ | Hanya tracking satu baris | S-23 |

## §9 Produk, Listing & Stok — brief 08 · Layar S-26 s/d S-28

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Mode stok: Ready / Infinite / Pre-Order / Custom / Discontinued | ✅ | ✅ | `fulfillment_mode` | S-26, S-27 |
| Low Stock / Stok Kosong otomatis | ✅ | ✅ | `availability` di detail produk | S-26 |
| Discontinued hilang dari pencarian | ✅ | ✅ | | S-26 |
| Lead time Pre-Order/Custom | ✅ | ✅ | Per produk | S-27 |
| Lead time per varian | ❌ | ❌ | Hanya per produk | S-27 |
| Harga per varian | ✅ | ✅ | | S-27 |
| Stok per varian | ✅ | ✅ | Diatur lewat Gudang → Atur Stok | S-27 |
| Reservasi stok atomik | ✅ | — | | — |
| Notifikasi stok menipis | ❌ | ❌ | | S-40 |
| MOQ (minimum order) | ❌ | ❌ | | S-27 |
| Watermark foto produk | ✅ | ✅ | `context=product_photo`, terverifikasi | S-27 |
| Galeri foto produk (maks 9) | ❌ | 🟡 | `product_images` tidak bisa ditulis; app: satu foto per varian | S-27 |
| Merek, Kondisi, Harga Grosir | ❌ | ❌ | Tidak ada field | S-27 |
| Dimensi kemasan | 🟡 | ❌ | Kolom `products.dimensions` ada, tapi tidak ada endpoint yang menulis | S-27 |
| Sertifikasi BPOM / Halal / SNI | ✅ | ✅ | Menggantikan kotak MSDS di desain | S-27 |
| Status moderasi produk | ❌ | 🟡 | Tidak ada endpoint untuk seller; app hanya tahu dari `RESTRICTION_REVIEW_PENDING` | S-28 |
| Master Product ("Tersedia dari X seller") | ❌ | — | | — |

## §10 Campaign & Promo — brief 09 · Layar S-31

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Voucher toko & flash sale | ✅ | ✅ | Tab + filter Aktif/Terjadwal/Selesai sesuai S-31 | S-31 |
| Ikut campaign platform (submit produk) | 🟡 | ❌ | Submit ada, tapi daftar campaign hanya untuk admin (A #15) | S-31 |
| Campaign toko (target produk, jadwal + jam aktif, diskon % / Rp) | 🟡 | ❌ | Hanya lewat voucher/flash sale; tidak ada entitas campaign toko | S-31 |
| Subsidi ongkir oleh seller | ✅ | 🟡 | Voucher `free_shipping` + split platform | S-31 |
| Promo bertumpuk | ✅ | — | Voucher stacking | — |
| Bundel produk | ✅ | ✅ | Di Kelola Storefront | S-31 |
| Proteksi margin (proyeksi harga sebelum aktif) | — | ✅ | Simulasi payout vs HPP; HPP tidak disimpan | S-31 |
| Ubah / hentikan promo | ❌ | — | Voucher & flash sale tidak bisa diedit/dihapus (405) | S-31 |

## §11 Xpedia Growth — brief 10 · Layar S-32

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Komisi tambahan 1–15% | ✅ | ✅ | | S-32 |
| Kunci 7×24 jam | ✅ | ✅ | App menolak simpan tanpa perubahan (server mengunci walau no-op) | S-32 |
| Syarat Natural Performance ≥ 60 | ✅ | 🟡 | Tidak ada endpoint skor; app hanya tahu dari penolakan | S-32 |
| Mode "Aktif 7 Hari" vs "Always On" | ❌ | ❌ | | S-32 |
| Atribusi 7 hari | ❌ | — | Komisi dipotong dari semua order selesai produk itu, bukan yang teratribusi | — |
| Laporan 7 hari vs 7 hari sebelumnya | ✅ | ✅ | `/growth/performance` | S-32 |
| Tanpa sort/filter harga termurah (sisi buyer) | ❌ | — | `price_asc`/`price_desc` masih ada | — |

## §12 Chat — brief 11 · Layar S-29, S-30

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Daftar percakapan toko (inbox) | ❌ | 🟡 | `/chat/conversations` hanya percakapan sebagai pembeli; app menjelaskan keterbatasannya | S-29 |
| Badge belum dibaca | ❌ | ❌ | Kolom `*_unread_count` tidak pernah ditulis | S-29 |
| Kirim & baca pesan | ✅ | ✅ | Layout S-30, pembatas hari, banner keamanan | S-30 |
| Tipe: teks, foto, kartu produk, referensi order (tanpa video/file) | ✅ | ✅ | Composer: foto, bagikan produk, bagikan pesanan | S-30 |
| 4 status pesan (pending, 1 ✓, 2 ✓, 2 ✓ biru) | ✅ | ✅ | `status` + `delivered_at`; pending di sisi app. Terverifikasi | S-30 |
| Moderasi anti-bypass kontak | ✅ | ✅ | `CHAT_CONTENT_BLOCKED` dijelaskan ke seller | S-30 |

## §13 Xpedia Wallet — brief 12 · Layar S-38, S-39

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Saldo tersedia & riwayat transaksi | ✅ | ✅ | | S-38 |
| Saldo ditahan | ❌ | ❌ | `held_balance` tidak pernah ditulis | S-38 |
| Referensi transaksi bisa diklik | ✅ | ✅ | Hasil penjualan membuka pesanannya | S-38 |
| PIN penarikan 6 digit | ✅ | ✅ | Buat & ganti PIN | S-39, S-44 |
| Maks 3 rekening tersimpan | ✅ | ✅ | | S-38, S-39 |
| Tanpa biaya penarikan | ✅ | ✅ | | S-39 |
| Minimum penarikan Rp10.000 | ❌ | 🟡 | API masih Rp50.000; app mengikuti API | S-39 |
| Ganti rekening dengan review internal | ❌ | ❌ | Rekening langsung aktif | S-38 |
| Riwayat penarikan seller | ❌ | 🟡 | Hanya admin; app memakai baris ledger | S-38 |
| Penarikan ditolak → saldo kembali | ❌ | — | Bug terbuka di CHANGELOG v1.24.0 | — |

## §14 Analytics — brief 13 · Layar S-33

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Penjualan bulanan (hanya Completed) | ❌ | 🟡 | `/stores/{id}/analytics` kosong; app menghitung GMV dari pesanan Completed | S-33 |
| Pelanggan baru vs loyal | ✅ | ✅ | `/stores/{id}/customer-segmentation` | S-33 |
| Kunjungan toko (dedup 30 menit) | ✅ | — | Dicatat dari sisi buyer | — |
| Product viewed (≥ 2 detik) | 🟡 | — | Server memakai ambang 3 detik | — |
| Corong konversi (visit → view → klik → keranjang → terjual) | ❌ | ❌ | | S-33 |
| Sumber traffic | ❌ | ❌ | | S-33 |
| Produk terlaris | ❌ | ❌ | `sold_count` tidak pernah di-increment | S-33 |
| Riwayat stok tidak sinkron | ✅ | ✅ | `/stores/{id}/stock-mismatch-events` | S-33 |

## §15 Performance — brief 14 · Layar S-35

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Periode bulan kalender (reset tanggal 1) | ✅ | ✅ | | S-35 |
| Cancellation rate (hanya kesalahan seller) | ✅ | ✅ | | S-35 |
| Rata-rata waktu balas chat | ✅ | ✅ | `avg_reply_minutes` | S-35 |
| Ketepatan handover | ❌ | ❌ | Butuh scan kurir | S-35 |
| Complaint rate (hanya yang terbukti) | ❌ | ❌ | | S-35 |
| Successful Orders % | 🟡 | ✅ | `success_rate_percent` | S-35 |
| Tier & health score | ✅ | ✅ | `/stores/{id}/tier`, `/health-score`; kosong sebelum worker malam jalan | S-35 |

## §16 Xpedia 911 — brief 15 · Layar S-41, S-42

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Buat & lihat tiket, riwayat balasan | ✅ | ✅ | | S-41, S-42 |
| Tepat 4 kategori (Pesanan, Pengiriman, Wallet, Produk) | 🟡 | 🟡 | Server memakai 4 kategori lain (`order_transaction`, `payment_wallet`, `account_security`, `report_violation`) | S-41 |
| Pilih objek terkait (pesanan/AWB/transaksi/produk) | 🟡 | ❌ | API hanya `related_order_id` | S-41 |
| Identitas "Tim Xpedia 911" | ✅ | ✅ | | S-42 |
| Lampiran bukti | ✅ | ✅ | `attachment_url`, konteks unggah `support_ticket_evidence` | S-42 |
| Live chat 911 | ❌ | ❌ | Ada di desain | S-41 |

## §17 Pengaturan & Keamanan — brief 16 · Layar S-43, S-44

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Profil toko, mode libur, kontak | ✅ | ✅ | | S-43 |
| Jam operasional | ✅ | ✅ | `operational_hours` JSON bebas; app menulis `{open, close, days}` | S-43 |
| Preferensi notifikasi | ✅ | ✅ | Dari Pengaturan Toko & Pusat Notifikasi | S-43 |
| Ganti kata sandi | ❌ | ❌ | Hanya lupa / reset | S-44 |
| Ganti HP / email | ❌ | ❌ | | S-44 |
| OTP / 2FA | ❌ | ❌ | | S-44 |
| Riwayat sesi & perangkat, keluar dari sesi lain | ✅ | ✅ | `/me/sessions`, `/me/devices` | S-44 |
| PIN penarikan | ✅ | ✅ | | S-44 |
| Bahasa Indonesia & English | — | 🟡 | App: teks seller hardcode Indonesia; berkas terjemahan kit berisi en/ar | — |
| Staf & peran toko | 🟡 | ✅ | Undang, ubah peran, izin per peran; staf belum bisa membuka toko (A #18, #20) | — |

## §18 Live Selling — brief 17 · Layar S-36

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Buat, mulai, akhiri sesi live | 🟡 | ✅ | Tidak ada daftar sesi & transisi tidak divalidasi (A #16, #17); app mengingat id sesi | S-36 |
| Pin produk saat live | ✅ | ✅ | `/live-sessions/{id}/products/{id}/pin` | S-36 |
| Voucher live | ✅ | ✅ | | S-36 |
| Live Now / total jam live di storefront | 🟡 | 🟡 | Total jam tampil di Performa; status "Live Now" belum | S-34 |

## §19 Notifikasi & Audit — brief 18 · Layar S-40

| Fitur | API | App | Catatan | Layar |
|---|---|---|---|---|
| Kotak masuk, tandai dibaca, bisukan per tipe | ✅ | ✅ | Layout S-40 | S-40 |
| Notifikasi untuk semua event penting | ❌ | — | Baru 3 pemanggil: undangan staf, checkout, pesanan baru | — |
| Prioritas Kritis / Operasional / Informasi | ❌ | 🟡 | App menggolongkan dari `type`; API tidak mengirim prioritas | S-40 |
| Log event append-only | 🟡 | — | Riwayat status pesanan & ledger ada; banyak event lain belum | — |

## Utang Teknis Prasyarat — brief 19

| # | Masalah | API | Catatan |
|---|---|---|---|
| 1 | Alamat kirim tidak bisa dibaca seller | ✅ | Diselesaikan v1.6.0 (dimasking per penonton) |
| 2 | `Wallet_model::transfer()` tidak atomik | ❌ | Transaksi bersarang masih sama |
| 3 | Auto-complete tidak membayar seller | ❌ | Worker masih `UPDATE` mentah tanpa kredit wallet |
| 4 | `refund_requested` bisa dari status apa pun | ❌ | `request_refund()` tidak memeriksa status |
| 5 | `order_shipments.status = 'in_transit'` tidak pernah ditulis | ❌ | Deteksi paket hilang mati |
| 6 | Setting di-seed tapi tidak dibaca | 🟡 | Sebagian sudah dibaca (mis. min penarikan dari config) |
| 7 | `sold_count` / `view_count` tidak pernah bertambah | ❌ | Memblokir Units Sold, produk terlaris, sort populer |
| 8 | Tabel agregat tidak pernah diisi | ❌ | `store_analytics_daily` |
| 9 | `withdrawal_requests` menyimpan id yang salah | — | Belum dicek ulang |
| 10 | `broadcast()` memuat semua user ke memori | — | Belum dicek ulang |

---

## A. Butuh API dulu

Tidak bisa diselesaikan di app sebelum backend menyediakannya. Diurutkan dari dampak terbesar.

1. **Scan kurir / first valid logistics scan** — menentukan "Under Logistics", ketepatan
   handover, monitoring pengiriman, dan QR Secure+. Pemblokir terbesar.
2. **Auto-complete mengkredit wallet seller** (utang #3) — tanpa ini, order yang selesai otomatis
   tidak pernah dibayar.
3. **Custom Request sebelum order** dan **Cancellation Request** pembeli.
4. **Komplain dengan bukti foto + batas 3×24 jam** (dan penjagaan status, utang #4).
5. **Endpoint label pengiriman** + nomor resi otomatis.
6. **Inbox chat toko** + penghitung belum dibaca.
7. **Held balance**, minimum penarikan Rp10.000, riwayat penarikan seller, credit-back saat ditolak.
8. **Ganti kata sandi / HP / email, 2FA**.
9. **Pengumuman resmi seller**, **ringkasan beranda**, **global search** lintas entitas.
10. **Analytics penjualan** (isi `store_analytics_daily`, `sold_count`), corong & sumber traffic.
11. Produk: **galeri foto**, **MOQ**, **lead time per varian**, **dimensi** (kolom sudah ada),
    merek/kondisi/grosir, **status moderasi** untuk seller, **skor Natural Performance**.
12. Growth: **Aktif 7 Hari / Always On**, **atribusi 7 hari**.
13. Kategori Xpedia 911 disamakan dengan desain, dan pemilihan objek selain pesanan.
14. Logo wajib + moderasi, reason code penolakan verifikasi, validasi dokumen wajib.
15. **Daftar campaign untuk seller** — `/admin/campaigns` butuh izin admin, jadi seller tidak bisa
    memilih campaign untuk diikuti.
16. **Daftar sesi live toko** (`GET /stores/{id}/live-sessions` menjawab 405) dan **validasi
    transisi** start/end — sesi yang sudah selesai bisa di-start lagi (terverifikasi).
17. 🔴 **Kebocoran `stream_key`** — `GET /live-sessions/{id}` publik dan mengembalikan stream key
    tanpa login (terverifikasi). Siapa pun yang tahu id bisa menyiarkan atas nama toko.
18. **`GET /stores` untuk staf** — hanya toko milik sendiri, jadi staf yang menerima undangan tidak
    bisa membuka toko tersebut.
19. **`/partners-performance` untuk pemilik toko belum aktif** — lewat `find_public()`, jadi 404.
20. **Undang staf ke email tak terdaftar / ubah izin peran yang tidak ada** — exception tak
    tertangkap, dijawab halaman HTML, bukan error envelope.

## B. API sudah ada, app belum

Dikerjakan 29 Sep 2026.

| # | Pekerjaan | Status | Catatan |
|---|---|---|---|
| 1 | Partners Performance + tier & health score (S-35) | ✅ | |
| 2 | Chat: 4 status centang, foto, kartu produk & referensi pesanan (S-30) | ✅ | Diuji live. Inbox toko tetap menunggu API |
| 3 | Ulasan produk + balas + laporkan (S-37) | ✅ | Belum bisa diuji live — seed tanpa ulasan |
| 4 | Analytics: pelanggan baru/loyal, stok tidak sinkron, penjualan per periode (S-33) | ✅ | |
| 5 | Bukti Secure+ di detail pesanan | ✅ | |
| 6 | Ikut campaign platform | ⛔ | Diblokir API: tidak ada daftar campaign untuk seller (A #15) |
| 7 | Sesi & perangkat (S-44) | ✅ | |
| 8 | Jam operasional toko (S-43) | ✅ | Diuji live |
| 9 | Lampiran bukti tiket 911 (S-42) | ✅ | Diuji live |
| 10 | Live selling (S-36) | ✅ | Diuji live; layout studio sesuai Stitch. App tidak menyiarkan video; RTMP + stream key untuk OBS. Pesanan/penjualan per sesi & komentar belum ada di API |
| 11 | Staf & peran toko | ✅ | Staf belum bisa membuka toko (A #18) |
| 12 | Restyle layar lama | 🟡 | Login/Daftar (S-01) & Verifikasi (S-08/09) ditata ulang; widget bersama dan skala teks semua layar sudah design system; tata letak Kurir, Gudang, Promo, Etalase, Notifikasi masih versi lama |

## C. Sisa yang bisa dikerjakan app sekarang

API-nya sudah cukup; yang kurang di sisi app. Sisanya di §2–§19 yang bertanda ❌/🟡 menunggu API (daftar A).

| # | Pekerjaan | Layar | Status | Catatan |
|---|---|---|---|---|
| 1 | Restyle Kurir | S-24 | ✅ | Switch per kurir; mematikan kurir terakhir ditolak (daftar kosong = semua) |
| 2 | Restyle Gudang & stok per varian | S-25 | ✅ | Kuota 3 lokasi; cakupan kota & subsidi ongkir diarahkan ke Produk / Promo |
| 3 | Restyle Promo: voucher, flash sale, bundel, subsidi ongkir | S-31 | ✅ | Tab, filter fase, kartu campaign; sub-layar & form ikut token |
| 4 | Proteksi margin (proyeksi harga sebelum promo aktif) | S-31 | ✅ | Komisi 5% + Growth produk |
| 5 | Kelola storefront + etalase | S-34 | ✅ | Ganti banner, etalase diurutkan dengan seret, bundel; panel mini & sorotan beranda tidak ada di API |
| 6 | Pusat notifikasi + preferensi | S-40, S-43 | ✅ | Kategori diturunkan dari `type` |
| 7 | Member Since & Followers | S-34/S-35 | ❌ | `opened_at` sudah dibaca model, `follower_count` belum; belum tampil |
| 8 | Onboarding bertahap: pilih tipe → identitas → badan usaha & PIC | S-02, S-03, S-03b | ❌ | Sekarang satu halaman |
| 9 | Layar khusus penolakan duplikasi identitas | S-06 | ❌ | Sekarang hanya pesan |
| 10 | Layar keputusan refund | S-19 | ❌ | Sekarang di Detail Pesanan |
| 11 | Menu pemantauan pengiriman | S-23 | ❌ | Dari daftar pesanan dikirim + `/tracking` (satu baris per kiriman) |
| 12 | Pilih pesanan terkait saat buat tiket 911 | S-41 | ❌ | API menerima `related_order_id`; form belum mengirimnya |
| 13 | Bahasa Inggris untuk teks seller | — | ❌ | Teks seller masih hardcode Indonesia |

## D. Tampilan dengan data contoh (menunggu API)

Dibuat 29 Sep 2026. Layar sudah ada; datanya dari repository tiruan (`lib/core/data/demo/`).
Jalankan dengan `--dart-define=DEMO_DATA=true` untuk melihat data contoh (bertanda **Data
contoh**); tanpa flag itu layar menampilkan **Menunggu API**. Aksi tulis hanya simulasi. Saat
endpoint tersedia, cukup ganti implementasi repository di `injector_repository.dart`.

| # | Area | Layar | Repository | Catatan |
|---|---|---|---|---|
| 1 | Inbox chat toko + badge belum dibaca | S-29 | `StoreInboxRepository` | Tanpa flag: tampilan penjelasan lama |
| 2 | Permintaan pembatalan, komplain & retur | S-18, S-19 | `OrderCaseRepository` | Dari tab Pesanan & menu Akun |
| 3 | Label pengiriman, monitoring kiriman | S-22, S-23 | `ShipmentMonitorRepository` | Label disusun dari data pesanan asli; cetak/unduh simulasi |
| 4 | Corong konversi, sumber traffic, produk terlaris | S-33 | `StoreInsightsRepository` | Nama produk terlaris dari katalog asli |
| 5 | Status moderasi, skor Natural Performance | S-28, S-32 | `CatalogQualityRepository` | |
| 6 | Saldo ditahan, riwayat penarikan | S-38 | `WalletExtrasRepository` | |
| 7 | Ganti kata sandi / HP / email, 2FA, biometrik | S-44 | `AccountSecurityRepository` | |
| 8 | Pencarian global, pengumuman resmi | S-12, S-11 | `DiscoveryRepository` | Pesanan & produk di pencarian = data asli |
| 9 | Komentar live, pesanan & penjualan per sesi | S-36 | `LiveInsightsRepository` | |
| 10 | 2 banner mini, sorotan beranda | S-34 | `StorefrontExtrasRepository` | Gambar tetap diunggah sungguhan |
| 11 | Galeri 9 foto, MOQ, grosir, merek/kondisi, dimensi | S-27 | `ProductExtrasRepository` | Kartu terpisah di form produk (setelah produk tersimpan) |
| 12 | Durasi Growth (7 hari / terus) + proyeksi; daftar campaign platform | S-32, S-31 | `CatalogQualityRepository`, `CampaignRepository` | Submit campaign akan memakai endpoint yang sudah ada |

---

*Perbarui dokumen ini setiap kali satu item selesai, dan cek ulang kolom API setiap kali
`CHANGELOG.md` di `marketplace-api` naik versi.*
