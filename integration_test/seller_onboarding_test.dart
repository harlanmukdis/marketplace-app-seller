import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:navy_wear/config/route/app_route_seller.dart';
import 'package:navy_wear/core/data/local/session_store.dart';
import 'package:navy_wear/core/utils/app_routes.dart';
import 'package:navy_wear/core/utils/local_network.dart';
import 'package:navy_wear/core/widgets/xpedia/x_widgets.dart';
import 'package:navy_wear/di/injector.dart';
import 'package:navy_wear/main.dart';

/// Drives verification and warehouse/stock against the **running** backend.
///
/// Registers a throwaway account each run and opens a fresh store, because both
/// flows are one-way: a store can only be verified once, and stock movements
/// cannot be deleted. Reusing a seeded store would leave permanent residue.
///
///     flutter test integration_test -d macos
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) {
        // Routes fade in; a widget that exists can still refuse a tap.
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        return;
      }
    }
    fail('Timed out waiting for: ${finder.describeMatch(Plurality.zero)}');
  }

  /// A menu grows a row per domain as they land, so a target that used to be
  /// on screen drifts below the fold — where a tap hits nothing.
  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text).first;
    await tester.ensureVisible(target);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(target);
  }

  /// These forms are taller than the window, so the submit button usually sits
  /// below the fold — where a tap silently lands on nothing.
  Future<void> tapButton(WidgetTester tester, String label) async {
    // Forms still built on Material buttons, and the redesigned ones on
    // XButton — either is a button.
    var button = find.widgetWithText(FilledButton, label);
    if (button.evaluate().isEmpty) button = find.widgetWithText(XButton, label);
    button = button.first;
    await tester.ensureVisible(button);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(button);
  }

  /// A modal bottom sheet covers the app bar, so [back] cannot reach its
  /// button — tapping the scrim above the sheet is what closes one.
  Future<void> dismissSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
  }

  /// Every app bar's back button carries this tooltip, the redesigned
  /// `XAppBar` and the restyled `customAppBar` alike.
  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Kembali').first);
    // Let the pop transition finish; until it does, the screen underneath is
    // offstage and no finder can see it.
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Since the Xpedia redesign, the modules outside the four main tabs are
  /// reached from the fifth one, Akun.
  Future<void> openFromAccount(WidgetTester tester, String label) async {
    await tester.tap(find.text('Akun').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tapText(tester, label);
  }

  testWidgets('a new store submits verification and stocks a warehouse',
      (tester) async {
    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final email = 'e2e$stamp@probe.test';

    await CachedHelper.init();
    await initialize(onSessionExpired: () => router.go(SellerRoutes.login));
    await injector<SessionStore>().clear();

    router.go(SellerRoutes.register);
    await tester.pumpWidget(Phoenix(child: const MyApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // ------------------------------------------------------------- register
    final fields = find.byType(TextFormField);
    expect(fields, findsAtLeastNWidgets(4),
        reason: 'name, email, phone and password');
    await tester.enterText(fields.at(0), 'E2E Probe');
    await tester.enterText(fields.at(1), email);
    await tester.enterText(fields.at(2), '0819${stamp.substring(stamp.length - 6)}');
    await tester.enterText(fields.at(3), 'Password123');
    await tester.pump();

    final registerButton =
        find.widgetWithText(XButton, 'Lanjutkan Registrasi');
    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    // Registration chains register -> verify -> login, then the bootstrap sends
    // an account with no store to the picker rather than straight home.
    await pumpUntil(tester, find.text('Pilih toko'));
    expect(find.textContaining('belum punya toko'), findsOneWidget);

    // ---------------------------------------------------------- open a store
    await tester.tap(find.byType(FloatingActionButton));
    await pumpUntil(tester, find.text('Toko baru'));

    final storeFields = find.byType(TextFormField);
    await tester.enterText(storeFields.at(0), 'Toko E2E $stamp');
    await tester.pump();
    await tapButton(tester, 'Buka toko');
    await pumpUntil(tester, find.text('Beranda'));

    // A store opens inactive, and Beranda's status strip says so.
    expect(find.textContaining('Toko belum aktif'), findsOneWidget);

    // ---------------------------------------------------------- verification
    await openFromAccount(tester, 'Verifikasi Toko');
    await pumpUntil(tester, find.text('Ajukan verifikasi'));

    final vFields = find.byType(TextFormField);
    // Unique per run: since API v1.7.0 a KTP number already on another
    // seller's verification is refused with 409 DUPLICATE_IDENTITY.
    final ktp = '3171${stamp.substring(stamp.length - 12)}';
    await tester.enterText(vFields.at(0), ktp); // KTP
    await tester.enterText(vFields.at(2), 'BCA'); // bank
    await tester.enterText(vFields.at(3), 'E2E Probe'); // account holder
    await tester.enterText(vFields.at(4), '1234567890'); // account number
    await tester.pump();

    final submitVerification = find.widgetWithText(XButton, 'Kirim pengajuan');
    await tester.ensureVisible(submitVerification);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(submitVerification);
    // Submitting flips the screen to the status view, which is also the only
    // place documents can be attached — the endpoint rejects uploads before a
    // request exists.
    await pumpUntil(tester, find.text('Menunggu ditinjau'));
    expect(find.text('Dokumen'), findsOneWidget);
    expect(find.textContaining('Masih kurang'), findsOneWidget);

    await back(tester);
    await pumpUntil(tester, find.text('Beranda'));

    // ------------------------------------------------------------- warehouse
    await openFromAccount(tester, 'Gudang & Stok');
    await pumpUntil(tester, find.textContaining('Belum ada gudang'));

    // S-25's add tile, which names the first warehouse differently.
    await tapText(tester, 'Buat Gudang Pertama');
    await pumpUntil(tester, find.text('Gudang baru'));

    final wFields = find.byType(TextFormField);
    await tester.enterText(wFields.at(0), 'Gudang E2E');
    await tester.enterText(wFields.at(1), 'Jl. Percobaan 1');
    await tester.enterText(wFields.at(2), '13920');
    await tester.pump();

    // Province and city come from the master data added in v1.2.0, and
    // choosing them is what fills the new `city_id` column. The lists load
    // over the network, so wait for the hint rather than settling.
    await pumpUntil(tester, find.text('Pilih provinsi'));
    await tester.tap(find.text('Pilih provinsi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DKI Jakarta').last);
    await tester.pumpAndSettle();

    await pumpUntil(tester, find.text('Pilih kota'));
    await tester.tap(find.text('Pilih kota'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jakarta').last);
    await tester.pumpAndSettle();

    // The escape hatch stays on offer: the seed master holds eleven provinces
    // and fifteen cities, and does not contain Jakarta Timur.
    expect(find.textContaining('tidak ada di daftar'), findsOneWidget);

    await tapButton(tester, 'Tambah gudang');
    // Waiting on the default pill rather than the name: the name is still in
    // the sheet's own text field until the sheet closes, so `find.text` would
    // match it a beat too early.
    await pumpUntil(tester, find.text('Gudang Utama'));

    // The server marks the first warehouse as the store's default, whatever the
    // client asked for — and the list has to show that rather than guess.
    expect(find.text('Gudang E2E'), findsOneWidget);

    // ----------------------------------------------------------- empty stock
    await tapText(tester, 'Atur Stok');
    await pumpUntil(tester, find.textContaining('Belum ada stok'));
    expect(find.text('Stok masuk'), findsWidgets);

    await back(tester);
    await pumpUntil(tester, find.text('Gudang E2E'));
    await back(tester);
    await pumpUntil(tester, find.text('Beranda'));

    // --------------------------------------------------------------- couriers
    await openFromAccount(tester, 'Kurir Aktif');
    await pumpUntil(tester, find.byType(XSwitch));

    // A new store has no restriction, which the backend treats as "every
    // courier" rather than "none" — so S-24 shows every switch on.
    expect(find.textContaining('Semua kurir aktif'), findsOneWidget);

    // Switching one off turns the open default into a whitelist of the rest.
    await tester.tap(find.byType(XSwitch).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tapButton(tester, 'Simpan Pengaturan Kurir');
    await pumpUntil(tester, find.text('Pengaturan kurir tersimpan.'));

    expect(find.textContaining('Semua kurir aktif'), findsNothing);
    expect(find.textContaining('hanya dapat memilih kurir'), findsOneWidget);

    // ------------------------------------------------------------ promotions
    // Exercised here rather than against the seed store because a voucher and
    // a flash sale can never be deleted — no route on either path implements
    // DELETE — so the residue has to land on a store nobody else uses.
    await back(tester);
    await pumpUntil(tester, find.text('Beranda'));

    await openFromAccount(tester, 'Campaign & Promo');
    await pumpUntil(tester, find.text('Belum ada voucher toko.'));

    // ------------------------------------------------------------- voucher
    await tapButton(tester, 'Buat Voucher');
    await pumpUntil(tester, find.text('Voucher baru'));

    final voucherFields = find.byType(TextFormField);
    await tester.enterText(voucherFields.at(0), 'Diskon E2E');
    // Field 1 is the optional code, left blank so the server generates one.
    await tester.enterText(voucherFields.at(2), '10'); // percentage
    await tester.pump();
    // Skipping the optional max-discount and min-spend fields; quota and the
    // per-buyer cap are both required, and omitting either is a 500 rather
    // than a validation error.
    final quotaField = find.widgetWithText(TextFormField, 'Kuota voucher');
    await tester.ensureVisible(quotaField);
    await tester.enterText(quotaField, '50');
    await tester.pump();

    await tapButton(tester, 'Buat voucher');
    await pumpUntil(tester, find.text('Diskon E2E'));

    // The code was generated server-side, so the card shows something the form
    // never typed — proof the list was re-read rather than assembled locally.
    expect(find.textContaining('VC-'), findsOneWidget);
    expect(find.text('0 / 50'), findsOneWidget);
    expect(find.text('Sedang Berjalan'), findsOneWidget,
        reason: 'the window opens today, so the phase is derived as running');

    // ---------------------------------------------------------- flash sale
    await tester.tap(find.text('Flash Sale'));
    await pumpUntil(tester, find.text('Belum ada flash sale.'));

    await tapButton(tester, 'Buat Flash Sale');
    await pumpUntil(tester, find.text('Flash sale baru'));

    await tester.enterText(find.byType(TextFormField).first, 'Kilat E2E');
    await tester.pump();
    await tapButton(tester, 'Buat flash sale');
    await pumpUntil(tester, find.text('Kilat E2E'));

    // The form defaults the start to now, so the server's CASE expression
    // makes this one `active` at creation. A sale scheduled for later would be
    // born `scheduled` and depend on a cron worker to ever start — which is
    // why the form warns about that case and defaults away from it.
    expect(find.text('Sedang Berjalan'), findsOneWidget);
    expect(find.text('Tidak jalan'), findsNothing);

    // ------------------------------------------------- one product into it
    await tester.tap(find.text('Kilat E2E'));
    await pumpUntil(tester, find.text('Belum ada produk di flash sale ini.'));

    // The store has no products, so the picker has to say that rather than
    // offer an empty list.
    await tester.tap(find.byType(FloatingActionButton));
    await pumpUntil(tester, find.textContaining('belum punya produk'));

    // -------------------------------------------------- bundles & showcases
    // Written against the throwaway store because a bundle can never be
    // deleted — only switched off — so this would be permanent residue in a
    // seed store.
    await dismissSheet(tester);
    await back(tester); // leave the flash sale's contents
    // Back on the promotions screen, still on the flash sale tab — the sale
    // created a moment ago is what proves we landed there.
    await pumpUntil(tester, find.text('Kilat E2E'));
    await back(tester); // leave promotions
    await pumpUntil(tester, find.text('Beranda'));

    await openFromAccount(tester, 'Kelola Storefront');
    // S-34 is one page — store card, banner, showcases, then bundles — so the
    // bundle section starts below the fold.
    await pumpUntil(tester, find.text('Banner Promosi Toko'));
    await tester.scrollUntilVisible(
      find.text('Belum ada etalase.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpUntil(tester, find.text('Belum ada etalase.'));
    await tester.scrollUntilVisible(
      find.text('Belum ada bundel produk.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // A bundle needs at least one product and this store has none, so the
    // form has to say so rather than offering an empty picker.
    await tapButton(tester, 'Tambah Bundel');
    await pumpUntil(tester, find.text('Bundel baru'));
    expect(find.textContaining('belum punya produk untuk dibundel'),
        findsOneWidget);
    expect(find.textContaining('tidak bisa diubah setelah dibuat'),
        findsOneWidget,
        reason: 'bundle contents are final, and the form says so up front');

    await dismissSheet(tester);

    // ------------------------------------------------------------ showcase
    // Same page, back up to the showcases.
    await tapButton(tester, 'Tambah Etalase');
    await pumpUntil(tester, find.text('Etalase baru'));
    await tester.enterText(find.byType(TextFormField).first, 'Etalase E2E');
    await tester.pump();
    await tapButton(tester, 'Buat etalase');
    await pumpUntil(tester, find.text('Etalase E2E'));

    // Unlike everything else built lately, a showcase is fully editable —
    // both controls have to be there.
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.text('Etalase E2E'));
    await pumpUntil(tester, find.text('Belum ada produk aktif di etalase ini.'));

    // The trap worth guarding: a draft can be added and then never appears.
    expect(find.textContaining('Hanya produk aktif yang tampil'),
        findsOneWidget);

    // ------------------------------------------- product with two variants
    // S-27's create chain: one POST makes the product *and* a generated
    // variant; the form turns that into the first row and adds the rest.
    // Proving it means reading the product back from the server.
    await back(tester);
    await pumpUntil(tester, find.text('Etalase E2E'));
    await back(tester);
    // Back on the shell, where the bottom navigation is the only 'Akun'.
    await pumpUntil(tester, find.text('Akun'));
    await tester.tap(find.text('Produk').last);
    await tester.pump(const Duration(milliseconds: 400));
    // The product list's own FAB, not a stale one from a screen just popped.
    final addProduct =
        find.widgetWithText(FloatingActionButton, 'Tambah Produk');
    await pumpUntil(tester, addProduct);
    await tester.tap(addProduct);
    await pumpUntil(tester, find.text('Informasi Produk'));

    final productName = 'Kaos E2E $stamp';
    final productFields = find.byType(TextFormField);
    await tester.enterText(productFields.at(0), productName); // Nama Produk
    await tester.pump();

    await tapText(tester, 'Pilih kategori');
    await pumpUntil(tester, find.text('Kategori Produk'));
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    // Price of the first row, before variants copy it.
    await tester.enterText(productFields.at(1), '75000');
    await tester.pump();

    Future<void> addVariant(String value) async {
      await tapText(tester, 'Tambah');
      await pumpUntil(tester, find.byType(AlertDialog));
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        value,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();
    }

    await addVariant('Merah');
    await addVariant('Biru');
    expect(find.text('Merah'), findsWidgets);
    expect(find.text('Biru'), findsWidgets);

    // Further down the lazy form; scroll to it and find it by its suffix.
    await tester.scrollUntilVisible(find.textContaining('Berat Paket'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.widgetWithText(TextFormField, 'Gram'), '250');
    await tester.pump();

    await tester.tap(find.text('Simpan Draf'));
    await pumpUntil(tester, find.text(productName),
        timeout: const Duration(seconds: 40));

    // Read back: two variant cards, no phantom generated one.
    await tester.tap(find.text(productName));
    await pumpUntil(tester, find.text('Informasi Produk'));
    final form = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Varian Produk'), 300,
        scrollable: form);
    await tester.scrollUntilVisible(find.text('Biru'), 200, scrollable: form);
    expect(find.text('Merah'), findsWidgets);
    expect(find.text('Varian utama'), findsNothing,
        reason: 'the generated default must have become "Merah"');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
