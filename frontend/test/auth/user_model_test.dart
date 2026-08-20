import 'package:flutter_test/flutter_test.dart';
import 'package:betting_app/features/auth/data/models/user_model.dart';

void main() {
  test('UserModel parses verification status from profile JSON', () {
    final model = UserModel.fromJson({
      'id': 'user-1',
      'email': 'customer@example.com',
      'username': 'customer',
      'full_name': 'Customer One',
      'phone': '0912345678',
      'role': 'user',
      'status': 'active',
      'balance': 10000,
      'is_email_verified': true,
      'is_phone_verified': false,
      'kyc_status': 'rejected',
      'pending_withdrawal_count': 1,
      'created_at': '2026-08-20T00:00:00Z',
    });

    final user = model.toEntity();
    expect(user.isEmailVerified, isTrue);
    expect(user.isPhoneVerified, isFalse);
    expect(user.kycStatus, 'rejected');
    expect(user.pendingWithdrawalCount, 1);
  });

  test(
      'UserModel remains backward compatible when verification fields are absent',
      () {
    final model = UserModel.fromJson({
      'id': 'user-2',
      'email': 'legacy@example.com',
      'username': 'legacy',
      'full_name': 'Legacy User',
      'phone': '',
      'role': 'user',
      'status': 'active',
      'balance': 0,
      'created_at': '2026-08-20T00:00:00Z',
    });

    final user = model.toEntity();
    expect(user.isEmailVerified, isFalse);
    expect(user.isPhoneVerified, isFalse);
    expect(user.kycStatus, 'pending');
    expect(user.pendingWithdrawalCount, 0);
  });
}
