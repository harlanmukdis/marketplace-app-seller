import 'package:flutter/material.dart';

import '../../../../../core/data_state.dart';
import '../../../../../core/domain/model/catalog/product_growth.dart';
import '../../../../../core/domain/model/location/master_location.dart';
import '../../../../../core/domain/repositories/location_repository.dart';
import '../../../../../core/utils/xpedia_tokens.dart';
import '../../../../../core/widgets/xpedia/x_widgets.dart';
import '../../../../../di/injector.dart';

class CoverageDraft {
  const CoverageDraft(this.mode, this.locations);

  final String mode;
  final List<CoverageLocation> locations;
}

Future<CoverageDraft?> showCoverageSheet(
  BuildContext context,
  ShippingCoverage current,
) =>
    showModalBottomSheet<CoverageDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CoverageSheet(current: current),
    );

/// "Cakupan Pengiriman" for one product (API v1.17.0).
///
/// Matching on the server is by name — `city` and `province` are free text
/// compared with the buyer's address — so the master list is offered as a
/// convenience, and a typed name is accepted too: the master is a seed of 11
/// provinces and 15 cities, far short of Indonesia.
class _CoverageSheet extends StatefulWidget {
  const _CoverageSheet({required this.current});

  final ShippingCoverage current;

  @override
  State<_CoverageSheet> createState() => _CoverageSheetState();
}

class _CoverageSheetState extends State<_CoverageSheet> {
  late String _mode = widget.current.mode;
  late final List<CoverageLocation> _locations =
      List<CoverageLocation>.of(widget.current.locations);
  final TextEditingController _typed = TextEditingController();
  bool _typedIsProvince = false;

  List<MasterProvince> _provinces = const <MasterProvince>[];
  List<MasterCity> _cities = const <MasterCity>[];

  @override
  void initState() {
    super.initState();
    _loadMaster();
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _loadMaster() async {
    final repo = injector<LocationRepository>();
    final results = await Future.wait<Object>(<Future<Object>>[
      repo.getProvinces(),
      repo.getCities(),
    ]);
    if (!mounted) return;
    setState(() {
      final p = results[0];
      final c = results[1];
      if (p is DataSuccess<List<MasterProvince>>) _provinces = p.value;
      if (c is DataSuccess<List<MasterCity>>) _cities = c.value;
    });
  }

  void _add(CoverageLocation location) {
    if (_locations.contains(location)) return;
    setState(() => _locations.add(location));
  }

  void _addTyped() {
    final name = _typed.text.trim();
    if (name.isEmpty) return;
    _add(_typedIsProvince
        ? CoverageLocation(province: name)
        : CoverageLocation(city: name));
    _typed.clear();
  }

  @override
  Widget build(BuildContext context) {
    final restricted = _mode != CoverageMode.none;
    final valid = !restricted || _locations.isNotEmpty;

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
              Text('Cakupan Pengiriman', style: XText.headingM),
              const SizedBox(height: XSpace.s4),
              Text(
                'Berlaku untuk produk ini saja. Pembeli di luar cakupan tidak '
                'melihat produk ini di pencarian dan tidak bisa checkout.',
                style: XText.bodyS,
              ),
              const SizedBox(height: XSpace.s12),
              RadioGroup<String>(
                groupValue: _mode,
                onChanged: (v) => setState(() => _mode = v ?? _mode),
                child: Column(
                  children: <Widget>[
                    for (final m in <String>[
                      CoverageMode.none,
                      CoverageMode.exclude,
                      CoverageMode.include,
                    ])
                      RadioListTile<String>(
                        value: m,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(CoverageMode.label(m), style: XText.bodyM),
                      ),
                  ],
                ),
              ),
              if (restricted) ...<Widget>[
                const SizedBox(height: XSpace.s8),
                Text(
                  _mode == CoverageMode.exclude
                      ? 'Lokasi yang dikecualikan'
                      : 'Lokasi yang dilayani',
                  style: XText.titleM,
                ),
                const SizedBox(height: XSpace.s8),
                Wrap(
                  spacing: XSpace.s6,
                  runSpacing: XSpace.s6,
                  children: <Widget>[
                    for (final l in _locations)
                      InputChip(
                        label: Text(l.label, style: XText.labelM),
                        onDeleted: () => setState(() => _locations.remove(l)),
                      ),
                    if (_locations.isEmpty)
                      Text('Belum ada lokasi.', style: XText.bodyS),
                  ],
                ),
                const SizedBox(height: XSpace.s12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: PopupMenuButton<CoverageLocation>(
                        onSelected: _add,
                        itemBuilder: (_) => <PopupMenuEntry<CoverageLocation>>[
                          for (final p in _provinces)
                            PopupMenuItem<CoverageLocation>(
                              value: CoverageLocation(province: p.name),
                              child: Text('Prov. ${p.name}'),
                            ),
                        ],
                        child: const _PickerButton(label: 'Provinsi'),
                      ),
                    ),
                    const SizedBox(width: XSpace.s8),
                    Expanded(
                      child: PopupMenuButton<CoverageLocation>(
                        onSelected: _add,
                        itemBuilder: (_) => <PopupMenuEntry<CoverageLocation>>[
                          for (final c in _cities)
                            PopupMenuItem<CoverageLocation>(
                              value: CoverageLocation(city: c.name),
                              child: Text(c.name),
                            ),
                        ],
                        child: const _PickerButton(label: 'Kota'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: XSpace.s12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _typed,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: _typedIsProvince
                              ? 'Ketik nama provinsi'
                              : 'Kota tidak ada di daftar? Ketik',
                        ),
                        onSubmitted: (_) => _addTyped(),
                      ),
                    ),
                    const SizedBox(width: XSpace.s8),
                    ChoiceChip(
                      label: Text(_typedIsProvince ? 'Prov.' : 'Kota'),
                      selected: _typedIsProvince,
                      onSelected: (v) => setState(() => _typedIsProvince = v),
                    ),
                    IconButton(
                      tooltip: 'Tambah',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _addTyped,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: XSpace.s20),
              XButton(
                label: 'Simpan Cakupan',
                size: XButtonSize.large,
                expand: true,
                onPressed: valid
                    ? () => Navigator.of(context)
                        .pop(CoverageDraft(_mode, _locations))
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: XSize.controlMedium,
      padding: const EdgeInsets.symmetric(horizontal: XSpace.s12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(XRadius.md),
        border: Border.all(color: XColors.borderDefault),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.add, size: 18, color: XColors.primary),
          const SizedBox(width: XSpace.s6),
          Expanded(child: Text(label, style: XText.labelL)),
          Icon(Icons.expand_more, size: 18, color: XColors.textTertiary),
        ],
      ),
    );
  }
}
