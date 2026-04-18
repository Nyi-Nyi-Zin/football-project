import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../presentation/screens/admin_balances_screen.dart';
import '../presentation/screens/admin_dashboard_screen.dart';
import '../presentation/screens/admin_login_screen.dart';
import '../presentation/screens/admin_transactions_screen.dart';
import '../presentation/screens/admin_user_detail_screen.dart';
import '../presentation/screens/admin_users_screen.dart';
import '../presentation/screens/admin_withdrawals_screen.dart';
import 'admin_shell.dart';

final adminRouterProvider = Provider<GoRouter>((ref) {
  final routerRefresh = ValueNotifier<int>(0);
  ref.onDispose(routerRefresh.dispose);
  ref.listen(authNotifierProvider, (_, __) {
    routerRefresh.value++;
  });

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: routerRefresh,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final user = authState.valueOrNull;
      final isAuthRoute = state.matchedLocation == '/login';

      if (user == null && !isAuthRoute) {
        return '/login';
      }
      if (user != null && user.role != 'admin') {
        return '/login';
      }
      if (user != null && isAuthRoute) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const AdminLoginScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/users',
            builder: (_, __) => const AdminUsersScreen(),
          ),
          GoRoute(
            path: '/users/:id',
            builder: (_, state) => AdminUserDetailScreen(
              userId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/balances',
            builder: (_, __) => const AdminBalancesScreen(),
          ),
          GoRoute(
            path: '/transactions',
            builder: (_, __) => const AdminTransactionsScreen(),
          ),
          GoRoute(
            path: '/withdrawals',
            builder: (_, __) => const AdminWithdrawalsScreen(),
          ),
        ],
      ),
    ],
  );
});
