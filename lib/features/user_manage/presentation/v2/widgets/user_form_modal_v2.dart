import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/user_manage/data/models/user_manage_model.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/user_manage/presentation/v2/widgets/user_manage_ui_v2.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

/// Add / edit user sheet (v2). Same fields, role list, validation, payload, service calls and
/// error mapping as [UserFormModal] (v1, ../../widgets/user_form_modal.dart) — only the layout changes.
class UserFormModalV2 extends StatefulWidget {
  final UserManageModel? user;
  final VoidCallback onSuccess;

  const UserFormModalV2({
    super.key,
    this.user,
    required this.onSuccess,
  });

  @override
  State<UserFormModalV2> createState() => _UserFormModalV2State();
}

class _UserFormModalV2State extends State<UserFormModalV2> {
  // ── State (verbatim from v1) ──────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _userService = UserManageService();

  late TextEditingController _fullNameController;
  late TextEditingController _shortNameController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _joinDateController;
  late TextEditingController _workShiftController;

  String _selectedRole = 'user';
  bool _isLoading = false;

  List<String> _roles = ['admin', 'manager', 'dispatcher', 'driver', 'user'];
  Map<String, String> _roleNames = {
    'admin': 'Quản trị viên',
    'manager': 'Quản lý',
    'dispatcher': 'Điều phối xe',
    'driver': 'Tài xế',
    'user': 'Người dùng',
  };

