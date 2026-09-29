import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/support/support_ticket.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/support_cubit.dart';

/// "Xpedia 911" (S-41): the four categories, then the account's tickets.
class SupportView extends StatelessWidget {
  const SupportView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SupportCubit>(
      create: (_) => SupportCubit()..load(),
      child: const _SupportBody(),
    );
  }
}

class _SupportBody extends StatelessWidget {
  const _SupportBody();

  Future<void> _create(BuildContext context, {String? category}) async {
    final cubit = SupportCubit.get(context);
    final draft = await showModalBottomSheet<_TicketDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewTicketSheet(category: category),
    );
    if (draft == null || !context.mounted) return;
    final (id, error) = await cubit.create(
      category: draft.category,
      subject: draft.subject,
      description: draft.description,
    );
    if (!context.mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    if (id != null) await context.push(SellerRoutes.supportTicketPath(id));
  }

  static IconData _icon(String category) => switch (category) {
        SupportCategory.orderTransaction => Icons.local_shipping_outlined,
        SupportCategory.paymentWallet => Icons.account_balance_wallet_outlined,
        SupportCategory.accountSecurity => Icons.shield_outlined,
        _ => Icons.report_gmailerrorred_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: const XAppBar(title: 'Xpedia 911'),
      body: BlocBuilder<SupportCubit, SupportState>(
        builder: (context, state) {
          final tickets =
              state is SupportLoaded ? state.tickets : const <SupportTicket>[];
          return RefreshIndicator(
            onRefresh: SupportCubit.get(context).load,
            child: ListView(
              padding: const EdgeInsets.all(XSpace.screen),
              children: <Widget>[
                Text(
                  'Pilih kategori kendala untuk bantuan tim operasional Xpedia.',
                  style: XText.bodyS,
                ),
                const SizedBox(height: XSpace.s12),
                const XBanner(
                  tone: XTone.info,
                  icon: Icons.shield_outlined,
                  title: 'Bantuan Seller.',
                  message: 'Tiket langsung ke tim platform, terpisah dari chat '
                      'dengan pembeli.',
                ),
                const SizedBox(height: XSpace.cardGap),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: XSpace.cardGap,
                  crossAxisSpacing: XSpace.cardGap,
                  childAspectRatio: 0.95,
                  children: <Widget>[
                    for (final c in SupportCategory.all)
                      XCard(
                        onTap: () => _create(context, category: c),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: XColors.brandSubtle,
                                borderRadius: BorderRadius.circular(XRadius.md),
                              ),
                              child: Icon(_icon(c), color: XColors.primary),
                            ),
                            const SizedBox(height: XSpace.s12),
                            Text(SupportCategory.label(c), style: XText.titleM),
                            const SizedBox(height: XSpace.s4),
                            Expanded(
                              child: Text(
                                c.supportHint,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: XText.bodyS,
                              ),
                            ),
                            Text('Pilih →',
                                style: XText.labelM
                                    .copyWith(color: XColors.primary)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: XSpace.sectionGap),
                XSectionHeader(
                  title: 'Tiket Saya',
                  trailing: '${tickets.length} laporan',
                ),
                switch (state) {
                  SupportInProgress() => const Padding(
                      padding: EdgeInsets.all(XSpace.s24),
                      child: LoadingIndicatorView(),
                    ),
                  SupportFailure(:final error) => ErrorStateView(
                      error: error,
                      onRetry: SupportCubit.get(context).load,
                    ),
                  SupportLoaded() when tickets.isEmpty => const XEmptyState(
                      icon: Icons.support_agent_outlined,
                      title: 'Belum ada tiket',
                      message: 'Tiket yang Anda buat muncul di sini.',
                    ),
                  SupportLoaded() => Column(
                      children: <Widget>[
                        for (final t in tickets) ...<Widget>[
                          _TicketCard(ticket: t),
                          const SizedBox(height: XSpace.s8),
                        ],
                      ],
                    ),
                },
                const SizedBox(height: XSpace.s24),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Material(
        color: XColors.surface,
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(XSpace.screen),
            child: Builder(
              builder: (context) => XButton(
                label: 'Buat Tiket Bantuan Baru',
                icon: Icons.add_circle_outline,
                size: XButtonSize.large,
                expand: true,
                onPressed: () => _create(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final tone = switch (ticket.status) {
      SupportTicketStatus.open => XTone.info,
      SupportTicketStatus.inProgress => XTone.processing,
      SupportTicketStatus.resolved => XTone.completed,
      _ => XTone.neutral,
    };
    return XCard(
      onTap: () => context.push(SellerRoutes.supportTicketPath(ticket.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('#${ticket.ticketNumber}', style: XText.overline),
              ),
              XChip(
                  label: SupportTicketStatus.label(ticket.status), tone: tone),
            ],
          ),
          const SizedBox(height: XSpace.s8),
          Text(ticket.subject, style: XText.titleL),
          const SizedBox(height: XSpace.s8),
          Row(
            children: <Widget>[
              XChip(label: SupportCategory.label(ticket.category)),
              const Spacer(),
              Icon(Icons.schedule, size: 14, color: XColors.textTertiary),
              const SizedBox(width: XSpace.s4),
              Text(formatDateTime(ticket.createdAt), style: XText.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _TicketDraft {
  const _TicketDraft(this.category, this.subject, this.description);

  final String category;
  final String subject;
  final String description;
}

class _NewTicketSheet extends StatefulWidget {
  const _NewTicketSheet({this.category});

  final String? category;

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _description = TextEditingController();
  late String? _category = widget.category;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(XSpace.screen),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Tiket Bantuan Baru', style: XText.headingM),
                const SizedBox(height: XSpace.s16),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: <DropdownMenuItem<String>>[
                    for (final c in SupportCategory.all)
                      DropdownMenuItem<String>(
                        value: c,
                        child: Text(SupportCategory.label(c)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                  validator: (v) => v == null ? 'Pilih kategori' : null,
                ),
                const SizedBox(height: XSpace.s12),
                TextFormField(
                  controller: _subject,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Judul'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Judul wajib diisi' : null,
                ),
                const SizedBox(height: XSpace.s4),
                TextFormField(
                  controller: _description,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Jelaskan kendalanya',
                    hintText: 'Sertakan nomor pesanan bila ada.',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Deskripsi wajib diisi' : null,
                ),
                const SizedBox(height: XSpace.s20),
                XButton(
                  label: 'Kirim Tiket',
                  size: XButtonSize.large,
                  expand: true,
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    Navigator.of(context).pop(_TicketDraft(
                      _category!,
                      _subject.text.trim(),
                      _description.text.trim(),
                    ));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
