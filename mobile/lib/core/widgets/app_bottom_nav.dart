import 'package:flutter/material.dart';
import '../theme/twobee_theme.dart';

enum AppUserRole { client, rider, merchant }

class AppNavTabSpec {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const AppNavTabSpec(this.label, this.icon, this.activeIcon);
}

/// Option B Role-Tailored 4-Tab Bottom Navigation Bar shared across all 3 roles:
/// - Client: Home | Activity | Wallet | Profile
/// - Rider: Home | Jobs | Wallet | Profile
/// - Merchant: Home | Orders | Wallet | Store (Menu accessed via Home quick card, Store & Orders header)
class AppBottomNav extends StatelessWidget {
  final AppUserRole role;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int badgeCount;

  const AppBottomNav({
    super.key,
    required this.role,
    required this.currentIndex,
    required this.onTap,
    this.badgeCount = 0,
  });

  static List<AppNavTabSpec> tabsForRole(AppUserRole role) {
    switch (role) {
      case AppUserRole.client:
        return const [
          AppNavTabSpec('Home', Icons.home_outlined, Icons.home_rounded),
          AppNavTabSpec('Activity', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
          AppNavTabSpec('Wallet', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
          AppNavTabSpec('Profile', Icons.person_outline_rounded, Icons.person_rounded),
        ];
      case AppUserRole.rider:
        return const [
          AppNavTabSpec('Home', Icons.two_wheeler_outlined, Icons.two_wheeler_rounded),
          AppNavTabSpec('Jobs', Icons.assignment_outlined, Icons.assignment_rounded),
          AppNavTabSpec('Wallet', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
          AppNavTabSpec('Profile', Icons.person_outline_rounded, Icons.person_rounded),
        ];
      case AppUserRole.merchant:
        return const [
          AppNavTabSpec('Home', Icons.storefront_outlined, Icons.storefront_rounded),
          AppNavTabSpec('Orders', Icons.list_alt_outlined, Icons.list_alt_rounded),
          AppNavTabSpec('Wallet', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
          AppNavTabSpec('Store', Icons.settings_outlined, Icons.settings_rounded),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final specs = tabsForRole(role);
    return Container(
      decoration: const BoxDecoration(
        color: TwoBeeColors.surfaceCard,
        border: Border(top: BorderSide(color: TwoBeeColors.borderSoft)),
      ),
      child: NavigationBar(
        backgroundColor: TwoBeeColors.surfaceCard,
        indicatorColor: TwoBeeColors.surfaceTonalAlt,
        selectedIndex: currentIndex.clamp(0, 3),
        onDestinationSelected: onTap,
        destinations: List.generate(specs.length, (i) {
          final item = specs[i];
          Widget iconWidget = Icon(item.icon, color: TwoBeeColors.textSecondary);
          Widget selectedWidget = Icon(item.activeIcon, color: TwoBeeColors.primary);
          if (i == 1 && badgeCount > 0) {
            iconWidget = Badge.count(count: badgeCount, child: iconWidget);
            selectedWidget = Badge.count(count: badgeCount, child: selectedWidget);
          }
          return NavigationDestination(
            icon: iconWidget,
            selectedIcon: selectedWidget,
            label: item.label,
          );
        }),
      ),
    );
  }
}

