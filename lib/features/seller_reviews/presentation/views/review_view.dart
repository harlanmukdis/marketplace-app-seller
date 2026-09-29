import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/model/review/product_review.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/review_cubit.dart';

/// "Ulasan Produk" (S-37): summary, filters, review cards with one reply.
///
/// Departures, because of the API: no "Dengan Foto" filter or review photos
/// (`review_media` is never returned), no reviewer name (not joined — shown
/// as "Pembeli"), and no delete — the seller can only reply or report, which
/// is also what the blueprint allows.
class ReviewView extends StatelessWidget {
  const ReviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ReviewCubit>(
      create: (_) => ReviewCubit()..load(),
      child: BlocBuilder<ReviewCubit, ReviewState>(
        builder: (context, s) => Scaffold(
          backgroundColor: XColors.canvas,
          appBar: const XAppBar(title: 'Ulasan Produk'),
          body: s.loading
              ? const LoadingIndicatorView(
                  message: 'Membaca ulasan tiap produk')
              : s.error != null
                  ? ErrorStateView(
                      error: s.error!,
                      onRetry: ReviewCubit.get(context).load,
                    )
                  : RefreshIndicator(
                      onRefresh: ReviewCubit.get(context).load,
                      child: ListView(
                        padding: const EdgeInsets.all(XSpace.screen),
                        children: <Widget>[
                          _Summary(state: s),
                          const SizedBox(height: XSpace.cardGap),
                          _Filters(state: s),
                          const SizedBox(height: XSpace.cardGap),
                          if (s.visible.isEmpty)
                            XEmptyState(
                              icon: Icons.rate_review_outlined,
                              title: s.reviews.isEmpty
                                  ? 'Belum ada ulasan'
                                  : 'Tidak ada ulasan di filter ini',
                              message: s.reviews.isEmpty
                                  ? 'Ulasan muncul setelah pembeli '
                                      'menyelesaikan pesanan.'
                                  : null,
                            )
                          else
                            for (final r in s.visible) ...<Widget>[
                              _ReviewCard(
                                review: r,
                                busy: s.busyId == r.id,
                              ),
                              const SizedBox(height: XSpace.cardGap),
                            ],
                          if (s.truncated)
                            Text(
                              'Menampilkan ulasan dari 40 produk dengan ulasan '
                              'terbanyak.',
                              textAlign: TextAlign.center,
                              style: XText.caption,
                            ),
                          const SizedBox(height: XSpace.s12),
                          const XBanner(
                            tone: XTone.warning,
                            icon: Icons.lightbulb_outline,
                            title: 'Pertahankan SLA Tanggapan.',
                            message: 'Membalas ulasan dalam 24 jam menjaga '
                                'kepercayaan pembeli. Balasan tidak bisa '
                                'diubah setelah dikirim.',
                          ),
                          const SizedBox(height: XSpace.s24),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.state});

  final ReviewState state;

  @override
  Widget build(BuildContext context) {
    final counts = <int, int>{
      for (var s = 1; s <= 5; s++)
        s: state.reviews.where((r) => r.rating == s).length,
    };
    final max = counts.values.fold(0, (a, b) => a > b ? a : b);
    return XCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 108,
                padding: const EdgeInsets.all(XSpace.s12),
                decoration: BoxDecoration(
                  color: XColors.brandSubtle,
                  borderRadius: BorderRadius.circular(XRadius.md),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      state.reviews.isEmpty
                          ? '–'
                          : state.average
                              .toStringAsFixed(1)
                              .replaceAll('.', ','),
                      style: XText.headingXL.copyWith(color: XColors.brandNavy),
                    ),
                    _Stars(rating: state.average.round()),
                    Text('${state.reviews.length} ulasan',
                        style: XText.caption),
                  ],
                ),
              ),
              const SizedBox(width: XSpace.s16),
              Expanded(
                child: Column(
                  children: <Widget>[
                    for (var star = 5; star >= 1; star--)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: <Widget>[
                            Text('$star ★', style: XText.labelS),
                            const SizedBox(width: XSpace.s6),
                            Expanded(
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(XRadius.full),
                                child: LinearProgressIndicator(
                                  value: max == 0 ? 0 : counts[star]! / max,
                                  minHeight: 6,
                                  backgroundColor: XColors.sunken,
                                  color: XColors.signatureGold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: XSpace.s12),
            child: Divider(height: 1, color: XColors.borderSubtle),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryStat(
                  icon: Icons.sentiment_satisfied_alt_outlined,
                  tone: XTone.success,
                  value: state.reviews.isEmpty
                      ? '–'
                      : '${(counts[5]! + counts[4]!) * 100 ~/ state.reviews.length}%',
                  label: 'Ulasan Positif (4–5★)',
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  icon: Icons.reply_rounded,
                  tone: XTone.info,
                  value: state.reviews.isEmpty
                      ? '–'
                      : '${state.replyRate.round()}% Dibalas',
                  label: '${state.countOf(ReviewFilter.unreplied)} menunggu',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final XTone tone;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: tone.background,
            borderRadius: BorderRadius.circular(XRadius.md),
          ),
          child: Icon(icon, size: 18, color: tone.foreground),
        ),
        const SizedBox(width: XSpace.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(value, style: XText.titleM),
              Text(label, style: XText.caption),
            ],
          ),
        ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.state});

  final ReviewState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ReviewFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: XSpace.s8),
        itemBuilder: (context, i) {
          final f = ReviewFilter.values[i];
          final selected = f == state.filter;
          return ChoiceChip(
            label: Text('${f.label}  ${state.countOf(f)}'),
            selected: selected,
            showCheckmark: false,
            labelStyle: XText.labelL.copyWith(
              color: selected ? XColors.textOnBrand : XColors.textPrimary,
            ),
            selectedColor: XColors.primary,
            backgroundColor: XColors.surface,
            side: BorderSide(
              color: selected ? XColors.primary : XColors.borderSubtle,
            ),
            shape: const StadiumBorder(),
            onSelected: (_) => ReviewCubit.get(context).setFilter(f),
          );
        },
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 16,
            color: XColors.signatureGold,
          ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.busy});

