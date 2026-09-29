import 'package:flutter/material.dart';

import '../../../../../core/domain/model/inventory/warehouse.dart';
import '../../../../../core/domain/model/location/master_location.dart';
import '../../../../../core/utils/constant.dart';
import '../../../../../core/utils/extensions.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/app_dropdown_field.dart';
import '../../../../../core/widgets/custom_text_form_field.dart';
import '../../../../../core/utils/xpedia_tokens.dart';

/// What the sheet collected. Null from [showWarehouseSheet] means cancelled.
class WarehouseDraft {
  const WarehouseDraft({
    required this.name,
    required this.address,
    required this.city,
    required this.province,
    required this.postalCode,
    this.cityId,
    this.status,
  });

  final String name;
  final String address;

  /// Always sent as text, whether it came from the master list or was typed:
  /// the backend kept these columns alongside the new foreign key.
  final String city;
  final String province;

  final String postalCode;

  /// Null when the place was typed rather than chosen — which the column
  /// allows, and which the small master list makes necessary.
  final int? cityId;

  /// Only meaningful when editing; a new warehouse is always created active.
  final String? status;
}

Future<WarehouseDraft?> showWarehouseSheet(
  BuildContext context, {
  Warehouse? existing,
  required Future<List<MasterProvince>> Function() provinces,
  required Future<List<MasterCity>> Function(int provinceId) citiesOf,
}) =>
    showModalBottomSheet<WarehouseDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WarehouseSheet(
        existing: existing,
        provinces: provinces,
        citiesOf: citiesOf,
      ),
    );

/// Creates or edits a warehouse.
///
/// The address is chosen from the province/city master data added in v1.2.0,
/// which is what fills `city_id` and gives the column a shared source of
/// truth. **But the master list is a small seed** — eleven provinces, fifteen
/// cities, and no "Jakarta Timur" — so the form also lets the place be typed,
/// exactly as the backend intends: `city_id` is nullable and the free-text
/// columns were deliberately kept.
///
/// Every field here is a real column. Since v1.2.0 the backend whitelists them
/// rather than passing the body into SQL, so an unknown key no longer answers
/// 500 — it is now dropped silently, which makes a wrong field name harder to
/// notice, not easier.
class _WarehouseSheet extends StatefulWidget {
  const _WarehouseSheet({
    this.existing,
    required this.provinces,
    required this.citiesOf,
  });

  final Warehouse? existing;
  final Future<List<MasterProvince>> Function() provinces;
  final Future<List<MasterCity>> Function(int provinceId) citiesOf;

  @override
  State<_WarehouseSheet> createState() => _WarehouseSheetState();
}

