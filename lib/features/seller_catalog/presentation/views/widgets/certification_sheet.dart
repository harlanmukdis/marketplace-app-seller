import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../../core/domain/model/catalog/product_certification.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../../core/utils/xpedia_tokens.dart';
import '../../../../../core/widgets/xpedia/x_widgets.dart';
import '../../cubits/product_form_cubit/product_form_cubit.dart';

class CertificationDraft {
  const CertificationDraft({
    required this.type,
    required this.number,
    required this.document,
    this.issuedBy,
    this.validUntil,
  });

  final String type;
  final String number;
  final PickedPhoto document;
  final String? issuedBy;

  /// `YYYY-MM-DD`, the `DATE` column's own format.
  final String? validUntil;
}

Future<CertificationDraft?> showCertificationSheet(BuildContext context) =>
    showModalBottomSheet<CertificationDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CertificationSheet(),
    );

/// Every field is checked here because the server checks none of them.
class _CertificationSheet extends StatefulWidget {
  const _CertificationSheet();

  @override
  State<_CertificationSheet> createState() => _CertificationSheetState();
}

class _CertificationSheetState extends State<_CertificationSheet> {
  final TextEditingController _number = TextEditingController();
  final TextEditingController _issuer = TextEditingController();
  String _type = CertificationType.bpom;
  DateTime? _validUntil;
  PickedPhoto? _document;

  @override
  void dispose() {
    _number.dispose();
    _issuer.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    final bytes = file?.bytes;
    if (bytes == null || !mounted) return;
    setState(() => _document = PickedPhoto(bytes: bytes, fileName: file!.name));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  String? get _validUntilText {
    final d = _validUntil;
    if (d == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final ready = _number.text.trim().isNotEmpty && _document != null;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(XSpace.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Unggah Sertifikat', style: XText.headingM),
              const SizedBox(height: XSpace.s4),
              Text(
                'Diverifikasi tim Xpedia sebelum berlaku.',
                style: XText.bodyS,
              ),
              const SizedBox(height: XSpace.s16),
              SegmentedButton<String>(
                segments: <ButtonSegment<String>>[
                  for (final t in CertificationType.all)
                    ButtonSegment<String>(
                      value: t,
                      label: Text(CertificationType.label(t)),
                    ),
                ],
                selected: <String>{_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: XSpace.s12),
              TextField(
                controller: _number,
                onChanged: (_) => setState(() {}),
                decoration:
                    const InputDecoration(labelText: 'Nomor sertifikat *'),
              ),
              const SizedBox(height: XSpace.s12),
              TextField(
                controller: _issuer,
                decoration: const InputDecoration(
                  labelText: 'Diterbitkan oleh (opsional)',
                ),
              ),
              const SizedBox(height: XSpace.s12),
              XListGroup(
                children: <Widget>[
                  XListRow(
                    icon: Icons.event_outlined,
                    title: 'Berlaku sampai',
                    subtitle: _validUntil == null
                        ? 'Opsional'
                        : formatDate(_validUntil),
                    onTap: _pickDate,
                  ),
                  XListRow(
                    icon: Icons.upload_file_outlined,
                    iconColor: XColors.primary,
                    title: 'Dokumen *',
                    subtitle: _document?.fileName ?? 'PDF, JPG atau PNG',
                    onTap: _pickDocument,
                  ),
                ],
              ),
              const SizedBox(height: XSpace.s20),
              XButton(
                label: 'Kirim untuk Verifikasi',
                size: XButtonSize.large,
                expand: true,
                onPressed: ready
                    ? () => Navigator.of(context).pop(CertificationDraft(
                          type: _type,
                          number: _number.text.trim(),
                          document: _document!,
                          issuedBy: _issuer.text.trim().isEmpty
                              ? null
                              : _issuer.text.trim(),
                          validUntil: _validUntilText,
                        ))
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
