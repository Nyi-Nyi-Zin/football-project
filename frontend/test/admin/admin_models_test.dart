import 'package:betting_app/admin/data/admin_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin models', () {
    test('AdminUserStats parses json', () {
      final stats = AdminUserStats.fromJson({
        'total_users': 100,
        'active_users': 80,
        'suspended_users': 20,
      });

      expect(stats.totalUsers, 100);
      expect(stats.activeUsers, 80);
      expect(stats.suspendedUsers, 20);
    });

    test('AdminTransaction parses json', () {
      final tx = AdminTransaction.fromJson({
        'id': 'tx-1',
        'user_id': 'user-1',
        'type': 'withdraw',
        'amount': 25.5,
        'currency': 'MMK',
        'status': 'pending',
        'description': 'Withdrawal',
        'reference': 'ref-1',
        'created_at': '2026-04-15T10:00:00Z',
      });

      expect(tx.id, 'tx-1');
      expect(tx.userId, 'user-1');
      expect(tx.amount, 25.5);
      expect(tx.status, 'pending');
      expect(tx.createdAt.toUtc().year, 2026);
    });
  });
}
