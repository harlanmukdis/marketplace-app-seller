import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/model/verification/store_verification.dart';
import '../../../../core/utils/app_styles.dart';
import '../../../../core/utils/constant.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/custom_text_form_field.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/verification_cubit/verification_cubit.dart';

/// Store verification — the only route out of `inactive`, and so the only way
/// the store ever becomes able to sell.
class VerificationView extends StatelessWidget {
  const VerificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VerificationCubit>(
      create: (_) => VerificationCubit()..load(),
      child: const _VerificationBody(),
    );
  }
}

class _VerificationBody extends StatelessWidget {
  const _VerificationBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XColors.canvas,
      appBar: const XAppBar(title: 'Verifikasi Toko'),
      body: SafeArea(
        child: BlocBuilder<VerificationCubit, VerificationState>(
          builder: (context, state) => switch (state) {
            VerificationInProgress() => const LoadingIndicatorView(),
            VerificationNoStore() => const EmptyStateView(
                icon: Icons.storefront_outlined,
                message: 'Pilih toko dulu sebelum mengajukan verifikasi.',
              ),
            VerificationFailure(:final error) => ErrorStateView(
                error: error,
                onRetry: () => VerificationCubit.get(context).load(),
              ),
            VerificationNotSubmitted() => _SubmitForm(isBusy: state.isBusy),
            VerificationLoaded() => _Status(state: state),
          },
        ),
      ),
    );
  }
}

/// Step one. Nothing can be uploaded until this exists — the document endpoint
/// answers `VERIFICATION_NOT_FOUND` without a request to hang the file on.
class _SubmitForm extends StatefulWidget {
  const _SubmitForm({required this.isBusy, this.resubmitting = false});

  final bool isBusy;
  final bool resubmitting;

  @override
  State<_SubmitForm> createState() => _SubmitFormState();
}

