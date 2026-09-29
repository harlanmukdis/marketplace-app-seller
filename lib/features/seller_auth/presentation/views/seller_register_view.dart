import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/route/app_route_seller.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/custom_text_form_field.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../cubits/seller_auth_cubit/seller_auth_cubit.dart';
import 'widgets/auth_layout.dart';

/// Creates the **account**, not the store.
///
/// On this backend every account starts as a buyer and becomes a seller by
/// opening a store, so asking for a shop name here would be asking for
/// something the endpoint cannot accept.
class SellerRegisterView extends StatelessWidget {
  const SellerRegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SellerAuthCubit>(
      create: (_) => SellerAuthCubit(),
      child: const _SellerRegisterBody(),
    );
  }
}

class _SellerRegisterBody extends StatefulWidget {
  const _SellerRegisterBody();

  @override
  State<_SellerRegisterBody> createState() => _SellerRegisterBodyState();
}

class _SellerRegisterBodyState extends State<_SellerRegisterBody> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final error = await SellerAuthCubit.get(context).register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      phone: phone.isEmpty ? null : phone,
    );

    if (!mounted) return;
    if (error != null) {
      showErrorSnackBar(context, error);
      return;
    }

    // Registered, verified and logged in — but with no store yet, so the
    // bootstrap screen is what decides where to land.
    context.go(SellerRoutes.bootstrap);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SellerAuthCubit, SellerAuthState>(
      builder: (context, state) => AuthLayout(
        isRegister: true,
        onSwitch: () => context.canPop()
            ? context.pop()
            : context.go(SellerRoutes.login),
        actionLabel: 'Lanjutkan Registrasi',
        busy: state is SellerAuthInProgress,
        onAction: _submit,
        footer: TextButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(SellerRoutes.login),
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: 'Sudah punya akun? ', style: XText.bodyS),
                TextSpan(
                  text: 'Masuk di sini',
                  style: XText.labelM.copyWith(color: XColors.primary),
                ),
              ],
            ),
          ),
        ),
        form: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const AuthLabel('Nama Lengkap (sesuai KTP)'),
              CustomTextFormField(
                controller: _fullNameController,
                hintText: 'Nama lengkap',
                prefix: const Icon(Icons.person_outline_rounded),
                validator: Validators.required('Nama lengkap'),
              ),
              const SizedBox(height: XSpace.s16),
              const AuthLabel('Alamat Email Bisnis'),
              CustomTextFormField(
                controller: _emailController,
                hintText: 'nama@tokoanda.com',
                keyboardType: TextInputType.emailAddress,
                prefix: const Icon(Icons.mail_outline_rounded),
                validator: Validators.email,
              ),
              const SizedBox(height: XSpace.s16),
              const AuthLabel('Nomor Handphone / WhatsApp', required: false),
              CustomTextFormField(
                controller: _phoneController,
                hintText: '0812 3456 7890',
                keyboardType: TextInputType.phone,
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 12, right: 8),
                  child: Text('+62'),
                ),
                validator: Validators.optional,
              ),
              const SizedBox(height: XSpace.s6),
              Text(
                'Dipakai untuk notifikasi pesanan masuk.',
                style: XText.caption,
              ),
              const SizedBox(height: XSpace.s16),
              const AuthLabel('Kata Sandi'),
              CustomTextFormField(
                controller: _passwordController,
                hintText: 'Minimal 8 karakter',
                obscureText: true,
                textInputAction: TextInputAction.done,
                prefix: const Icon(Icons.lock_outline_rounded),
                onSubmitted: (_) => _submit(),
                validator: Validators.password,
              ),
              const SizedBox(height: XSpace.s12),
              Text(
                'Satu akun bisa punya beberapa toko. Toko pertama dibuat '
                'setelah akun jadi.',
                style: XText.bodyS,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
