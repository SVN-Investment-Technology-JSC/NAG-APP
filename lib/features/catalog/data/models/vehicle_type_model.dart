class VehicleTypeModel {
  final int id;
  final String name;
  final String? symbol;
  final String? description;

  VehicleTypeModel({
    required this.id,
    required this.name,
    this.symbol,
    this.description,
  });

  factory VehicleTypeModel.fromJson(Map<String, dynamic> json) {
    return VehicleTypeModel(
      id: json['vehicle_type_id'] ?? 0,
      name: json['vehicle_type_name'] ?? '',
      symbol: json['vehicle_type_symbol'],
      description: json['vehicle_type_description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'vehicle_type_id': id,
      'vehicle_type_name': name,
      'vehicle_type_symbol': symbol,
      'vehicle_type_description': description,
    };
  }

  VehicleTypeModel copyWith({
    int? id,
    String? name,
    String? symbol,
    String? description,
  }) {
    return VehicleTypeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      description: description ?? this.description,
    );
  }
}
