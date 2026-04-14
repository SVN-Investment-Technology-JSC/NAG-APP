class MealSlot {
  final String key; // "sang" | "trua" | "toi"
  final String label;
  final int fromH;
  final int fromM;
  final int toH;
  final int toM;

  const MealSlot({
    required this.key,
    required this.label,
    required this.fromH,
    required this.fromM,
    required this.toH,
    required this.toM,
  });
}

const mealSlots = [
  MealSlot(key: 'sang', label: 'Sáng', fromH: 11, fromM: 30, toH: 13, toM: 0),
  MealSlot(key: 'trua', label: 'Trưa', fromH: 19, fromM: 0, toH: 22, toM: 0),
  MealSlot(key: 'toi', label: 'Tối', fromH: 22, fromM: 0, toH: 23, toM: 59),
];

class DayMeals {
  bool sang;
  bool trua;
  bool toi;

  DayMeals({this.sang = false, this.trua = false, this.toi = false});

  int get total => (sang ? 1 : 0) + (trua ? 1 : 0) + (toi ? 1 : 0);
}

/// Multi-day meal data: name → { dateStr → DayMeals }
typedef MealDataMap = Map<String, Map<String, DayMeals>>;

class Personnel {
  final String tenVT;
  final String hoTen;
  final String boPhan;

  const Personnel({
    required this.tenVT,
    required this.hoTen,
    required this.boPhan,
  });

  factory Personnel.fromJson(Map<String, dynamic> json) {
    return Personnel(
      tenVT: json['tenVT']?.toString() ?? '',
      hoTen: json['hoTen']?.toString() ?? '',
      boPhan: json['boPhan']?.toString() ?? '',
    );
  }
}

class NhomConfig {
  final String key;
  final String ten;
  final List<String> boPhanMatch;

  const NhomConfig({
    required this.key,
    required this.ten,
    required this.boPhanMatch,
  });
}

const nhomConfigs = [
  NhomConfig(key: 'A', ten: 'Quản lý sản xuất', boPhanMatch: ['BLD', 'QLSX']),
  NhomConfig(key: 'B', ten: 'Văn phòng', boPhanMatch: ['VP', 'Văn phòng']),
  NhomConfig(key: 'C', ten: 'Vận hành trạm', boPhanMatch: ['VHT']),
  NhomConfig(key: 'D', ten: 'QA/QC', boPhanMatch: ['QA/QC']),
  NhomConfig(key: 'E', ten: 'Tổ xe bơm', boPhanMatch: ['Tổ bơm']),
  NhomConfig(key: 'F', ten: 'Tổ bơm tĩnh', boPhanMatch: ['Bơm tĩnh']),
  NhomConfig(key: '', ten: 'Tổ xe bồn', boPhanMatch: ['Xe bồn']),
];
