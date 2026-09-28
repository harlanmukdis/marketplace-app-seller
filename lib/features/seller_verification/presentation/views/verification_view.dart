import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/model/verification/store_verification.dart';
import '../../../../core/function/custom_app_bar.dart';
import '../../../../core/utils/app_styles.dart';
import '../../../../core/utils/constant.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/custom_text_form_field.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../seller_home/presentation/views/widgets/section_card.dart';
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
      appBar: customAppBar(context, 'Verifikasi toko'),
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
                  widget.resubmitting ? 'Ajukan ulang' : 'Ajukan verifikasi',
                  style: AppStyles.styleSemiBold18(context),
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
                  Text('Penanggung jawab (PIC)',
                      style: AppStyles.styleMedium14(context)),
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
                Text('Rekening pencairan',
                    style: AppStyles.styleMedium14(context)),
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
                FilledButton(
                  onPressed: widget.isBusy ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: widget.isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kWhiteColor,
                          ),
                        )
                      : const Text('Kirim pengajuan'),
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

/// Step two and onward: where the request stands, and what is still missing.
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

    return RefreshIndicator(
      onRefresh: () => VerificationCubit.get(context).load(),
      child: ListView(
        padding: 20.pa,
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _StatusCard(verification: verification),
                  12.sbh,
                  SectionCard(
                    title: 'Data pengajuan',
                    child: Column(
                      children: <Widget>[
                        StatRow(
                          label: 'Jenis',
                          value: VerificationType.label(verification.type),
                        ),
                        StatRow(
                          label: 'Nomor KTP',
                          value: verification.idCardNumber ?? '-',
                        ),
                        StatRow(
                          label: 'NPWP',
                          value: verification.taxNumber ?? '-',
                        ),
                        StatRow(
                          label: 'Rekening',
                          value: verification.bankAccountNumber == null
                              ? '-'
                              : '${verification.bankName ?? ''} '
                                  '${verification.bankAccountNumber}'.trim(),
                        ),
                      ],
                    ),
                  ),
                  12.sbh,
                  SectionCard(
                    title: 'Dokumen',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (missing.isEmpty)
                          Text(
                            'Semua dokumen yang diminta sudah terunggah.',
                            style: AppStyles.styleRegular12(context)
                                .copyWith(color: kSuccessColor),
                          )
                        else
                          Text(
                            'Masih kurang: '
                            '${missing.map(DocumentType.label).join(', ')}.',
                            style: AppStyles.styleRegular12(context)
                                .copyWith(color: kWarningColor),
                          ),
                        12.sbh,
                        for (final docType in DocumentType.requiredFor(
                          verification.type,
                        ))
                          _DocumentRow(
                            docType: docType,
                            document: verification.documents
                                .where((doc) => doc.docType == docType)
                                .firstOrNull,
                            onAttach: state.canAttachDocuments && !state.isBusy
                                ? () => _attach(context, docType)
                                : null,
                          ),
                      ],
                    ),
                  ),
                  if (verification.history.isNotEmpty) ...<Widget>[
                    12.sbh,
                    SectionCard(
                      title: 'Riwayat',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (final event in verification.history.reversed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      VerificationStatus.label(event.toStatus),
                                      style:
                                          AppStyles.styleRegular12(context),
                                    ),
                                  ),
                                  Text(
                                    formatDateTime(event.createdAt),
                                    style: AppStyles.styleRegular10(context)
                                        .copyWith(color: kLightThirdColor),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (state.canResubmit) ...<Widget>[
                    24.sbh,
                    _SubmitForm(isBusy: state.isBusy, resubmitting: true),
                  ],
                  32.sbh,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.verification});

  final StoreVerification verification;

  @override
  Widget build(BuildContext context) {
    final (Color color, String note) = switch (verification.status) {
      VerificationStatus.approved => (
          kSuccessColor,
          'Toko sudah aktif dan bisa berjualan.',
        ),
      VerificationStatus.rejected => (
          kErrorColor,
          verification.rejectionReason ??
              'Pengajuan ditolak tanpa alasan tertulis.',
        ),
      _ => (
          kWarningColor,
          'Pengajuan sudah masuk dan menunggu ditinjau admin. '
              'Tidak ada yang perlu dilakukan selain menunggu.',
        ),
    };

    return Container(
      padding: 16.pa,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  VerificationStatus.label(verification.status),
                  style: AppStyles.styleSemiBold16(context)
                      .copyWith(color: color),
                ),
              ),
              if (verification.submittedAt != null)
                Text(
                  formatDate(verification.submittedAt),
                  style: AppStyles.styleRegular10(context)
                      .copyWith(color: kLightThirdColor),
                ),
            ],
          ),
          8.sbh,
          Text(note, style: AppStyles.styleRegular12(context)),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Icon(
            uploaded ? Icons.check_circle_outline : Icons.upload_file_outlined,
            size: 18,
            color: uploaded ? kSuccessColor : kLightThirdColor,
          ),
          12.sbw,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  DocumentType.label(docType),
                  style: AppStyles.styleRegular14(context),
                ),
                if (uploaded && document!.uploadedAt != null)
                  Text(
                    'Diunggah ${formatDate(document!.uploadedAt)}',
                    style: AppStyles.styleRegular10(context)
                        .copyWith(color: kLightThirdColor),
                  ),
              ],
            ),
          ),
          if (onAttach != null)
            TextButton(
              onPressed: onAttach,
              child: Text(uploaded ? 'Ganti' : 'Unggah'),
            ),
        ],
      ),
    );
  }
}
