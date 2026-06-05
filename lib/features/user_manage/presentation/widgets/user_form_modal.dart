import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/features/user_manage/data/models/user_manage_model.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

class UserFormModal extends StatefulWidget {
  final UserManageModel? user;
  final VoidCallback onSuccess;

  const UserFormModal({
    super.key,
    this.user,
    required this.onSuccess,
  });

  @override
  State<UserFormModal> createState() => _UserFormModalState();
}

class _UserFormModalState extends State<UserFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserManageService();
  
  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _joinDateController;
  late TextEditingController _workShiftController;
  
  String _selectedRole = 'user';
  bool _isLoading = false;

  final List<String> _roles = ['admin', 'manager', 'dispatcher', 'driver', 'user'];
  final Map<String, String> _roleNames = {
    'admin': 'Quản trị viên',
    'manager': 'Quản lý',
    'dispatcher': 'Điều phối xe',
    'driver': 'Tài xế',
    'user': 'Người dùng',
  };

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user?.userFullName ?? '');
    _usernameController = TextEditingController(text: widget.user?.username ?? '');
    _passwordController = TextEditingController();
    _emailController = TextEditingController(text: widget.user?.userEmail ?? '');
    _phoneController = TextEditingController(text: widget.user?.userPhoneNumber ?? '');
    _addressController = TextEditingController(text: widget.user?.userAddress ?? '');
    _joinDateController = TextEditingController(text: widget.user?.userJoinDate ?? '');
    _workShiftController = TextEditingController(text: widget.user?.userWorkShift ?? '');
    
    if (widget.user != null && _roles.contains(widget.user!.role)) {
      _selectedRole = widget.user!.role;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = <String, dynamic>{
        'user_full_name': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'user_email': _emailController.text.trim(),
        'user_phone_number': _phoneController.text.trim(),
        'user_address': _addressController.text.trim(),
        'role': _selectedRole,
        if (_joinDateController.text.isNotEmpty) 'user_join_date': _joinDateController.text.trim(),
        if (_workShiftController.text.isNotEmpty) 'user_work_shift': _workShiftController.text.trim(),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.user != null;

    return Container(
      padding: EdgeInsets.all(24.w),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEditing ? 'Cập nhật thông tin' : 'Thêm người dùng mới',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Flexible(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      controller: _fullNameController,
                      label: 'Họ và tên',
                      icon: Icons.person,
                      validator: (v) => v!.isEmpty ? 'Vui lòng nhập họ tên' : null,
                    ),
                    SizedBox(height: 16.h),
                    _buildTextField(
                      controller: _usernameController,
                      label: 'Tên đăng nhập (Username)',
                      icon: Icons.account_circle,
                      enabled: !isEditing,
                      validator: (v) => v!.isEmpty ? 'Vui lòng nhập username' : null,
                    ),
                    SizedBox(height: 16.h),
                    _buildTextField(
                      controller: _passwordController,
                      label: isEditing ? 'Mật khẩu mới (để trống nếu không đổi)' : 'Mật khẩu',
                      icon: Icons.lock,
                      obscureText: true,
                    ),
                    SizedBox(height: 16.h),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 16.h),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Số điện thoại',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 16.h),
                    _buildTextField(
                      controller: _addressController,
                      label: 'Địa chỉ',
                      icon: Icons.location_on,
                    ),
                    SizedBox(height: 16.h),
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Vai trò (Role)',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      items: _roles.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(_roleNames[role] ?? role),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedRole = v!),
                    ),
                    SizedBox(height: 16.h),
                    _buildDatePickerField(
                      controller: _joinDateController,
                      label: 'Ngày vào làm (Tùy chọn)',
                      icon: Icons.calendar_today,
                    ),
                    SizedBox(height: 16.h),
                    _buildTextField(
                      controller: _workShiftController,
                      label: 'Ca làm việc (Tùy chọn)',
                      icon: Icons.work_outline,
                    ),
                    SizedBox(height: 24.h),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      child: _isLoading 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(isEditing ? 'Lưu' : 'Tạo mới', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
          ),
        ],
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
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        filled: !enabled,
      ),
    );
  }

  Widget _buildDatePickerField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
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
