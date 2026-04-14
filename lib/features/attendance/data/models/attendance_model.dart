class AttendanceRecord {
  final String tenVT;
  final String hoTen;
  final String boPhan;
  final String status; // "1" | "0" | "0.5"

  const AttendanceRecord({
    required this.tenVT,
    required this.hoTen,
    required this.boPhan,
    required this.status,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      tenVT: json['tenVT']?.toString() ?? '',
      hoTen: json['hoTen']?.toString() ?? '',
      boPhan: json['boPhan']?.toString() ?? '',
      status: json['status']?.toString() ?? '0',
    );
  }

  bool get isWorking => status == '1';
  bool get isOff => status == '0';
  bool get isHalf => status == '0.5';
}

class AttendanceGroup {
  final String key;
  final String ten;
  final List<String> nhanSu;

  const AttendanceGroup({
    required this.key,
    required this.ten,
    required this.nhanSu,
  });

  factory AttendanceGroup.fromJson(Map<String, dynamic> json) {
    return AttendanceGroup(
      key: json['key']?.toString() ?? '',
      ten: json['ten']?.toString() ?? '',
      nhanSu: (json['nhanSu'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class AttendanceSummary {
  final int total;
  final int working;
  final int off;
  final double half;

  const AttendanceSummary({
    required this.total,
    required this.working,
    required this.off,
    required this.half,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      total: (json['total'] as num?)?.toInt() ?? 0,
      working: (json['working'] as num?)?.toInt() ?? 0,
      off: (json['off'] as num?)?.toInt() ?? 0,
      half: (json['half'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AttendanceResponse {
  final String sheetDate;
  final List<AttendanceRecord> results;
  final List<AttendanceGroup> nhomNS;
  final AttendanceSummary summary;

  const AttendanceResponse({
    required this.sheetDate,
    required this.results,
    required this.nhomNS,
    required this.summary,
  });

  factory AttendanceResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceResponse(
      sheetDate: json['sheetDate']?.toString() ?? '',
      results: (json['results'] as List<dynamic>?)
              ?.map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      nhomNS: (json['nhomNS'] as List<dynamic>?)
              ?.map((e) => AttendanceGroup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      summary: json['summary'] != null
          ? AttendanceSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : const AttendanceSummary(total: 0, working: 0, off: 0, half: 0),
    );
  }
}