class _WarehouseSheetState extends State<_WarehouseSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _province;
  late final TextEditingController _postalCode;
  late String _status;

  late final Future<List<MasterProvince>> _provincesFuture = widget.provinces();
  Future<List<MasterCity>>? _citiesFuture;

  MasterProvince? _selectedProvince;
  MasterCity? _selectedCity;

  /// Typed rather than chosen. Defaults on for an existing warehouse that has
  /// no `city_id`, so editing one does not silently demand it be re-picked
  /// from a list its city may not be in.
  late bool _isFreeText;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _address = TextEditingController(text: existing?.address ?? '');
    _city = TextEditingController(text: existing?.city ?? '');
    _province = TextEditingController(text: existing?.province ?? '');
    _postalCode = TextEditingController(text: existing?.postalCode ?? '');
    _status = existing?.status ?? WarehouseStatus.active;
    _isFreeText = _isEditing && existing?.cityId == null;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    _province.dispose();
    _postalCode.dispose();
    super.dispose();
  }

  void _chooseProvince(MasterProvince? province) {
    setState(() {
      _selectedProvince = province;
      _selectedCity = null;
      _citiesFuture = province == null ? null : widget.citiesOf(province.id);
    });
  }

  String? _validatePlace() {
    if (_isFreeText) return null;
    if (_selectedProvince == null) return 'Pilih provinsi dulu';
    if (_selectedCity == null) return 'Pilih kota dulu';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final placeError = _validatePlace();
    if (placeError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(placeError)));
      return;
    }

    Navigator.of(context).pop(
      WarehouseDraft(
        name: _name.text.trim(),
        address: _address.text.trim(),
        // The text columns are filled either way — from the chosen row when
        // the master list was used, from the box when it was not.
        city: _isFreeText ? _city.text.trim() : _selectedCity!.name,
        province: _isFreeText ? _province.text.trim() : _selectedProvince!.name,
        postalCode: _postalCode.text.trim(),
        cityId: _isFreeText ? null : _selectedCity!.id,
        status: _isEditing ? _status : null,
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
              Text(
                _isEditing ? 'Ubah gudang' : 'Gudang baru',
                style: XText.headingM,
              ),
              if (!_isEditing) ...<Widget>[
                8.sbh,
                Text(
                  'Gudang pertama otomatis jadi gudang utama — itu keputusan '
                  'server, bukan pilihan di sini.',
                  style: XText.caption.copyWith(color: kLightThirdColor),
                ),
              ],
              16.sbh,
              CustomTextFormField(
                controller: _name,
                labelText: 'Nama gudang',
                validator: Validators.required('Nama gudang'),
              ),
              16.sbh,
              CustomTextFormField(
                controller: _address,
                labelText: 'Alamat',
                maxLines: 2,
                validator: Validators.required('Alamat'),
              ),
              16.sbh,
              if (_isFreeText) _freeTextPlace(context) else _masterPlace(),
              8.sbh,
              _FreeTextToggle(
                isFreeText: _isFreeText,
                onChanged: (value) => setState(() => _isFreeText = value),
              ),
              16.sbh,
              CustomTextFormField(
                controller: _postalCode,
                labelText: 'Kode pos',
                keyboardType: TextInputType.number,
                validator: Validators.required('Kode pos'),
              ),
              if (_isEditing) ...<Widget>[
                16.sbh,
                AppDropdownField<String>(
                  label: 'Status',
                  value: _status,
                  items: WarehouseStatus.all,
                  itemLabel: WarehouseStatus.label,
                  onChanged: (value) => setState(
                    () => _status = value ?? WarehouseStatus.active,
                  ),
                ),
              ],
              24.sbh,
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(_isEditing ? 'Simpan' : 'Tambah gudang'),
              ),
              12.sbh,
            ],
          ),
        ),
      ),
    );
  }

  Widget _freeTextPlace(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: CustomTextFormField(
              controller: _city,
              labelText: 'Kota',
              validator: Validators.required('Kota'),
            ),
          ),
          12.sbw,
          Expanded(
            child: CustomTextFormField(
              controller: _province,
              labelText: 'Provinsi',
              validator: Validators.required('Provinsi'),
            ),
          ),
        ],
      );

  Widget _masterPlace() {
    return FutureBuilder<List<MasterProvince>>(
      future: _provincesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          );
        }

        final provinces = snapshot.data ?? const <MasterProvince>[];
        if (provinces.isEmpty) {
          // The master data is a convenience, not a gate — if it cannot be
          // read, the text columns still accept an address.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Daftar wilayah tidak bisa dimuat. Ketik kota dan provinsi '
                'secara manual.',
                style: XText.bodySPrimary.copyWith(color: kWarningColor),
              ),
              12.sbh,
              _freeTextPlace(context),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppDropdownField<MasterProvince>(
              label: 'Provinsi',
              value: _selectedProvince,
              items: provinces,
              itemLabel: (province) => province.name,
              hint: 'Pilih provinsi',
              onChanged: _chooseProvince,
            ),
            16.sbh,
            if (_citiesFuture == null)
              AppDropdownField<MasterCity>(
                label: 'Kota',
                value: null,
                items: const <MasterCity>[],
                itemLabel: (city) => city.name,
                hint: 'Pilih provinsi dulu',
                onChanged: (_) {},
              )
            else
              FutureBuilder<List<MasterCity>>(
                future: _citiesFuture,
                builder: (context, citySnapshot) {
                  final cities = citySnapshot.data ?? const <MasterCity>[];
                  return AppDropdownField<MasterCity>(
                    label: 'Kota',
                    value: _selectedCity,
                    items: cities,
                    itemLabel: (city) => city.name,
                    hint: citySnapshot.connectionState != ConnectionState.done
                        ? 'Memuat…'
                        : (cities.isEmpty
                            ? 'Provinsi ini belum punya kota terdaftar'
                            : 'Pilih kota'),
                    onChanged: (city) => setState(() => _selectedCity = city),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// The escape hatch. Named plainly, because the master list is incomplete
/// often enough that a seller will need it.
class _FreeTextToggle extends StatelessWidget {
  const _FreeTextToggle({required this.isFreeText, required this.onChanged});

  final bool isFreeText;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!isFreeText),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isFreeText,
                onChanged: (value) => onChanged(value ?? false),
              ),
            ),
            8.sbw,
            Expanded(
              child: Text(
                'Kota saya tidak ada di daftar — ketik manual',
                style: XText.bodySPrimary.copyWith(color: kLightThirdColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
