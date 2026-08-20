import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ResponsibleGamingSettings {
  final double? dailyStakeLimit;
  final double? singleBetLimit;
  final DateTime? coolOffUntil;
  final DateTime? selfExcludedUntil;

  const ResponsibleGamingSettings({
    this.dailyStakeLimit,
    this.singleBetLimit,
    this.coolOffUntil,
    this.selfExcludedUntil,
  });

  const ResponsibleGamingSettings.defaults()
      : dailyStakeLimit = null,
        singleBetLimit = null,
        coolOffUntil = null,
        selfExcludedUntil = null;

  bool get isCoolOffActive =>
      coolOffUntil != null && coolOffUntil!.isAfter(DateTime.now().toUtc());

  bool get isSelfExcluded =>
      selfExcludedUntil != null &&
      selfExcludedUntil!.isAfter(DateTime.now().toUtc());

  String? validateStake({required double stake, required double todayStake}) {
    if (isSelfExcluded)
      return 'Self-exclusion is active until ${selfExcludedUntil!.toLocal()}.';
    if (isCoolOffActive)
      return 'Cool-off is active until ${coolOffUntil!.toLocal()}.';
    if (singleBetLimit != null && stake > singleBetLimit!) {
      return 'This stake exceeds your single-bet limit of ${singleBetLimit!.toStringAsFixed(0)} MMK.';
    }
    if (dailyStakeLimit != null && todayStake + stake > dailyStakeLimit!) {
      return 'This stake exceeds your daily limit of ${dailyStakeLimit!.toStringAsFixed(0)} MMK.';
    }
    return null;
  }

  ResponsibleGamingSettings copyWith({
    double? Function()? dailyStakeLimit,
    double? Function()? singleBetLimit,
    DateTime? Function()? coolOffUntil,
    DateTime? Function()? selfExcludedUntil,
  }) {
    return ResponsibleGamingSettings(
      dailyStakeLimit:
          dailyStakeLimit == null ? this.dailyStakeLimit : dailyStakeLimit(),
      singleBetLimit:
          singleBetLimit == null ? this.singleBetLimit : singleBetLimit(),
      coolOffUntil: coolOffUntil == null ? this.coolOffUntil : coolOffUntil(),
      selfExcludedUntil: selfExcludedUntil == null
          ? this.selfExcludedUntil
          : selfExcludedUntil(),
    );
  }

  Map<String, dynamic> toJson() => {
        'daily_stake_limit': dailyStakeLimit,
        'single_bet_limit': singleBetLimit,
        'cool_off_until': coolOffUntil?.toIso8601String(),
        'self_excluded_until': selfExcludedUntil?.toIso8601String(),
      };

  factory ResponsibleGamingSettings.fromJson(Map<String, dynamic> json) {
    return ResponsibleGamingSettings(
      dailyStakeLimit: (json['daily_stake_limit'] as num?)?.toDouble(),
      singleBetLimit: (json['single_bet_limit'] as num?)?.toDouble(),
      coolOffUntil:
          DateTime.tryParse(json['cool_off_until'] as String? ?? '')?.toUtc(),
      selfExcludedUntil:
          DateTime.tryParse(json['self_excluded_until'] as String? ?? '')
              ?.toUtc(),
    );
  }
}

final responsibleGamingProvider = StateNotifierProvider<
    ResponsibleGamingNotifier, AsyncValue<ResponsibleGamingSettings>>((ref) {
  return ResponsibleGamingNotifier();
});

class ResponsibleGamingNotifier
    extends StateNotifier<AsyncValue<ResponsibleGamingSettings>> {
  static const _storageKey = 'cloud9_responsible_gaming_settings';
  static const _storage = FlutterSecureStorage();

  ResponsibleGamingNotifier()
      : super(const AsyncData(ResponsibleGamingSettings.defaults())) {
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return;
      state = AsyncData(
        ResponsibleGamingSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        ),
      );
    } catch (_) {
      state = const AsyncData(ResponsibleGamingSettings.defaults());
    }
  }

  Future<void> _save(ResponsibleGamingSettings settings) async {
    state = AsyncData(settings);
    await _storage.write(
        key: _storageKey, value: jsonEncode(settings.toJson()));
  }

  Future<void> setDailyStakeLimit(double? value) async => _save(
        state.valueOrNull!.copyWith(dailyStakeLimit: () => value),
      );

  Future<void> setSingleBetLimit(double? value) async => _save(
        state.valueOrNull!.copyWith(singleBetLimit: () => value),
      );

  Future<void> startCoolOff(Duration duration) async => _save(
        state.valueOrNull!.copyWith(
          coolOffUntil: () => DateTime.now().toUtc().add(duration),
        ),
      );

  Future<void> startSelfExclusion(Duration duration) async => _save(
        state.valueOrNull!.copyWith(
          selfExcludedUntil: () => DateTime.now().toUtc().add(duration),
        ),
      );

  Future<void> clearLimits() async => _save(
        const ResponsibleGamingSettings.defaults(),
      );
}
