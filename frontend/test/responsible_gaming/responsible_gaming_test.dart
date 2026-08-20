import 'package:flutter_test/flutter_test.dart';
import 'package:betting_app/features/responsible_gaming/presentation/providers/responsible_gaming_provider.dart';

void main() {
  test('single-bet limit blocks a stake above the configured amount', () {
    const settings = ResponsibleGamingSettings(singleBetLimit: 1000);
    expect(
      settings.validateStake(stake: 1500, todayStake: 0),
      contains('single-bet limit'),
    );
    expect(settings.validateStake(stake: 500, todayStake: 0), isNull);
  });

  test('daily limit includes the already placed stake for today', () {
    const settings = ResponsibleGamingSettings(dailyStakeLimit: 5000);
    expect(
      settings.validateStake(stake: 1000, todayStake: 4500),
      contains('daily limit'),
    );
  });

  test('responsible-gaming settings round-trip through secure-storage JSON',
      () {
    final original = ResponsibleGamingSettings(
      dailyStakeLimit: 10000,
      singleBetLimit: 2000,
      coolOffUntil: DateTime.utc(2026, 8, 20, 12),
      selfExcludedUntil: DateTime.utc(2026, 9, 20, 12),
    );
    final restored = ResponsibleGamingSettings.fromJson(original.toJson());
    expect(restored.dailyStakeLimit, 10000);
    expect(restored.singleBetLimit, 2000);
    expect(restored.coolOffUntil, original.coolOffUntil);
    expect(restored.selfExcludedUntil, original.selfExcludedUntil);
  });
}
