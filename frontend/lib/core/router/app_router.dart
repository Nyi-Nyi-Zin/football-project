import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../i18n/app_localizations.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/betting/presentation/screens/betting_screen.dart';
import '../../features/betting/presentation/screens/bet_detail_screen.dart';
import '../../features/betting/presentation/screens/my_bets_screen.dart';
import '../../features/payment/presentation/screens/wallet_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      if (isAuthenticated && isAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Main app with bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const BettingScreen(),
          ),
          GoRoute(
            path: '/my-bets',
            name: 'myBets',
            builder: (context, state) => const MyBetsScreen(),
          ),
          GoRoute(
            path: '/wallet',
            name: 'wallet',
            builder: (context, state) => const WalletScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),

      // Detail routes
      GoRoute(
        path: '/bet/:id',
        name: 'betDetail',
        builder: (context, state) => BetDetailScreen(
          betId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});

class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _tabs = ['/home', '/my-bets', '/wallet', '/profile'];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.contains(location) ? _tabs.indexOf(location) : 0;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          context.go(_tabs[index]);
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.sports_soccer),
            label: context.l10n.tr('betting'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long),
            label: context.l10n.tr('myBets'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_balance_wallet),
            label: context.l10n.tr('wallet'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: context.l10n.tr('profile'),
          ),
        ],
      ),
    );
  }
}
