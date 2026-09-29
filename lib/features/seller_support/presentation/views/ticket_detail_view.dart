import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/datasources/remote/service/media_service.dart';
import '../../../../core/domain/model/support/support_ticket.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/support_cubit.dart';

/// "Detail Tiket Bantuan" (S-42): the ticket, then its thread with the team.
class TicketDetailView extends StatelessWidget {
  const TicketDetailView({super.key, required this.ticketId});

  final int ticketId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TicketCubit>(
      create: (_) => TicketCubit(ticketId)..load(),
      child: const _TicketBody(),
    );
  }
}

class _TicketBody extends StatefulWidget {
  const _TicketBody();

  @override
  State<_TicketBody> createState() => _TicketBodyState();
}

class _TicketBodyState extends State<_TicketBody> {
  final TextEditingController _message = TextEditingController();
  PickedFile? _attachment;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text;
    final error =
        await TicketCubit.get(context).reply(text, attachment: _attachment);
    if (!mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    _message.clear();
    setState(() => _attachment = null);
  }

  Future<void> _pickAttachment() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    final bytes = file?.bytes;
    if (bytes == null || !mounted) return;
    setState(() => _attachment = PickedFile(bytes: bytes, name: file!.name));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TicketCubit, TicketState>(
      builder: (context, state) {
        final title =
            state is TicketLoaded ? '#${state.ticket.ticketNumber}' : 'Tiket';
        return Scaffold(
          backgroundColor: XColors.canvas,
          appBar: XAppBar(title: title),
          body: switch (state) {
            TicketInProgress() => const LoadingIndicatorView(),
            TicketFailure(:final error) => ErrorStateView(
                error: error,
                onRetry: TicketCubit.get(context).load,
              ),
            TicketLoaded() => _thread(state),
          },
          bottomNavigationBar: state is TicketLoaded && !state.ticket.isClosed
              ? _composer(state)
              : null,
        );
      },
    );
  }

  Widget _thread(TicketLoaded state) {
    final t = state.ticket;
    return ListView(
      padding: const EdgeInsets.all(XSpace.screen),
      children: <Widget>[
        XCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  XChip(label: SupportCategory.label(t.category)),
                  const Spacer(),
                  XChip(
                    label: SupportTicketStatus.label(t.status),
                    tone: t.isClosed ? XTone.completed : XTone.processing,
                  ),
                ],
              ),
              const SizedBox(height: XSpace.s12),
              Text(t.subject, style: XText.titleL),
              const SizedBox(height: XSpace.s8),
              Text(t.description, style: XText.bodyM),
              const SizedBox(height: XSpace.s8),
              Text('Dibuat ${formatDateTime(t.createdAt)}',
                  style: XText.caption),
            ],
          ),
        ),
        const SizedBox(height: XSpace.sectionGap),
        if (state.messages.isEmpty)
          const XEmptyState(
            icon: Icons.forum_outlined,
            title: 'Belum ada balasan',
            message: 'Tim Xpedia 911 akan membalas di sini.',
          ),
        for (final m in state.messages) _Bubble(message: m),
      ],
    );
  }

  Widget _composer(TicketLoaded state) {
    return Material(
      color: XColors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            XSpace.s12,
            XSpace.s8,
            XSpace.s8,
            XSpace.s8 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Lampirkan bukti',
                onPressed: state.isSending ? null : _pickAttachment,
                icon: Icon(
                  _attachment == null
                      ? Icons.attach_file_rounded
                      : Icons.check_circle_rounded,
                  color: _attachment == null
                      ? XColors.textSecondary
                      : XColors.success,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _message,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: _attachment == null
                        ? 'Tulis balasan'
                        : 'Lampiran: ${_attachment!.name}',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: XSpace.s8),
              IconButton.filled(
                tooltip: 'Kirim',
                onPressed: state.isSending ? null : _send,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final SupportTicketMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = !message.isAdminReply;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: XSpace.s8),
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.all(XSpace.s12),
        decoration: BoxDecoration(
          color: mine ? XColors.primary : XColors.surface,
          borderRadius: BorderRadius.circular(XRadius.lg),
          border: mine ? null : Border.all(color: XColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!mine)
              Text('Tim Xpedia 911',
                  style: XText.labelM.copyWith(color: XColors.primary)),
            if (message.attachmentUrl != null) ...<Widget>[
              _Attachment(url: message.attachmentUrl!, mine: mine),
              const SizedBox(height: XSpace.s6),
            ],
            Text(
              message.message,
              style: XText.bodyM.copyWith(
                color: mine ? XColors.textOnBrand : XColors.textPrimary,
              ),
            ),
            const SizedBox(height: XSpace.s4),
            Text(
              formatDateTime(message.createdAt),
              style: XText.caption.copyWith(
                color: mine
                    ? XColors.textOnBrand.withValues(alpha: 0.7)
                    : XColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Attachment extends StatelessWidget {
  const _Attachment({required this.url, required this.mine});

  final String url;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final isPdf = url.toLowerCase().endsWith('.pdf');
    if (isPdf) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.picture_as_pdf_outlined,
              color: mine ? XColors.textOnBrand : XColors.danger),
          const SizedBox(width: XSpace.s6),
          Text('Dokumen PDF',
              style: XText.labelM.copyWith(
                color: mine ? XColors.textOnBrand : XColors.textPrimary,
              )),
        ],
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(XRadius.md),
      child: Image.network(
        normaliseUploadUrl(url),
        width: 200,
        height: 140,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(
          width: 200,
          height: 60,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    );
  }
}
