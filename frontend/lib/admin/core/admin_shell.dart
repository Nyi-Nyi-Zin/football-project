import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';

class AdminShell extends ConsumerWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  static const _tabs = <String>[
    '/dashboard',
    '/users',
    '/balances',
    '/transactions',
    '/withdrawals',
    '/odds',
    '/support',
    '/reconciliation',
    '/commission',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final selected = _tabs.indexWhere((tab) => location.startsWith(tab));
    final selectedIndex = selected < 0 ? 0 : selected;
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    const destinations = [
      NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: Text('Dashboard'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: Text('Users'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet),
        label: Text('Balances'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long),
        label: Text('Transactions'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.payments_outlined),
        selectedIcon: Icon(Icons.payments),
        label: Text('Withdrawals'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.candlestick_chart_outlined),
        selectedIcon: Icon(Icons.candlestick_chart),
        label: Text('Odds'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.support_agent_outlined),
        selectedIcon: Icon(Icons.support_agent),
        label: Text('Support'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.fact_check_outlined),
        selectedIcon: Icon(Icons.fact_check),
        label: Text('Reconcile'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.percent_outlined),
        selectedIcon: Icon(Icons.percent),
        label: Text('Commission'),
      ),
    ];

    return Scaffold(
      body: isMobile
          ? child
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) => context.go(_tabs[index]),
                  labelType: NavigationRailLabelType.all,
                  destinations: destinations,
                  trailing: IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () =>
                        ref.read(authNotifierProvider.notifier).logout(),
                    tooltip: 'Logout',
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => context.go(_tabs[index]),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'Users',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: 'Balances',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Tx',
                ),
                NavigationDestination(
                  icon: Icon(Icons.payments_outlined),
                  selectedIcon: Icon(Icons.payments),
                  label: 'Wd',
                ),
                NavigationDestination(
                  icon: Icon(Icons.candlestick_chart_outlined),
                  selectedIcon: Icon(Icons.candlestick_chart),
                  label: 'Odds',
                ),
                NavigationDestination(
                  icon: Icon(Icons.support_agent_outlined),
                  selectedIcon: Icon(Icons.support_agent),
                  label: 'Support',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: 'Reconcile',
                ),
                NavigationDestination(
                  icon: Icon(Icons.percent_outlined),
                  selectedIcon: Icon(Icons.percent),
                  label: 'Commission',
                ),
              ],
            )
          : null,
      floatingActionButton: isMobile
          ? FloatingActionButton.small(
              onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
              tooltip: 'Logout',
              child: const Icon(Icons.logout),
            )
          : null,
    );
  }
}
