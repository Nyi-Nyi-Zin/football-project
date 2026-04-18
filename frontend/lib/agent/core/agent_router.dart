import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../presentation/screens/agent_login_screen.dart';
import '../presentation/screens/agent_withdrawals_screen.dart';

final agentRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authNotifierProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: '/withdrawals',
    refreshListenable: refresh,
    redirect: (_, state) {
      final user = ref.read(authNotifierProvider).valueOrNull;
      final isAuthRoute = state.matchedLocation == '/login';
      if (user == null && !isAuthRoute) return '/login';
      if (user != null && user.role != 'agent') return '/login';
      if (user != null && isAuthRoute) return '/withdrawals';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const AgentLoginScreen(),
      ),
      GoRoute(
        path: '/withdrawals',
        builder: (_, __) => const AgentWithdrawalsScreen(),
      ),
    ],
  );
});
