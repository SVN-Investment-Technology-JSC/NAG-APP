class LotTagModel {
  final int id;
  final String key;
  final String name;
  final String rule;
  final int? sortGroup;
  final int? displayOrder;

  LotTagModel({
    required this.id,
    required this.key,
    required this.name,
    required this.rule,
    this.sortGroup,
    this.displayOrder,
  });

  factory LotTagModel.fromJson(Map<String, dynamic> json) {
    return LotTagModel(
      id: json['lot_tag_id'] ?? 0,
      key: json['lot_tag_key'] ?? '',
      name: json['lot_tag_name'] ?? '',
      rule: json['lot_tag_rule'] ?? '',
      sortGroup: json['sort_group'] != null ? int.tryParse(json['sort_group'].toString()) : null,
      displayOrder: json['display_order'] != null ? int.tryParse(json['display_order'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'lot_tag_id': id,
      'lot_tag_key': key,
      'lot_tag_name': name,
      'lot_tag_rule': rule,
      'sort_group': sortGroup,
      'display_order': displayOrder,
    };
  }

  LotTagModel copyWith({
    int? id,
    String? key,
    String? name,
    String? rule,
    int? sortGroup,
    int? displayOrder,
  }) {
    return LotTagModel(
      id: id ?? this.id,
      key: key ?? this.key,
      name: name ?? this.name,
      rule: rule ?? this.rule,
      sortGroup: sortGroup ?? this.sortGroup,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }
}
