import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/v2/wa_widgets_v2.dart';

/// v2 of `PersonnelSelectorSheet`: same constructor, same `show()`, same search / skill-filter rules.
class PersonnelSelectorSheetV2 extends StatefulWidget {
  final List<WorkPersonnel> unassignedPersonnel;
  final Function(WorkPersonnel) onSelected;

  const PersonnelSelectorSheetV2({super.key, required this.unassignedPersonnel, required this.onSelected});

  static Future<void> show(BuildContext context, List<WorkPersonnel> personnel, Function(WorkPersonnel) onSelected) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: FxTokens.of(context).card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (sheetContext) => PersonnelSelectorSheetV2(
        unassignedPersonnel: personnel,
        onSelected: (p) {
          Navigator.pop(sheetContext);
          onSelected(p);
        },
      ),
    );
  }

  @override
  State<PersonnelSelectorSheetV2> createState() => _PersonnelSelectorSheetV2State();
}

class _PersonnelSelectorSheetV2State extends State<PersonnelSelectorSheetV2> {
  String _searchQuery = '';
  Set<String> _selectedSkills = {};

  void _showFilterSheet(List<String> allSkills) {
    Set<String> tempSelected = Set.from(_selectedSkills);
    final t = FxTokens.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const WaSheetHandle(),
                  WaSheetHeader(
                    icon: Icons.tune_rounded,
                    tone: FxTokens.violet,
                    title: 'Lọc tay nghề',
                    subtitle: tempSelected.isEmpty
                        ? 'Chưa chọn tay nghề nào'
                        : 'Đã chọn ${tempSelected.length} tay nghề',
                    onClose: () => Navigator.pop(ctx),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: allSkills.map((skill) {
                          final isSelected = tempSelected.contains(skill);
                          return WaFilterPill(
                            label: skill,
                            selected: isSelected,
                            onSelected: (val) {
                              setStateSheet(() {
                                if (val) {
                                  tempSelected.add(skill);
                                } else {
                                  tempSelected.remove(skill);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h + MediaQuery.of(context).padding.bottom),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setStateSheet(() => tempSelected.clear());
                            },
                            child: const Text('Thiết lập lại'),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _selectedSkills = tempSelected;
                              });
                              Navigator.pop(ctx);
                            },
                            child: const Text('Áp dụng'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);

    // Extract unique skills (same as v1)
    final skills = widget.unassignedPersonnel.map((p) => p.skillName ?? 'Chưa xác định').toSet().toList()..sort();

    // Filter personnel (same as v1)
    final filtered = widget.unassignedPersonnel.where((p) {
      final matchSearch = p.userFullName.toLowerCase().contains(_searchQuery.toLowerCase());
      final skill = p.skillName ?? 'Chưa xác định';
      final matchSkill = _selectedSkills.isEmpty || _selectedSkills.contains(skill);
      return matchSearch && matchSkill;
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WaSheetHandle(),
            WaSheetHeader(
              icon: Icons.person_add_alt_1_rounded,
              tone: FxTokens.blue,
              title: 'Chọn nhân sự',
              subtitle: '${widget.unassignedPersonnel.length} nhân sự chưa được phân công',
              onClose: () => Navigator.pop(context),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  Expanded(
                    child: FxSearchField(
                      hint: 'Tìm kiếm tên nhân sự...',
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  _filterButton(t, skills),
                ],
              ),
            ),
            SizedBox(height: 10.h),
            SizedBox(
              height: 34.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                children: [
                  Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: WaFilterPill(
                      label: 'Tất cả',
                      selected: _selectedSkills.isEmpty,
                      onSelected: (val) {
                        if (val) setState(() => _selectedSkills.clear());
                      },
                    ),
                  ),
                  ...skills.map(
                    (skill) => Padding(
                      padding: EdgeInsets.only(right: 8.w),
                      child: WaFilterPill(
                        label: skill,
                        selected: _selectedSkills.contains(skill),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedSkills.add(skill);
                            } else {
                              _selectedSkills.remove(skill);
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
            Divider(height: 1, color: t.divider),
            Expanded(
              child: filtered.isEmpty
                  ? ListView(
                      controller: scrollController,
                      children: [
                        SizedBox(height: 24.h),
                        const FxEmpty(icon: Icons.person_search_rounded, title: 'Không tìm thấy nhân sự phù hợp'),
                      ],
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(8.w, 6.h, 8.w, 16.h),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        return WaPersonRow(
                          name: p.userFullName,
                          subtitle: p.skillName ?? p.departmentName ?? '---',
                          trailing: Icon(Icons.add_circle_outline_rounded, size: 20.sp, color: t.ink(FxTokens.blue)),
                          onTap: () {
                            widget.onSelected(p);
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _filterButton(FxTokens t, List<String> skills) {
    final active = _selectedSkills.isNotEmpty;
    return Tooltip(
      message: 'Lọc tay nghề',
      child: Material(
        color: active ? t.soft(FxTokens.red) : t.cardAlt,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: active ? FxTokens.red.withValues(alpha: 0.45) : t.border),
        ),
        child: InkWell(
          onTap: () => _showFilterSheet(skills),
          child: SizedBox(
            height: 42.h,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 11.w),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_alt_outlined, size: 18.sp, color: active ? t.ink(FxTokens.red) : t.textMuted),
                  if (active) ...[
                    SizedBox(width: 4.w),
                    Text(
                      'Lọc · ${_selectedSkills.length}',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                        color: t.ink(FxTokens.red),
                        fontFeatures: FxTokens.tabular,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
