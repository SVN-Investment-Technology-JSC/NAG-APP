import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';

class PersonnelSelectorSheet extends StatefulWidget {
  final List<WorkPersonnel> unassignedPersonnel;
  final Function(WorkPersonnel) onSelected;

  const PersonnelSelectorSheet({
    super.key,
    required this.unassignedPersonnel,
    required this.onSelected,
  });

  static Future<void> show(BuildContext context, List<WorkPersonnel> personnel, Function(WorkPersonnel) onSelected) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => PersonnelSelectorSheet(
        unassignedPersonnel: personnel, 
        onSelected: (p) {
          Navigator.pop(sheetContext);
          onSelected(p);
        },
      ),
    );
  }

  @override
  State<PersonnelSelectorSheet> createState() => _PersonnelSelectorSheetState();
}

class _PersonnelSelectorSheetState extends State<PersonnelSelectorSheet> {
  String _searchQuery = '';
  Set<String> _selectedSkills = {};

  void _showFilterSheet(List<String> allSkills) {
    Set<String> tempSelected = Set.from(_selectedSkills);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.5,
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Lọc tay nghề', style: Theme.of(context).textTheme.titleLarge),
                      CloseButton(onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: allSkills.map((skill) {
                          final isSelected = tempSelected.contains(skill);
                          return FilterChip(
                            label: Text(skill),
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setStateSheet(() => tempSelected.clear());
                          },
                          child: const Text('Thiết lập lại'),
                        ),
                      ),
                      SizedBox(width: 16.w),
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
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Extract unique skills
    final skills = widget.unassignedPersonnel
        .map((p) => p.skillName ?? 'Chưa xác định')
        .toSet()
        .toList()
      ..sort();

    // Filter personnel
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
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Text('Chọn nhân sự', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  CloseButton(onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm tên nhân sự...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        isDense: true,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Column(
                    children: [
                      IconButton(
                        onPressed: () => _showFilterSheet(skills),
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              Icons.filter_alt_outlined, 
                              color: _selectedSkills.isNotEmpty ? Colors.red : colorScheme.onSurfaceVariant
                            ),
                            if (_selectedSkills.isNotEmpty)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  width: 8.w,
                                  height: 8.w,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_selectedSkills.isNotEmpty)
                        Text('Lọc', style: TextStyle(color: Colors.red, fontSize: 10.sp)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              height: 40.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                children: [
                  Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: FilterChip(
                      label: const Text('Tất cả'),
                      selected: _selectedSkills.isEmpty,
                      onSelected: (val) {
                        if (val) setState(() => _selectedSkills.clear());
                      },
                    ),
                  ),
                  ...skills.map((skill) => Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: FilterChip(
                          label: Text(skill),
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
                      )),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            Divider(height: 1, color: colorScheme.outlineVariant),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text('Không tìm thấy nhân sự phù hợp', style: theme.textTheme.bodyLarge))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(p.userFullName.substring(0, 1).toUpperCase()),
                          ),
                          title: Text(p.userFullName),
                          subtitle: Text(p.skillName ?? p.departmentName ?? '---'),
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
}
