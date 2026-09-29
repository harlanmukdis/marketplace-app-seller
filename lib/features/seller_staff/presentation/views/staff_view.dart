import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/model/staff/store_staff.dart';
import '../../../../core/utils/format_helper.dart';
import '../../../../core/utils/xpedia_tokens.dart';
import '../../../../core/widgets/state_widgets.dart';
import '../../../../core/widgets/xpedia/x_widgets.dart';
import '../cubits/staff_cubit.dart';

/// Store staff and roles (blueprint §17 "role/akses untuk tim company").
///
/// An invitee must already have an account; they accept from the
/// notification the invite sends. Seeded roles start with no permissions —
/// the screen says so, because an invited "Customer Service" who can do
/// nothing is the default, not a bug.
class StaffView extends StatelessWidget {
  const StaffView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<StaffCubit>(
      create: (_) => StaffCubit()..load(),
      child: DefaultTabController(
        length: 2,
        child: BlocBuilder<StaffCubit, StaffState>(
          builder: (context, s) => Scaffold(
            backgroundColor: XColors.canvas,
            appBar: XAppBar(
              title: 'Staf & Peran',
              bottom: TabBar(
                labelColor: XColors.primary,
                unselectedLabelColor: XColors.textSecondary,
                indicatorColor: XColors.primary,
                labelStyle: XText.labelL,
                tabs: const <Widget>[
                  Tab(text: 'Staf'),
                  Tab(text: 'Peran & Izin')
                ],
              ),
            ),
            body: s.loading
                ? const LoadingIndicatorView()
                : s.error != null && s.roles.isEmpty
                    ? ErrorStateView(
                        error: s.error!,
                        onRetry: StaffCubit.get(context).load,
                      )
                    : TabBarView(
                        children: <Widget>[
                          _StaffTab(state: s),
                          _RolesTab(state: s),
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}

class _StaffTab extends StatelessWidget {
  const _StaffTab({required this.state});

  final StaffState state;

  Future<void> _invite(BuildContext context) async {
    final cubit = StaffCubit.get(context);
    final roles = state.assignable;
    final email = TextEditingController();
    int? roleId = roles.isEmpty ? null : roles.first.id;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setLocal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(XSpace.screen),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Undang Staf', style: XText.headingM),
                  const SizedBox(height: XSpace.s4),
                  Text(
                    'Email harus sudah terdaftar di Xpedia. Undangan dikirim '
                    'lewat notifikasi dan berlaku 7 hari.',
                    style: XText.bodyS,
                  ),
                  const SizedBox(height: XSpace.s12),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: XSpace.s12),
                  DropdownButtonFormField<int>(
                    initialValue: roleId,
                    decoration: const InputDecoration(labelText: 'Peran'),
                    items: <DropdownMenuItem<int>>[
                      for (final r in roles)
                        DropdownMenuItem<int>(value: r.id, child: Text(r.name)),
                    ],
                    onChanged: (v) => setLocal(() => roleId = v),
                  ),
                  const SizedBox(height: XSpace.s16),
                  XButton(
                    label: 'Kirim Undangan',
                    size: XButtonSize.large,
                    expand: true,
                    onPressed: () => Navigator.of(sheet).pop(true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (ok != true || roleId == null || !context.mounted) return;
    final error = await cubit.invite(email.text, roleId!);
    if (!context.mounted) return;
    error == null
        ? showSuccessSnackBar(context, 'Undangan terkirim.')
        : showErrorSnackBar(context, error);
  }

  Future<void> _manage(BuildContext context, StaffMember m) async {
    final cubit = StaffCubit.get(context);
    final choice = await showModalBottomSheet<Object>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(XSpace.screen),
              child: Text(m.fullName, style: XText.headingM),
            ),
            for (final r in state.assignable)
              ListTile(
                leading: Icon(
                  r.code == m.roleCode
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: XColors.primary,
                ),
                title: Text(r.name, style: XText.bodyM),
                onTap: () => Navigator.of(sheet).pop(r.id),
              ),
            const Divider(height: 1),
            ListTile(
              leading:
                  Icon(Icons.person_remove_outlined, color: XColors.danger),
              title: Text('Keluarkan dari toko',
                  style: XText.bodyM.copyWith(color: XColors.danger)),
              onTap: () => Navigator.of(sheet).pop('remove'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final error = choice == 'remove'
        ? await cubit.remove(m)
        : await cubit.changeRole(m, choice as int);
    if (!context.mounted) return;
    error == null
        ? showSuccessSnackBar(
            context,
            choice == 'remove' ? 'Staf dikeluarkan.' : 'Peran diubah.',
          )
        : showErrorSnackBar(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final staff = state.current;
    return RefreshIndicator(
      onRefresh: StaffCubit.get(context).load,
      child: ListView(
        padding: const EdgeInsets.all(XSpace.screen),
        children: <Widget>[
          const XBanner(
            tone: XTone.info,
            message: 'Pemilik toko selalu punya akses penuh. Staf hanya bisa '
                'melakukan yang diizinkan perannya.',
          ),
          const SizedBox(height: XSpace.cardGap),
          if (staff.isEmpty)
            const XEmptyState(
              icon: Icons.groups_outlined,
              title: 'Belum ada staf',
              message: 'Undang tim Anda untuk membantu mengelola toko.',
            )
          else
            for (final m in staff) ...<Widget>[
              XCard(
                onTap: state.busy ? null : () => _manage(context, m),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      backgroundColor: XColors.brandSubtle,
                      child: Text(
                        m.fullName.isEmpty ? '?' : m.fullName[0].toUpperCase(),
                        style: XText.titleM.copyWith(color: XColors.primary),
                      ),
                    ),
                    const SizedBox(width: XSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(m.fullName, style: XText.titleM),
                          Text(m.email, style: XText.bodyS),
                          Text(
                            m.joinedAt == null
                                ? m.roleName
                                : '${m.roleName} · sejak ${formatDate(m.joinedAt)}',
                            style: XText.caption,
                          ),
                        ],
                      ),
                    ),
                    XChip(
                      label: StaffStatus.label(m.status),
                      tone: m.status == StaffStatus.active
                          ? XTone.success
                          : XTone.warning,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: XSpace.s8),
            ],
          const SizedBox(height: XSpace.s16),
          XButton(
            label: 'Undang Staf',
            icon: Icons.person_add_alt_outlined,
            size: XButtonSize.large,
            expand: true,
            loading: state.busy,
            onPressed: state.assignable.isEmpty ? null : () => _invite(context),
          ),
        ],
      ),
    );
  }
}

class _RolesTab extends StatelessWidget {
  const _RolesTab({required this.state});

  final StaffState state;

  Future<void> _newRole(BuildContext context) async {
    final cubit = StaffCubit.get(context);
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Peran Baru'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama peran'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Buat'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final error = await cubit.createRole(name.text);
    if (!context.mounted) return;
    error == null
        ? showSuccessSnackBar(context, 'Peran dibuat. Atur izinnya.')
        : showErrorSnackBar(context, error);
  }

  Future<void> _edit(BuildContext context, StaffRole role) async {
    final cubit = StaffCubit.get(context);
    final codes = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PermissionSheet(role: role),
    );
    if (codes == null || !context.mounted) return;
    final error = await cubit.setPermissions(role, codes);
    if (!context.mounted) return;
    error == null
        ? showSuccessSnackBar(context, 'Izin ${role.name} disimpan.')
        : showErrorSnackBar(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(XSpace.screen),
      children: <Widget>[
        for (final r in state.roles) ...<Widget>[
          XCard(
            onTap: r.isOwner || state.busy ? null : () => _edit(context, r),
            child: Row(
              children: <Widget>[
                Icon(
                  r.isOwner
                      ? Icons.workspace_premium_outlined
                      : Icons.badge_outlined,
                  color: XColors.primary,
                ),
                const SizedBox(width: XSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(r.name, style: XText.titleM),
                      Text(
                        r.isOwner
                            ? 'Akses penuh, tidak bisa diubah'
                            : r.permissions.isEmpty
                                ? 'Belum ada izin — staf dengan peran ini '
                                    'belum bisa apa-apa'
                                : '${r.permissions.length} izin',
                        style: XText.bodyS.copyWith(
                          color: !r.isOwner && r.permissions.isEmpty
                              ? XColors.warningStrong
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (r.isCustom) const XChip(label: 'Kustom'),
                if (!r.isOwner)
                  Icon(Icons.chevron_right, color: XColors.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: XSpace.s8),
        ],
        const SizedBox(height: XSpace.s12),
        XButton.secondary(
          label: 'Buat Peran Kustom',
          icon: Icons.add_circle_outline,
          expand: true,
          onPressed: state.busy ? null : () => _newRole(context),
        ),
      ],
    );
  }
}

class _PermissionSheet extends StatefulWidget {
  const _PermissionSheet({required this.role});

  final StaffRole role;

  @override
  State<_PermissionSheet> createState() => _PermissionSheetState();
}

class _PermissionSheetState extends State<_PermissionSheet> {
  late final Set<String> _on = widget.role.permissions.toSet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (context, controller) => Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(XSpace.screen),
            child: Row(
              children: <Widget>[
                Expanded(
                  child:
                      Text('Izin ${widget.role.name}', style: XText.headingM),
                ),
                Text('${_on.length} dipilih', style: XText.caption),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              children: <Widget>[
                for (final group
                    in StaffPermissions.groups.entries) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      XSpace.screen,
                      XSpace.s12,
                      XSpace.screen,
                      XSpace.s4,
                    ),
                    child: Text(group.key.toUpperCase(), style: XText.overline),
                  ),
                  for (final (code, label) in group.value)
                    CheckboxListTile(
                      dense: true,
                      value: _on.contains(code),
                      title: Text(label, style: XText.bodyM),
                      subtitle: Text(code, style: XText.caption),
                      onChanged: (v) => setState(
                        () => v == true ? _on.add(code) : _on.remove(code),
                      ),
                    ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(XSpace.screen),
              child: XButton(
                label: 'Simpan Izin',
                size: XButtonSize.large,
                expand: true,
                onPressed: () => Navigator.of(context).pop(_on.toList()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