  // ── v2 presentation only ──────────────────────────────────────────────────
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user?.userFullName ?? '');
    _shortNameController = TextEditingController(text: widget.user?.userShortName ?? '');
    _usernameController = TextEditingController(text: widget.user?.username ?? '');
    _passwordController = TextEditingController();
    _emailController = TextEditingController(text: widget.user?.userEmail ?? '');
    _phoneController = TextEditingController(text: widget.user?.userPhoneNumber ?? '');
    _addressController = TextEditingController(text: widget.user?.userAddress ?? '');
    final todayStr = DateTime.now().toString().split(' ')[0];
    _joinDateController = TextEditingController(text: widget.user?.userJoinDate ?? todayStr);
    _workShiftController = TextEditingController(text: widget.user?.userWorkShift ?? '');

    if (widget.user != null) {
      _selectedRole = widget.user!.role;
    }
    _initRolesList();
  }

  // ── Logic (verbatim from v1) ──────────────────────────────────────────────

  Future<void> _initRolesList() async {
    if (_selectedRole != 'admin') {
      setState(() {
        _roles.remove('admin');
      });
    }
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    try {
      final rolesData = await _userService.getRoles();
      if (rolesData.isNotEmpty && mounted) {
        setState(() {
          final List<String> fetchedRoles = [];
          final Map<String, String> fetchedNames = {};
          for (final roleObj in rolesData) {
            final String rName = roleObj['role'] ?? '';
            final String rLabel = roleObj['role_label'] ?? rName;
            if (rName.isNotEmpty) {
              if (rName == 'admin' && _selectedRole != 'admin') {
                continue;
              }
              fetchedRoles.add(rName);
              fetchedNames[rName] = rLabel;
            }
          }
          if (fetchedRoles.isNotEmpty) {
            _roles = fetchedRoles;
            _roleNames = fetchedNames;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _shortNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _joinDateController.dispose();
    _workShiftController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorPleaseFillRequiredFields)),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = <String, dynamic>{
        'user_full_name': _fullNameController.text.trim(),
        'user_short_name': _shortNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'user_email': _emailController.text.trim(),
        'user_phone_number': _phoneController.text.trim(),
        'user_address': _addressController.text.trim(),
        'role': _selectedRole,
        'user_join_date': _joinDateController.text.isNotEmpty
            ? _joinDateController.text.trim()
            : DateTime.now().toString().split(' ')[0],
        'user_work_shift': _workShiftController.text.trim(),
      };

      if (_passwordController.text.isNotEmpty) {
        data['password'] = _passwordController.text;
      }

      if (widget.user == null) {
        if (_passwordController.text.isEmpty) {
          throw Exception('Vui lòng nhập mật khẩu cho người dùng mới');
        }
        await _userService.createUser(data);
      } else {
        await _userService.updateUser(widget.user!.userId, data);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.user == null ? 'Thêm người dùng thành công' : 'Cập nhật thành công')),
        );
      }
    } catch (e) {
      debugPrint('[UserFormModal] _submit error: $e');
      if (mounted) {
        String errMsg = 'Đã xảy ra lỗi không xác định. Vui lòng thử lại sau.';
        if (e is DioException) {
          final statusCode = e.response?.statusCode;
          final responseData = e.response?.data;

          String? rawServerMsg;
          if (responseData is Map) {
            rawServerMsg = (responseData['message'] ?? responseData['error'] ?? responseData['errorMessage'])?.toString();
          }

          final String baseMsg = rawServerMsg ?? e.message ?? e.toString();
          final lowerMsg = baseMsg.toLowerCase();

          if (lowerMsg.contains('username') && (lowerMsg.contains('already') || lowerMsg.contains('duplicate') || lowerMsg.contains('exist'))) {
            errMsg = l10n.errorDuplicateUsername;
          } else if (lowerMsg.contains('email') && (lowerMsg.contains('already') || lowerMsg.contains('duplicate') || lowerMsg.contains('exist'))) {
            errMsg = l10n.errorDuplicateEmail;
          } else if (lowerMsg.contains('phone') && (lowerMsg.contains('already') || lowerMsg.contains('duplicate') || lowerMsg.contains('exist'))) {
            errMsg = l10n.errorDuplicatePhone;
          } else if (statusCode == 500) {
            errMsg = l10n.errorServer500;
          } else if (statusCode == 403 || statusCode == 401) {
            errMsg = l10n.errorForbidden403;
          } else if (statusCode == 404) {
            errMsg = l10n.errorNotFound404;
          } else {
            errMsg = baseMsg;
          }
        } else {
          errMsg = e.toString();
        }

        showDialog(
          context: context,
          builder: (context) {
            final t = FxTokens.of(context);
            return AlertDialog(
              icon: FxIconBadge(icon: Icons.error_outline_rounded, tone: FxTokens.red, size: 44),
              title: Text(l10n.errorDialogTitle, textAlign: TextAlign.center),
              content: Text(errMsg, textAlign: TextAlign.center, style: t.body.copyWith(color: t.textMuted)),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.closeButton),
                ),
              ],
            );
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ── Layout (v2) ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.user != null;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 10.h),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 12.h),
            child: Row(
              children: [
                FxIconBadge(
                  icon: isEditing ? Icons.manage_accounts_rounded : Icons.person_add_alt_1_rounded,
                  tone: FxTokens.blue,
                  size: 40,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Cập nhật thông tin' : 'Thêm người dùng mới',
                        style: t.h2.copyWith(fontSize: 17.sp),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        isEditing ? '@${widget.user!.username}' : 'Điền thông tin để tạo tài khoản mới',
                        style: t.small,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.closeButton,
                  icon: Icon(Icons.close_rounded, color: t.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: t.divider),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 6.h),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    UmFormSection(
                      icon: Icons.badge_outlined,
                      title: 'Thông tin cá nhân',
                      tone: FxTokens.blue,
                      children: [
                        _buildTextField(
                          controller: _fullNameController,
                          label: 'Họ và tên *',
                          icon: Icons.person_outline_rounded,
                          validator: (v) => v!.isEmpty ? 'Vui lòng nhập họ tên' : null,
                        ),
                        _buildTextField(
                          controller: _shortNameController,
                          label: l10n.shortNameLabel,
                          icon: Icons.short_text_rounded,
                        ),
                      ],
                    ),
                    UmFormSection(
                      icon: Icons.lock_outline_rounded,
                      title: 'Tài khoản đăng nhập',
                      tone: FxTokens.indigo,
                      children: [
                        _buildTextField(
                          controller: _usernameController,
                          label: 'Tên đăng nhập (Username) *',
                          icon: Icons.alternate_email_rounded,
                          enabled: !isEditing,
                          helper: isEditing ? 'Không thể thay đổi tên đăng nhập' : null,
                          validator: (v) => v!.isEmpty ? 'Vui lòng nhập username' : null,
                        ),
                        _buildTextField(
                          controller: _passwordController,
                          label: isEditing ? 'Mật khẩu mới' : 'Mật khẩu *',
                          icon: Icons.key_rounded,
                          obscureText: !_showPassword,
                          helper: isEditing ? 'Để trống nếu không đổi' : 'Bắt buộc với người dùng mới',
                          suffix: IconButton(
                            tooltip: _showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                            icon: Icon(
                              _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 19.sp,
                              color: t.textMuted,
                            ),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                      ],
                    ),
                    UmFormSection(
                      icon: Icons.contact_mail_outlined,
                      title: 'Liên hệ',
                      tone: FxTokens.emerald,
                      children: [
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Số điện thoại',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        _buildTextField(
                          controller: _addressController,
                          label: 'Địa chỉ',
                          icon: Icons.location_on_outlined,
                        ),
                      ],
                    ),
                    UmFormSection(
                      icon: Icons.shield_outlined,
                      title: 'Vai trò (Role)',
                      tone: FxTokens.violet,
                      children: [_roleSelector(t)],
                    ),
                    UmFormSection(
                      icon: Icons.work_outline_rounded,
                      title: 'Công việc',
                      tone: FxTokens.amber,
                      children: [
                        _buildDatePickerField(
                          controller: _joinDateController,
                          label: 'Ngày vào làm (Tùy chọn)',
                          icon: Icons.calendar_today_outlined,
                        ),
                        _buildTextField(
                          controller: _workShiftController,
                          label: 'Ca làm việc (Tùy chọn)',
                          icon: Icons.schedule_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          _actionBar(t, l10n, isEditing),
        ],
      ),
    );
  }

  Widget _roleSelector(FxTokens t) {
    // The current role is always shown, even if the role list from the server does not contain it.
    final options = [..._roles, if (!_roles.contains(_selectedRole)) _selectedRole];
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (final role in options)
          UmFilterChip(
            label: _roleNames[role] ?? role,
            icon: umRoleIcon(role),
            tone: umRoleTone(role),
            selected: role == _selectedRole,
            onTap: () => setState(() => _selectedRole = role),
          ),
      ],
    );
  }

  Widget _actionBar(FxTokens t, AppLocalizations l10n, bool isEditing) {
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border(top: BorderSide(color: t.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 10.h),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isEditing ? Icons.save_rounded : Icons.person_add_alt_1_rounded, size: 18.sp),
                            SizedBox(width: 8.w),
                            Flexible(
                              child: Text(
                                isEditing ? 'Lưu' : 'Tạo mới',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14.5.sp, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? helper,
    Widget? suffix,
  }) {
    final t = FxTokens.of(context);
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      textInputAction: TextInputAction.next,
      style: t.body.copyWith(fontSize: 14.sp, color: enabled ? t.text : t.textMuted),
      decoration: umInputDecoration(context, label: label, icon: icon, helper: helper, suffix: suffix, enabled: enabled),
    );
  }

  Widget _buildDatePickerField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    final t = FxTokens.of(context);
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: t.body.copyWith(fontSize: 14.sp, fontFeatures: FxTokens.tabular),
      decoration: umInputDecoration(
        context,
        label: label,
        icon: icon,
        suffix: Icon(Icons.expand_more_rounded, size: 20.sp, color: t.textFaint),
      ),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) {
          controller.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        }
      },
    );
  }
}
