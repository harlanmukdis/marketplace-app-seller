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

/// "Masuk" half of S-01.
class SellerLoginView extends StatelessWidget {
  const SellerLoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SellerAuthCubit>(
      create: (_) => SellerAuthCubit(),
      child: const _SellerLoginBody(),
    );
  }
}

class _SellerLoginBody extends StatefulWidget {
  const _SellerLoginBody();

  @override
  State<_SellerLoginBody> createState() => _SellerLoginBodyState();
}

class _SellerLoginBodyState extends State<_SellerLoginBody> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final error = await SellerAuthCubit.get(context).login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
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
    return BlocBuilder<SellerAuthCubit, SellerAuthState>(
      builder: (context, state) => AuthLayout(
        isRegister: false,
        onSwitch: () => context.push(SellerRoutes.register),
        actionLabel: 'Masuk',
        busy: state is SellerAuthInProgress,
        onAction: _submit,
        footer: TextButton(
          onPressed: () => context.push(SellerRoutes.register),
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: 'Belum punya akun toko? ', style: XText.bodyS),
                TextSpan(
                  text: 'Daftar',
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
              const AuthLabel('Alamat Email'),
              CustomTextFormField(
                controller: _emailController,
                hintText: 'nama@tokoanda.com',
                keyboardType: TextInputType.emailAddress,
                prefix: const Icon(Icons.mail_outline_rounded),
                validator: Validators.email,
              ),
              const SizedBox(height: XSpace.s16),
              const AuthLabel('Kata Sandi'),
              CustomTextFormField(
                controller: _passwordController,
                hintText: '••••••••',
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                prefix: const Icon(Icons.lock_outline_rounded),
                onSubmitted: (_) => _submit(),
                suffix: IconButton(
                  tooltip: _obscurePassword ? 'Tampilkan' : 'Sembunyikan',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: Validators.required('Kata sandi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
