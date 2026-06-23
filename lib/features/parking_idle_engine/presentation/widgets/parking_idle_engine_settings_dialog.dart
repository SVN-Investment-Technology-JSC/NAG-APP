import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/features/parking_idle_engine/data/models/parking_idle_engine_models.dart';
import 'package:nguyenanh/features/parking_idle_engine/data/services/parking_idle_engine_service.dart';

class ParkingIdleEngineSettingsDialog extends StatefulWidget {
  final ParkingIdleEngineService apiService;
  final VoidCallback onSaveSuccess;

  const ParkingIdleEngineSettingsDialog({
    super.key,
    required this.apiService,
    required this.onSaveSuccess,
  });

  @override
  State<ParkingIdleEngineSettingsDialog> createState() => _ParkingIdleEngineSettingsDialogState();
}

class _ParkingIdleEngineSettingsDialogState extends State<ParkingIdleEngineSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _minutesController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _enabled = true;
  String _minConfidence = 'high';
  double _notificationTtlSeconds = 300;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await widget.apiService.getSettings();
      if (mounted) {
        setState(() {
          _enabled = settings.enabled;
          _minutesController.text = settings.warningAfterMinutes.round().toString();
          _minConfidence = settings.minConfidence;
          _notificationTtlSeconds = settings.notificationTtlSeconds;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải cấu hình cảnh báo')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final mins = double.tryParse(_minutesController.text) ?? 10.0;
      final newSettings = ParkingIdleEngineSettings(
        enabled: _enabled,
        warningAfterMinutes: mins,
        minConfidence: _minConfidence,
        notificationTtlSeconds: _notificationTtlSeconds,
      );

      await widget.apiService.updateSettings(newSettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật cấu hình cảnh báo')),
        );
        widget.onSaveSuccess();
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể lưu cấu hình cảnh báo')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: colorScheme.surface,
        ),
        child: _isLoading
            ? SizedBox(
                height: 150.h,
                child: const Center(child: CircularProgressIndicator.adaptive()),
              )
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(Icons.settings_outlined, color: const Color(0xFF6366F1), size: 20.sp),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cấu hình cảnh báo',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Thiết lập ngưỡng cảnh báo xe nổ máy',
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16.h),

                    // Warning Status Toggle Box
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bật cảnh báo',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'Bật/tắt toàn bộ cảnh báo nổ máy',
                                style: TextStyle(fontSize: 9.sp, color: Colors.grey[400], fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: _enabled,
                            activeThumbColor: const Color(0xFF6366F1),
                            activeTrackColor: const Color(0xFF6366F1).withValues(alpha: 0.5),
                            onChanged: (val) {
                              setState(() {
                                _enabled = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Alert Minutes Input
                    Text(
                      'Nổ máy bao nhiêu phút thì cảnh báo',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _minutesController,
                      keyboardType: TextInputType.number,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        isDense: true,
                        suffixText: 'phút',
                        suffixStyle: TextStyle(fontSize: 12.sp, color: Colors.grey[400], fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập số phút';
                        }
                        final numVal = int.tryParse(value);
                        if (numVal == null || numVal < 1) {
                          return 'Số phút phải lớn hơn hoặc bằng 1';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 24.h),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                          child: Text(
                            'Hủy',
                            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                          ),
                          child: _isSaving
                              ? SizedBox(
                                  width: 16.w,
                                  height: 16.w,
                                  child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Lưu cấu hình', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
