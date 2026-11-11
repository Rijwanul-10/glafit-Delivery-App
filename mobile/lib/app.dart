import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/network/api_client.dart';
import 'core/theme/twobee_theme.dart';
import 'features/auth/auth_screens.dart';
import 'features/client/client_shell.dart';
import 'features/merchant/merchant_auth_kyc.dart';
import 'features/merchant/merchant_shell_panels.dart';
import 'features/rider/rider_auth_kyc.dart';
import 'features/rider/rider_shell_multiservice.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, state) {
          final extra = (state.extra as Map?) ?? {};
          return OtpVerificationScreen(
            phone: extra['phone']?.toString() ?? '',
            devHint: extra['devHint']?.toString(),
          );
        },
      ),
      GoRoute(path: '/roles', builder: (_, _) => const RoleSelectionScreen()),

      // Client 4-tab Shell (Home | Activity | Wallet | Profile)
      GoRoute(path: '/client', builder: (_, _) => const ClientShell()),

      // Merchant Auth, KYC (NO reg passcode -> Home Pending -> Post-approval 6-digit PIN) & Split Panel (Home | Orders | Wallet | Store)
      GoRoute(path: '/merchant/type', builder: (_, _) => const RestaurantTypeScreen()),
      GoRoute(
        path: '/merchant/register/:type',
        builder: (_, state) => MerchantRegWizardScreen(merchantType: state.pathParameters['type'] ?? 'PHYSICAL'),
      ),
      GoRoute(path: '/merchant/pending', builder: (_, _) => const MerchantHomePendingScreen()),
      GoRoute(path: '/merchant/needs-changes', builder: (_, _) => const MerchantNeedsChangesScreen()),
      GoRoute(path: '/merchant/post-approval-pin', builder: (_, _) => const MerchantApprovedPinSetupScreen()),
      GoRoute(path: '/merchant/passcode', builder: (_, _) => const RestaurantLoginScreen()),
      GoRoute(path: '/merchant/forgot-passcode', builder: (_, _) => const MerchantForgotPasscodeScreen()),
      GoRoute(path: '/merchant/panel', builder: (_, _) => const MerchantShell()),

      // Rider Auth, KYC (4-digit reg PIN at Step 8) & 4-tab Panel (Home | Jobs | Wallet | Profile)
      GoRoute(path: '/rider/register', builder: (_, _) => const RiderRegWizardScreen()),
      GoRoute(path: '/rider/passcode', builder: (_, _) => const RiderEnterPasscodeScreen()),
      GoRoute(path: '/rider/forgot-passcode', builder: (_, _) => const RiderForgotPasscodeScreen()),
      GoRoute(path: '/rider/panel', builder: (_, _) => const RiderShell()),
    ],
  );
});

class TwoBeeApp extends ConsumerWidget {
  const TwoBeeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return Listener(
      onPointerDown: (_) => ref.read(authControllerProvider.notifier).touch(),
      child: MaterialApp.router(
        title: '2Bee',
        debugShowCheckedModeBanner: false,
        theme: TwoBeeTheme.light(),
        routerConfig: router,
      ),
    );
  }
}

