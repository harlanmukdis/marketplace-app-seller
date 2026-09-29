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
import 'package:navy_wear/features/seller_catalog/presentation/views/widgets/product_card.dart';
import 'package:navy_wear/main.dart';

/// Drives the real app against the **running** marketplace API.
///
/// This is not a unit test: it boots the same widget tree `main()` does, talks
/// to `http://localhost:8000/api/v1` for real, and signs in as a seed seller.
/// It therefore needs the backend up and seeded — see
/// `docs/23-frontend-integration-guide.md` §3 for the accounts it uses.
///
///     flutter test integration_test -d macos
///
/// `DevicePreview` is skipped here on purpose: it wraps the app in a simulated
/// device frame that makes hit-testing depend on the preview's scaling.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String seedEmail = 'budi.santoso@kedaikopi.id';
  const String seedPassword = 'RahasiaAman123';

  /// Boots the app the way `main()` does, minus the preview frame, from a
  /// signed-out state so the run always starts at the login screen.
  Future<void> bootSignedOut(WidgetTester tester) async {
    await CachedHelper.init();
    await initialize(onSessionExpired: () => router.go(SellerRoutes.login));
    await injector<SessionStore>().clear();

    router.go(SellerRoutes.login);
    await tester.pumpWidget(Phoenix(child: const MyApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  /// The app talks to a real server, so a fixed `pumpAndSettle` is not enough —
  /// this pumps until [finder] appears or the budget runs out.
  ///
  /// It then keeps pumping briefly: every route here is wrapped in a
  /// fade-through transition, and a widget that merely *exists* can still be
  /// mid-animation, where it will not accept a tap.
  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) {
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        return;
      }
    }
    fail('Timed out waiting for: ${finder.describeMatch(Plurality.zero)}');
  }

  /// Every app bar's back button carries this tooltip, the redesigned
  /// `XAppBar` and the restyled `customAppBar` alike.
  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Kembali').first);
    // Let the pop transition finish; until it does, the screen underneath is
    // offstage and no finder can see it.
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// A bottom-navigation tab, by its label. `.last` because a tab's label can
  /// also appear in the screen above it ("Produk" is both).
  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Modules outside the four main tabs are reached from Akun.
  Future<void> openFromAccount(WidgetTester tester, String label) async {
    await openTab(tester, 'Akun');
    final target = find.text(label).first;
    await tester.ensureVisible(target);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(target);
  }

  testWidgets('a seller signs in and works through the catalogue',
      (tester) async {
    await bootSignedOut(tester);

    // ---------------------------------------------------------------- login
    expect(find.text('Masuk sebagai Toko'), findsOneWidget,
        reason: 'the app should start at the seller login screen');

    final fields = find.byType(TextFormField);
    expect(fields, findsAtLeastNWidgets(2));
    await tester.enterText(fields.at(0), seedEmail);
    await tester.enterText(fields.at(1), seedPassword);
    await tester.pump();

    // The tab and the button both say "Masuk"; the button is the XButton.
    await tester.tap(find.widgetWithText(XButton, 'Masuk'));
    await pumpUntil(tester, find.text('Beranda'));

    // Beranda's header names the store the session landed on, which is the
    // proof that login -> GET /me -> GET /stores all came back.
    await pumpUntil(tester, find.text('Kedai Kopi Nusantara'));
    expect(find.text('Perlu Tindakan'), findsOneWidget);
    expect(find.text('Ringkasan Toko'), findsOneWidget);

    // ------------------------------------------------------------ catalogue
    await openTab(tester, 'Produk');
    await pumpUntil(tester, find.byType(ProductCard));

    expect(find.byType(ProductCard), findsWidgets,
        reason: 'GET /stores/{id}/products should have produced rows');

    // Paging regression guard. The endpoint sends no `meta` but still caps each
    // response at 20 rows, so a catalogue read in one request is silently
    // truncated — this store's seed products sit past that cut. Scrolling to
    // one of them proves every page was fetched, not just the first.
    await tester.scrollUntilVisible(
      find.text('Kopi Arabika Gayo 250g'),
      300,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 200,
    );
    expect(find.text('Kopi Arabika Gayo 250g'), findsOneWidget);

    // The status filter is client-side, because the endpoint takes no status
    // parameter — the chips are the whole mechanism.
    expect(find.text('Semua'), findsOneWidget, reason: 'status filter chips');
    expect(find.text('Draf'), findsWidgets);

    // ----------------------------------------------------- open one product
    await tester.tap(find.byType(ProductCard).first);
    await pumpUntil(tester, find.text('Ubah Produk'));
    // The title renders while the body is still loading; wait for the form.
    await pumpUntil(tester, find.text('Informasi Produk'));

    // The edit form is fed by GET /products/{id}, so its presence proves the
    // detail payload parsed — variants, images, stock and all.
    expect(find.textContaining('Status: '), findsOneWidget);
    expect(find.textContaining('Stok tersedia'), findsOneWidget);
    expect(find.textContaining('Foto Produk'), findsOneWidget);

    // Category and type are read-only when editing: the API's PATCH accepts
    // neither, so the form must not offer them.
    expect(find.text('Kategori & jenis'), findsOneWidget);
    expect(find.text('Kategori *'), findsNothing);

    // The form is a lazy list; walk down it in the design's section order.
    final form = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Mode Stok & Pemenuhan'), 300,
        scrollable: form);
    // The v1.7.0 stock modes, as the design's 2×2 grid.
    expect(find.text('Pre-Order'), findsOneWidget);
    expect(find.text('Custom Order'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Varian Produk'), 300,
        scrollable: form);
    await tester.scrollUntilVisible(find.text('HARGA SATUAN').first, 200,
        scrollable: form);
    await tester.scrollUntilVisible(find.text('Cakupan Pengiriman *'), 300,
        scrollable: form);
    await tester.scrollUntilVisible(
        find.text('Sertifikasi Produk (BPOM / Halal / SNI)'), 300,
        scrollable: form);
    await tester.scrollUntilVisible(find.text('Xpedia Growth'), 300,
        scrollable: form);

    // --------------------------------------------------- back, then create
    await back(tester);
    await pumpUntil(tester, find.byType(ProductCard));

    await tester.tap(find.byType(FloatingActionButton));
    // "Tambah Produk" is also the FAB's label, so wait for the form itself.
    await pumpUntil(tester, find.text('Informasi Produk'));

    // Creating needs the live category tree, behind the picker row.
    expect(find.text('Kategori *'), findsOneWidget);
    expect(find.text('Pilih kategori'), findsOneWidget);
    expect(find.text('Jenis produk *'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Harga coret (opsional)'), 300,
        scrollable: find.byType(Scrollable).first);

    // ------------------------------------------------------------- orders
    // Produk is a tab now: back from the form lands on it, not on Beranda.
    await back(tester);
    await pumpUntil(tester, find.byType(ProductCard));

    await openTab(tester, 'Pesanan');
    await pumpUntil(tester, find.text('Daftar Pesanan'));

    // The privacy notice is unconditional — design rule 1 — and the tab bar is
    // the design's, with no "needs action"/accept vocabulary left.
    expect(find.textContaining('Proteksi Privasi Pembeli Aktif'),
        findsOneWidget);
    expect(find.text('Dalam Pengiriman'), findsOneWidget);
    expect(find.text('Terima pesanan'), findsNothing);

    // Store 1 has no orders since the reseed; an empty tab has to read as
    // "nothing here" rather than as a failure.
    await pumpUntil(tester, find.textContaining('Belum ada pesanan'));

    // -------------------------------------------------------------- wallet
    await openFromAccount(tester, 'Xpedia Wallet');
    await pumpUntil(tester, find.text('Saldo Tersedia'));

    // The v1.24.0 payout setup is on screen: saved accounts, max three.
    expect(find.text('Rekening Bank Pencairan'), findsOneWidget);
    expect(find.text('(0/3)'), findsOneWidget);
    expect(find.text('Riwayat Transaksi'), findsOneWidget);

    // Seed store 1 has never earned, so withdrawing is refused on the client
    // rather than at the server.
    expect(find.text('Saldo belum mencapai minimum penarikan.'),
        findsOneWidget);

    // ---------------------------------------------------------- promotions
    // Read-only against the seed store on purpose: a voucher or flash sale
    // created here could never be removed again — neither path implements
    // DELETE — so the write side is exercised in the onboarding test, which
    // works on a throwaway store.
    await back(tester);
    await openFromAccount(tester, 'Campaign & Promo');
    await pumpUntil(tester, find.textContaining('Voucher hanya bisa dibuat'));

    expect(find.text('Belum ada voucher toko.'), findsOneWidget,
        reason: 'GET /stores/1/vouchers answers an empty array');

    await tester.tap(find.text('Flash Sale'));
    await pumpUntil(tester, find.text('Belum ada flash sale.'));

    // Both lists are create-and-list only, and the screen has to say so before
    // anything is submitted rather than after.
    expect(find.textContaining('tidak bisa diubah atau dibatalkan'),
        findsOneWidget);

    // ---------------------------------------------------------------- chat
    // Only the inbox is driven here. The thread needs a conversation id, and
    // no conversation is seed data — the backend has no way for a seller to
    // create or even list one, which is the whole finding. Pinning the test to
    // an id that happens to exist today would make it fail mysteriously after
    // the next reseed, so the thread's contract is verified against the API
    // directly instead (read, reply, read-receipt and long-poll all confirmed).
    await back(tester);
    await openTab(tester, 'Chat');
    await pumpUntil(tester, find.text('Kotak masuk toko belum bisa dibuat'));

    // GET /chat/conversations answers 200 with the account's conversations as
    // a *buyer*. The screen must not pass those off as the store's enquiries.
    expect(find.text('Percakapan Anda sebagai pembeli'), findsOneWidget);
    expect(find.textContaining('GET /stores/{id}/chat/conversations'),
        findsOneWidget,
        reason: 'the screen names the endpoint the backend still owes');

    // The thread is reachable meanwhile, which is what keeps the working half
    // of chat usable.
    expect(find.text('Buka percakapan lewat ID'), findsOneWidget);

    // --------------------------------------------------------- notifications
    await openFromAccount(tester, 'Pusat Notifikasi');
    // Either a list or the empty state resolves; the settings action is on
    // the bar in both cases, so it is the stable thing to wait for.
    await pumpUntil(tester, find.byIcon(Icons.tune_rounded));

    // The mute switches. Asserting the copy rather than the rows: the list is
    // derived from the types this account has *received*, so its contents
    // depend on traffic while this explanation never does.
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await pumpUntil(tester, find.text('Pengaturan notifikasi'));

    expect(find.textContaining('tetap masuk ke daftar di aplikasi ini'),
        findsOneWidget,
        reason: 'in_app cannot be muted, and the sheet has to say why');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
