import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/domain/model/store/store.dart';
import '../../../../core/function/custom_app_bar.dart';
import '../../../../core/utils/constant.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/custom_text_form_field.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../cubits/store_cubit/store_cubit.dart';
import '../../../../core/utils/xpedia_tokens.dart';

/// Opens a shop under the logged-in account.
class StoreCreateView extends StatefulWidget {
  const StoreCreateView({super.key});

  @override
  State<StoreCreateView> createState() => _StoreCreateViewState();
}

class _StoreCreateViewState extends State<StoreCreateView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _type = StoreType.physical;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final description = _descriptionController.text.trim();
    final (error, _) = await StoreCubit.get(context).create(
      name: _nameController.text.trim(),
      description: description.isEmpty ? null : description,
      type: _type,
    );

    if (!mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }
    context.go(SellerRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: customAppBar(context, 'Buka toko'),
      body: SafeArea(
        child: BlocBuilder<StoreCubit, StoreState>(
          builder: (context, state) {
            final isBusy = state is StoreLoadInProgress;

            return SingleChildScrollView(
              padding: 24.pa,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Toko baru',
                          style: XText.headingM,
                        ),
                        8.sbh,
                        Text(
                          'Toko dibuat dalam keadaan belum aktif. Ajukan '
                          'verifikasi dari halaman toko untuk mulai berjualan.',
                          style: XText.bodySPrimary
                              .copyWith(color: kLightThirdColor),
                        ),
                        24.sbh,
                        CustomTextFormField(
                          controller: _nameController,
                          labelText: 'Nama toko',
                          textInputAction: TextInputAction.next,
                          validator: Validators.required('Nama toko'),
                        ),
                        16.sbh,
                        AppDropdownField<String>(
                          label: 'Jenis toko',
                          value: _type,
                          items: StoreType.all,
                          itemLabel: StoreType.label,
                          onChanged: (value) => setState(
                            () => _type = value ?? StoreType.physical,
                          ),
                        ),
                        16.sbh,
                        CustomTextFormField(
                          controller: _descriptionController,
                          labelText: 'Deskripsi (opsional)',
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          validator: Validators.optional,
                        ),
                        8.sbh,
                        Text(
                          'Alamat toko dipilih server sendiri dari nama — '
                          'server menambahkan akhiran unik, jadi alamat yang '
                          'jadi bisa berbeda dari yang Anda bayangkan.',
                          style:
                              XText.caption.copyWith(color: kLightThirdColor),
                        ),
                        32.sbh,
                        FilledButton(
                          onPressed: isBusy ? null : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          child: isBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: kWhiteColor,
                                  ),
                                )
                              : const Text('Buka toko'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
