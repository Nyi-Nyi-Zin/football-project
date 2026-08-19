import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';

class _AdminMoreDestination {
  final String path;
  final String label;
  final IconData icon;

  const _AdminMoreDestination(this.path, this.label, this.icon);
}

class AdminShell extends ConsumerWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  static const _desktopTabs = <String>[
    '/dashboard',
    '/users',
    '/balances',
    '/transactions',
    '/withdrawals',
    '/odds',
    '/reconciliation',
    '/commission',
  ];

  static const _mobileTabs = <String>[
    '/dashboard',
    '/users',
    '/withdrawals',
    '/balances',
  ];

  static const _moreDestinations = <_AdminMoreDestination>[
    _AdminMoreDestination('/transactions', 'Transactions', Icons.receipt_long),
    _AdminMoreDestination('/odds', 'Odds management', Icons.candlestick_chart),
    _AdminMoreDestination('/reconciliation', 'Reconciliation', Icons.fact_check),
    _AdminMoreDestination('/commission', 'Commission rules', Icons.percent),
  ];

  static const _desktopDestinations = <NavigationRailDestination>[
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

  int _desktopSelectedIndex(String location) {
    final selected = _desktopTabs.indexWhere(
      (tab) => location.startsWith(tab),
    );
    return selected < 0 ? 0 : selected;
  }

  int _mobileSelectedIndex(String location) {
    final selected = _mobileTabs.indexWhere(
      (tab) => location.startsWith(tab),
    );
    return selected < 0 ? _mobileTabs.length : selected;
  }

  void _openMoreMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const ListTile(
                title: Text(
                  'Admin tools',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('More operations and account actions'),
              ),
              const Divider(height: 8),
              ..._moreDestinations.map(
                (destination) => ListTile(
                  minTileHeight: 56,
                  leading: Icon(destination.icon),
                  title: Text(destination.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go(destination.path);
                  },
                ),
              ),
              const Divider(height: 8),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(authNotifierProvider.notifier).logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    final desktopSelectedIndex = _desktopSelectedIndex(location);
    final mobileSelectedIndex = _mobileSelectedIndex(location);

    return Scaffold(
      body: isMobile
          ? child
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: desktopSelectedIndex,
                  onDestinationSelected: (index) =>
                      context.go(_desktopTabs[index]),
                  labelType: NavigationRailLabelType.all,
                  destinations: _desktopDestinations,
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
              height: 68,
              selectedIndex: mobileSelectedIndex,
              onDestinationSelected: (index) {
                if (index == _mobileTabs.length) {
                  _openMoreMenu(context, ref);
                  return;
                }
                context.go(_mobileTabs[index]);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'Users',
                ),
                NavigationDestination(
                  icon: Icon(Icons.payments_outlined),
                  selectedIcon: Icon(Icons.payments),
                  label: 'Payouts',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: 'Finance',
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  selectedIcon: Icon(Icons.more_horiz),
                  label: 'More',
                ),
              ],
            )
          : null,
    );
  }
}