class _SubmitFormState extends State<_SubmitForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _idCard = TextEditingController();
  final TextEditingController _tax = TextEditingController();
  final TextEditingController _bankName = TextEditingController();
  final TextEditingController _bankAccountName = TextEditingController();
  final TextEditingController _bankAccountNumber = TextEditingController();
  final TextEditingController _picName = TextEditingController();
  final TextEditingController _picIdCard = TextEditingController();
  final TextEditingController _picEmail = TextEditingController();

  String _type = VerificationType.individual;

  @override
  void dispose() {
    _idCard.dispose();
    _tax.dispose();
    _bankName.dispose();
    _bankAccountName.dispose();
    _bankAccountNumber.dispose();
    _picName.dispose();
    _picIdCard.dispose();
    _picEmail.dispose();
    super.dispose();
  }

  bool get _isBusiness => _type == VerificationType.business;

  String? _emptyToNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final error = await VerificationCubit.get(context).submit(
      type: _type,
      idCardNumber: _emptyToNull(_idCard),
      taxNumber: _emptyToNull(_tax),
      bankName: _emptyToNull(_bankName),
      bankAccountName: _emptyToNull(_bankAccountName),
      bankAccountNumber: _emptyToNull(_bankAccountNumber),
      picName: _isBusiness ? _emptyToNull(_picName) : null,
      picIdCardNumber: _isBusiness ? _emptyToNull(_picIdCard) : null,
      picEmail: _isBusiness ? _emptyToNull(_picEmail) : null,
    );

    if (!mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(
      context,
      'Pengajuan dikirim. Sekarang unggah dokumennya.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: 20.pa,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'LANGKAH 1 DARI 2 • DATA IDENTITAS & REKENING',
                  style: XText.overline.copyWith(color: XColors.primary),
                ),
                const SizedBox(height: XSpace.s6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(XRadius.full),
                  child: LinearProgressIndicator(
                    value: 0.5,
                    minHeight: 4,
                    backgroundColor: XColors.brandSubtle,
                    color: XColors.primary,
                  ),
                ),
                const SizedBox(height: XSpace.s16),
                Text(
                  widget.resubmitting ? 'Ajukan ulang' : 'Ajukan verifikasi',
                  style: XText.headingXL,
                ),
                8.sbh,
                Text(
                  widget.resubmitting
                      ? 'Pengajuan baru dimulai dari nol — dokumen yang dulu '
                          'diunggah tidak ikut terbawa, jadi siapkan berkasnya '
                          'lagi.'
                      : 'Toko baru bisa berjualan setelah pengajuan ini '
                          'disetujui admin. Isi datanya dulu, dokumennya '
                          'diunggah di langkah berikutnya.',
                  style: AppStyles.styleRegular12(context)
                      .copyWith(color: kLightThirdColor),
                ),
                24.sbh,
                AppDropdownField<String>(
                  label: 'Jenis pengajuan',
                  value: _type,
                  items: VerificationType.all,
                  itemLabel: VerificationType.label,
                  onChanged: (value) => setState(
                    () => _type = value ?? VerificationType.individual,
                  ),
                ),
                16.sbh,
                CustomTextFormField(
                  controller: _idCard,
                  labelText: 'Nomor KTP',
                  keyboardType: TextInputType.number,
                  validator: Validators.required('Nomor KTP'),
                ),
                16.sbh,
                CustomTextFormField(
                  controller: _tax,
                  labelText: _type == VerificationType.business
                      ? 'NPWP badan usaha'
                      : 'NPWP (opsional)',
                  validator: _type == VerificationType.business
                      ? Validators.required('NPWP')
                      : Validators.optional,
                ),
                if (_isBusiness) ...<Widget>[
                  24.sbh,
                  Text('Penanggung jawab (PIC)', style: XText.titleM),
                  4.sbh,
                  Text(
                    'Wajib untuk badan usaha. KTP PIC tidak boleh sudah '
                    'terdaftar di akun seller lain.',
                    style: AppStyles.styleRegular10(context)
                        .copyWith(color: kLightThirdColor),
                  ),
                  12.sbh,
                  CustomTextFormField(
                    controller: _picName,
                    labelText: 'Nama PIC',
                    validator: Validators.required('Nama PIC'),
                  ),
                  16.sbh,
                  CustomTextFormField(
                    controller: _picIdCard,
                    labelText: 'Nomor KTP PIC',
                    keyboardType: TextInputType.number,
                    validator: Validators.required('Nomor KTP PIC'),
                  ),
                  16.sbh,
                  CustomTextFormField(
                    controller: _picEmail,
                    labelText: 'Email PIC',
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.required('Email PIC'),
                  ),
                ],
                24.sbh,
                Text('Rekening pencairan', style: XText.titleM),
                4.sbh,
                Text(
                  'Ke sinilah hasil penjualan ditarik nanti.',
                  style: AppStyles.styleRegular10(context)
                      .copyWith(color: kLightThirdColor),
                ),
                12.sbh,
                CustomTextFormField(
                  controller: _bankName,
                  labelText: 'Nama bank',
                  validator: Validators.required('Nama bank'),
                ),
                16.sbh,
                CustomTextFormField(
                  controller: _bankAccountName,
                  labelText: 'Nama pemilik rekening',
                  validator: Validators.required('Nama pemilik rekening'),
                ),
                16.sbh,
                CustomTextFormField(
                  controller: _bankAccountNumber,
                  labelText: 'Nomor rekening',
                  keyboardType: TextInputType.number,
                  validator: Validators.accountNumber,
                ),
                32.sbh,
                XButton(
                  label: 'Kirim pengajuan',
                  icon: Icons.verified_user_outlined,
                  size: XButtonSize.large,
                  expand: true,
                  loading: widget.isBusy,
                  onPressed: _submit,
                ),
                32.sbh,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Step two and onward (S-08, S-09): where the request stands, each required
/// document with its upload, what the store can do meanwhile, and history.
class _Status extends StatelessWidget {
  const _Status({required this.state});

  final VerificationLoaded state;

  Future<void> _attach(BuildContext context, String docType) async {
    final cubit = VerificationCubit.get(context);

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      // The narrower of the two upload allowlists on this backend: the document
      // endpoint takes no gif or webp, unlike /media/upload.
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    final bytes = file?.bytes;
    if (bytes == null || !context.mounted) return;

    final error = await cubit.uploadDocument(
      bytes: bytes,
      fileName: file!.name,
      docType: docType,
    );
    if (!context.mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    showSuccessSnackBar(context, '${DocumentType.label(docType)} terunggah.');
  }

  @override
  Widget build(BuildContext context) {
    final verification = state.verification;
    final missing = verification.missingDocuments;
    final required = DocumentType.requiredFor(verification.type);
    final approved = verification.status == VerificationStatus.approved;
    const gap = SizedBox(height: XSpace.cardGap);

    return RefreshIndicator(
      onRefresh: () => VerificationCubit.get(context).load(),
      child: ListView(
        padding: const EdgeInsets.all(XSpace.screen),
        children: <Widget>[
          _StatusCard(verification: verification),
          gap,
          if (!approved && missing.isNotEmpty) ...<Widget>[
            const XBanner(
              tone: XTone.warning,
              icon: Icons.schedule_rounded,
              title: 'Lengkapi dokumen.',
              message: 'Toko belum bisa memproses pesanan atau menayangkan '
                  'produk sebelum verifikasi disetujui.',
            ),
            gap,
          ],
          XCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.fact_check_outlined, color: XColors.primary),
                    const SizedBox(width: XSpace.s8),
                    Expanded(
                      child: Text('Dokumen', style: XText.titleL),
                    ),
                    Text(
                      '${required.length - missing.length} dari '
                      '${required.length}',
                      style: XText.caption,
                    ),
                  ],
                ),
                const SizedBox(height: XSpace.s4),
                Text(
                  missing.isEmpty
                      ? 'Semua dokumen yang diminta sudah terunggah.'
                      : 'Masih kurang: '
                          '${missing.map(DocumentType.label).join(', ')}.',
                  style: XText.bodyS.copyWith(
                    color: missing.isEmpty
                        ? XColors.successStrong
                        : XColors.warningStrong,
                  ),
                ),
                const SizedBox(height: XSpace.s12),
                for (final docType in required) ...<Widget>[
                  _DocumentRow(
                    docType: docType,
                    document: verification.documents
                        .where((doc) => doc.docType == docType)
                        .firstOrNull,
                    onAttach: state.canAttachDocuments && !state.isBusy
                        ? () => _attach(context, docType)
                        : null,
                  ),
                  const SizedBox(height: XSpace.s8),
                ],
              ],
            ),
          ),
          gap,
          XCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Data Pengajuan', style: XText.titleL),
                const SizedBox(height: XSpace.s8),
                XKeyValue(
                  label: 'Jenis',
                  value: VerificationType.label(verification.type),
                ),
                XKeyValue(
                  label: 'Nomor KTP',
                  value: _mask(verification.idCardNumber),
                ),
                XKeyValue(label: 'NPWP', value: verification.taxNumber ?? '-'),
                XKeyValue(
                  label: 'Rekening',
                  value: verification.bankAccountNumber == null
                      ? '-'
                      : '${verification.bankName ?? ''} '
                              '${_mask(verification.bankAccountNumber)}'
                          .trim(),
                ),
              ],
            ),
          ),
          gap,
          _AccessCard(approved: approved),
          if (verification.history.isNotEmpty) ...<Widget>[
            gap,
            XCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Riwayat', style: XText.titleL),
                  const SizedBox(height: XSpace.s8),
                  for (final event in verification.history.reversed)
                    XKeyValue(
                      label: VerificationStatus.label(event.toStatus),
                      value: formatDateTime(event.createdAt),
                    ),
                ],
              ),
            ),
          ],
          if (state.canResubmit) ...<Widget>[
            const SizedBox(height: XSpace.sectionGap),
            _SubmitForm(isBusy: state.isBusy, resubmitting: true),
          ],
          const SizedBox(height: XSpace.s24),
        ],
      ),
    );
  }

  /// `3171234567890001` -> `•••• •••• •••• 0001`.
  static String _mask(String? value) {
    if (value == null || value.isEmpty) return '-';
    if (value.length <= 4) return value;
    return '•••• ${value.substring(value.length - 4)}';
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.verification});

  final StoreVerification verification;

  @override
  Widget build(BuildContext context) {
    final (XTone tone, IconData icon, String title, String note) =
        switch (verification.status) {
      VerificationStatus.approved => (
          XTone.success,
          Icons.verified_rounded,
          'Verifikasi Disetujui',
          'Toko sudah aktif dan bisa berjualan.',
        ),
      VerificationStatus.rejected => (
          XTone.danger,
          Icons.gpp_bad_outlined,
          'Pengajuan Ditolak',
          verification.rejectionReason ??
              'Pengajuan ditolak tanpa alasan tertulis.',
        ),
      _ => (
          XTone.warning,
          Icons.hourglass_top_rounded,
          'Pengajuan Sedang Diproses',
          'Dokumen diterima tim kepatuhan Xpedia Partners dan ditinjau '
              'dalam 2×24 jam kerja. Tidak ada yang perlu dilakukan selain '
              'menunggu.',
        ),
    };

    return XCard(
      child: Column(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: tone.background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: tone.foreground),
          ),
          const SizedBox(height: XSpace.s12),
          XChip(
            label: VerificationStatus.label(verification.status),
            tone: tone,
          ),
          const SizedBox(height: XSpace.s8),
          Text(title, textAlign: TextAlign.center, style: XText.headingM),
          const SizedBox(height: XSpace.s4),
          Text(
            note,
            textAlign: TextAlign.center,
            style: XText.bodyM.copyWith(color: XColors.textSecondary),
          ),
          if (verification.submittedAt != null) ...<Widget>[
            const SizedBox(height: XSpace.s12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(XSpace.s12),
              decoration: BoxDecoration(
                color: XColors.brandSubtle,
                borderRadius: BorderRadius.circular(XRadius.md),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.shield_outlined, color: XColors.primary),
                  const SizedBox(width: XSpace.s8),
                  Expanded(
                    child: Text(
                      'Diajukan ${formatDateTime(verification.submittedAt)}',
                      style: XText.bodyS,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.docType,
    required this.document,
    required this.onAttach,
  });

  final String docType;
  final VerificationDocument? document;
  final VoidCallback? onAttach;

  @override
  Widget build(BuildContext context) {
    final uploaded = document != null;
    return Container(
      padding: const EdgeInsets.all(XSpace.s12),
      decoration: BoxDecoration(
        color: uploaded ? XColors.canvas : XTone.warning.background,
        borderRadius: BorderRadius.circular(XRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: XColors.surface,
              borderRadius: BorderRadius.circular(XRadius.md),
            ),
            child: Icon(
              uploaded ? Icons.task_outlined : Icons.upload_file_outlined,
              color: uploaded ? XColors.success : XColors.warningStrong,
            ),
          ),
          const SizedBox(width: XSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(DocumentType.label(docType), style: XText.titleM),
                Text(
                  uploaded
                      ? 'Diunggah ${formatDate(document!.uploadedAt)}'
                      : 'Belum diunggah · JPG, PNG atau PDF',
                  style: XText.bodyS,
                ),
              ],
            ),
          ),
          if (onAttach != null)
            XButton.secondary(
              label: uploaded ? 'Ganti' : 'Unggah',
              icon: Icons.upload_rounded,
              size: XButtonSize.small,
              onPressed: onAttach,
            )
          else if (uploaded)
            const XChip(label: 'Terunggah', tone: XTone.success),
        ],
      ),
    );
  }
}

