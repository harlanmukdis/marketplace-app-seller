import 'package:flutter/material.dart';
import '../../../../../core/widgets/xpedia/x_widgets.dart';

import '../../../../../core/utils/extensions.dart';
import '../../../../../core/utils/format_helper.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/custom_text_form_field.dart';
import '../../../../../core/utils/xpedia_tokens.dart';

class FlashSaleDraft {
  const FlashSaleDraft({
    required this.name,
    required this.startAt,
    required this.endAt,
  });

  final String name;
  final DateTime startAt;
  final DateTime endAt;
}

Future<FlashSaleDraft?> showFlashSaleFormSheet(BuildContext context) =>
    showModalBottomSheet<FlashSaleDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FlashSaleFormSheet(),
    );

/// Creates a flash sale.
///
/// The endpoint validates **nothing** — not even the name — so everything is
/// checked here. The one thing the form cannot fix is scheduling: a sale's
/// status is computed once, at creation, from whether its window already covers
/// `NOW()`. A sale created for later is born `scheduled` and only a
/// five-minute cron worker ever moves it on; where that worker is not running
/// it never becomes `active` and buyers never see it. The sheet says so rather
/// than pretending the choice is free.
class _FlashSaleFormSheet extends StatefulWidget {
  const _FlashSaleFormSheet();

  @override
  State<_FlashSaleFormSheet> createState() => _FlashSaleFormSheetState();
}

class _FlashSaleFormSheetState extends State<_FlashSaleFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();

  late DateTime _start = _roundedNow();
  late DateTime _end = _roundedNow().add(const Duration(days: 1));

  static DateTime _roundedNow() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  /// A start in the future is the case that depends on the status worker.
  bool get _startsLater => _start.isAfter(DateTime.now());

  bool get _windowIsValid => _end.isAfter(_start);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool isStart}) async {
    final initial = isStart ? _start : _end;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _start = picked;
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(days: 1));
        }
      } else {
        _end = picked;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || !_windowIsValid) return;
    Navigator.of(context).pop(
      FlashSaleDraft(
        name: _name.text.trim(),
        startAt: _start,
        endAt: _end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: 20.pa,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Flash sale baru', style: XText.headingM),
              4.sbh,
              Text(
                'Flash sale tidak bisa diubah, dijadwal ulang, atau dibatalkan '
                'setelah dibuat.',
                style: XText.caption.copyWith(color: XColors.textTertiary),
              ),
              16.sbh,
              CustomTextFormField(
                controller: _name,
                labelText: 'Nama flash sale',
                validator: Validators.required('Nama flash sale'),
              ),
              20.sbh,
              Text('Waktu berjalan', style: XText.labelL),
              8.sbh,
              _DateTimeField(
                label: 'Mulai',
                value: _start,
                onTap: () => _pick(isStart: true),
              ),
              12.sbh,
              _DateTimeField(
                label: 'Berakhir',
                value: _end,
                onTap: () => _pick(isStart: false),
              ),
              if (!_windowIsValid) ...<Widget>[
                8.sbh,
                Text(
                  'Waktu berakhir harus setelah waktu mulai.',
                  style: XText.bodySPrimary.copyWith(color: XColors.danger),
                ),
              ],
              if (_startsLater) ...<Widget>[
                12.sbh,
                const _ScheduledWarning(),
              ],
              24.sbh,
              XButton(
                label: 'Buat flash sale',
                size: XButtonSize.large,
                expand: true,
                onPressed: _windowIsValid ? _submit : null,
              ),
              12.sbh,
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the start is in the future — the case that can silently never
/// run.
class _ScheduledWarning extends StatelessWidget {
  const _ScheduledWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: 12.pa,
      decoration: BoxDecoration(
        color: XColors.warningStrong.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.schedule_outlined,
              size: 16, color: XColors.warningStrong),
          8.sbw,
          Expanded(
            child: Text(
              'Waktu mulainya di masa depan, jadi flash sale ini dibuat dengan '
              'status "terjadwal". Yang memindahkannya ke "berjalan" adalah '
              'proses terjadwal di server — kalau proses itu tidak hidup, '
              'harga flash sale tidak akan pernah muncul ke pembeli. '
              'Kalau ingin langsung jalan, setel waktu mulainya ke sekarang.',
              style: XText.bodySPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: Text(
          formatDateTime(value),
          style: XText.bodyM,
        ),
      ),
    );
  }
}