  final ProductReview review;
  final bool busy;

  Future<void> _reply(BuildContext context) async {
    final cubit = ReviewCubit.get(context);
    final controller = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(XSpace.screen),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Balas Ulasan', style: XText.headingM),
                const SizedBox(height: XSpace.s4),
                Text(
                  'Balasan tampil publik dan tidak bisa diubah atau dihapus.',
                  style: XText.bodyS,
                ),
                const SizedBox(height: XSpace.s12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    hintText: 'Terima kasih atas ulasannya…',
                  ),
                ),
                const SizedBox(height: XSpace.s12),
                XButton(
                  label: 'Kirim Balasan',
                  size: XButtonSize.large,
                  expand: true,
                  onPressed: () =>
                      Navigator.of(sheet).pop(controller.text.trim()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (text == null || text.isEmpty || !context.mounted) return;
    final error = await cubit.reply(review, text);
    if (!context.mounted) return;
    error == null
        ? showSuccessSnackBar(context, 'Balasan terkirim.')
        : showErrorSnackBar(context, error);
  }

  Future<void> _report(BuildContext context) async {
    final cubit = ReviewCubit.get(context);
    const reasons = <String>[
      'Berisi kata kasar atau SARA',
      'Tidak berhubungan dengan produk',
      'Promosi atau spam',
      'Mengandung data pribadi',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(XSpace.screen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Laporkan Pelanggaran', style: XText.headingM),
                  Text(
                    'Ulasan ditinjau tim moderasi; tidak langsung disembunyikan.',
                    style: XText.bodyS,
                  ),
                ],
              ),
            ),
            for (final r in reasons)
              ListTile(
                title: Text(r, style: XText.bodyM),
                onTap: () => Navigator.of(sheet).pop(r),
              ),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted) return;
    final error = await cubit.report(review, reason);
    if (!context.mounted) return;
    error == null
        ? showSuccessSnackBar(context, 'Ulasan dilaporkan ke tim moderasi.')
        : showErrorSnackBar(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final reply = review.reply;
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 14,
                backgroundColor: XColors.brandSubtle,
                child: Icon(Icons.person_outline,
                    size: 16, color: XColors.primary),
              ),
              const SizedBox(width: XSpace.s8),
              Expanded(
                child: Text(
                  review.isAnonymous ? 'Anonim' : 'Pembeli ••••••',
                  style: XText.titleM,
                ),
              ),
              Text(formatDateTime(review.createdAt), style: XText.caption),
            ],
          ),
          const SizedBox(height: XSpace.s8),
          Row(
            children: <Widget>[
              const XChip(
                label: 'Pembelian terverifikasi',
                tone: XTone.success,
                icon: Icons.verified_outlined,
              ),
              const Spacer(),
              _Stars(rating: review.rating),
            ],
          ),
          const SizedBox(height: XSpace.s12),
          Container(
            padding: const EdgeInsets.all(XSpace.s8),
            decoration: BoxDecoration(
              color: XColors.canvas,
              borderRadius: BorderRadius.circular(XRadius.md),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.inventory_2_outlined,
                    size: 18, color: XColors.textTertiary),
                const SizedBox(width: XSpace.s8),
                Expanded(
                  child: Text(
                    review.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: XText.bodyM,
                  ),
                ),
              ],
            ),
          ),
          if ((review.comment ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: XSpace.s12),
            Text(review.comment!, style: XText.bodyM),
          ],
          const SizedBox(height: XSpace.s12),
          if (reply != null)
            Container(
              padding: const EdgeInsets.all(XSpace.s12),
              decoration: BoxDecoration(
                color: XColors.canvas,
                borderRadius: BorderRadius.circular(XRadius.md),
                border: Border.all(color: XColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.storefront_outlined,
                          size: 16, color: XColors.primary),
                      const SizedBox(width: XSpace.s6),
                      Expanded(
                        child: Text('Balasan Toko',
                            style: XText.titleM
                                .copyWith(color: XColors.brandNavy)),
                      ),
                      Text(formatDateTime(reply.createdAt),
                          style: XText.caption),
                    ],
                  ),
                  const SizedBox(height: XSpace.s4),
                  Text(reply.text, style: XText.bodyS),
                ],
              ),
            )
          else
            Row(
              children: <Widget>[
                XButton.secondary(
                  label: 'Balas Ulasan',
                  icon: Icons.reply_rounded,
                  size: XButtonSize.small,
                  loading: busy,
                  onPressed: () => _reply(context),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: busy ? null : () => _report(context),
                  style: TextButton.styleFrom(
                    foregroundColor: XColors.textSecondary,
                  ),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Laporkan'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
