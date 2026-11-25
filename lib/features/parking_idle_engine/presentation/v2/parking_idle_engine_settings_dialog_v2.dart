import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/parking_idle_engine/data/models/parking_idle_engine_models.dart';
import 'package:nguyenanh/features/parking_idle_engine/data/services/parking_idle_engine_service.dart';

/// "Cấu hình cảnh báo" dialog (v2). Same load / validate / save as [ParkingIdleEngineSettingsDialog]
/// (min confidence and notification TTL are kept as loaded); only the presentation is new.
class ParkingIdleEngineSettingsDialogV2 extends StatefulWidget {
  final ParkingIdleEngineService apiService;
  final VoidCallback onSaveSuccess;

  const ParkingIdleEngineSettingsDialogV2({
    super.key,
    required this.apiService,
    required this.onSaveSuccess,
  });

  @override
  State<ParkingIdleEngineSettingsDialogV2> createState() => _ParkingIdleEngineSettingsDialogV2State();
}

class _ParkingIdleEngineSettingsDialogV2State extends State<ParkingIdleEngineSettingsDialogV2> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _minutesController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _enabled = true;
  String _minConfidence = 'high';
  double _notificationTtlSeconds = 300;

  // ── Logic (identical to v1) ───────────────────────────────────────────────

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

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);

    return Dialog(
      backgroundColor: t.card,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(t),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 18.h),
                child: _isLoading ? _skeleton() : _form(t),
              ),
            ),
            _actions(t),
          ],
        ),
      ),
    );
  }

  Widget _header(FxTokens t) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 12.w, 14.h),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
      child: Row(
        children: [
          const FxIconBadge(icon: Icons.tune_rounded, tone: FxTokens.indigo, size: 42),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cấu hình cảnh báo', style: t.h1.copyWith(fontSize: 18.sp)),
                SizedBox(height: 2.h),
                Text('Thiết lập ngưỡng cảnh báo xe nổ máy', style: t.small),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Đóng',
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded, size: 20.sp, color: t.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _skeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FxSkeleton(height: 12.h, width: 90.w, radius: 6),
        SizedBox(height: 10.h),
        FxSkeleton(height: 62.h, radius: 14),
        SizedBox(height: 20.h),
        FxSkeleton(height: 12.h, width: 120.w, radius: 6),
        SizedBox(height: 10.h),
        FxSkeleton(height: 50.h, radius: 14),
      ],
    );
  }

  Widget _form(FxTokens t) {
    final tone = _enabled ? FxTokens.emerald : FxTokens.slate;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('TRẠNG THÁI', style: t.overline),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.fromLTRB(12.w, 10.h, 6.w, 10.h),
            decoration: BoxDecoration(
              color: t.cardAlt,
              borderRadius: BorderRadius.circular(FxTokens.rTile),
              border: Border.all(color: t.border),
            ),
            child: Row(
              children: [
                FxIconBadge(
                  icon: _enabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                  tone: tone,
                  size: 34,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bật cảnh báo', style: t.h3),
                      SizedBox(height: 2.h),
                      Text('Bật/tắt toàn bộ cảnh báo nổ máy', style: t.tiny),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _enabled,
                  onChanged: (val) {
                    setState(() {
                      _enabled = val;
                    });
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          Text('NGƯỠNG CẢNH BÁO', style: t.overline),
          SizedBox(height: 8.h),
          Text('Nổ máy bao nhiêu phút thì cảnh báo', style: t.h3),
          SizedBox(height: 8.h),
          TextFormField(
            controller: _minutesController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            style: t.body.copyWith(fontWeight: FontWeight.w700, fontFeatures: FxTokens.tabular),
            decoration: InputDecoration(
              hintText: 'VD: 10',
              prefixIcon: Icon(Icons.timer_outlined, size: 20.sp),
              suffixText: 'phút',
              suffixStyle: t.small.copyWith(fontWeight: FontWeight.w700),
              helperText: 'Tối thiểu 1 phút',
              helperStyle: t.tiny,
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
        ],
      ),
    );
  }

  Widget _actions(FxTokens t) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _isSaving || _isLoading ? null : _saveSettings,
              icon: _isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_isSaving ? 'Đang lưu...' : 'Lưu cấu hình'),
            ),
          ),
        ],
      ),
    );
  }
}
