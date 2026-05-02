class NRCCode {
  final int id;
  final String code;
  final String nameEn;
  final String nameMm;
  final String createdAt;

  NRCCode({
    required this.id,
    required this.code,
    required this.nameEn,
    required this.nameMm,
    required this.createdAt,
  });

  factory NRCCode.fromJson(Map<String, dynamic> json) {
    return NRCCode(
      id: json['id'] as int,
      code: json['code'] as String,
      nameEn: json['name_en'] as String,
      nameMm: json['name_mm'] as String,
      createdAt: json['created_at'] as String,
    );
  }
}

class NRCTownship {
  final int id;
  final int nrcCodeId;
  final String nameEn;
  final String nameMm;
  final String code;
  final String createdAt;

  NRCTownship({
    required this.id,
    required this.nrcCodeId,
    required this.nameEn,
    required this.nameMm,
    required this.code,
    required this.createdAt,
  });

  factory NRCTownship.fromJson(Map<String, dynamic> json) {
    return NRCTownship(
      id: json['id'] as int,
      nrcCodeId: json['nrc_code_id'] as int,
      nameEn: json['name_en'] as String,
      nameMm: json['name_mm'] as String,
      code: json['code'] as String,
      createdAt: json['created_at'] as String,
    );
  }
}