/// "Status Akses Fitur Toko" (S-09): what the store can do before approval.
class _AccessCard extends StatelessWidget {
  const _AccessCard({required this.approved});

  final bool approved;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String title, String note, bool open) =>
        Padding(
          padding: const EdgeInsets.only(bottom: XSpace.s8),
          child: Container(
            padding: const EdgeInsets.all(XSpace.s12),
            decoration: BoxDecoration(
              color: XColors.canvas,
              borderRadius: BorderRadius.circular(XRadius.md),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, color: open ? XColors.success : XColors.danger),
                const SizedBox(width: XSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: XText.titleM),
                      Text(note, style: XText.bodyS),
                    ],
                  ),
                ),
                XChip(
                  label: open ? 'Siap' : 'Terkunci',
                  tone: open ? XTone.success : XTone.danger,
                  icon: open ? Icons.check_rounded : Icons.lock_outline_rounded,
                ),
              ],
            ),
          ),
        );
    return XCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Status Akses Fitur Toko', style: XText.titleL),
          const SizedBox(height: XSpace.s12),
          row(Icons.inventory_2_outlined, 'Tayangkan Produk',
              'Produk bisa dibuat sebagai draf sekarang', approved),
          row(Icons.local_shipping_outlined, 'Terima & Kelola Pesanan',
              'Butuh verifikasi disetujui', approved),
          row(Icons.account_balance_wallet_outlined, 'Xpedia Wallet',
              'Atur rekening & PIN sekarang', true),
        ],
      ),
    );
  }
}
