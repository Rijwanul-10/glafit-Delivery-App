import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/twobee_theme.dart';
import '../common/shared_screens.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await ref.read(authControllerProvider.notifier).init();
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (!state.onboardingSeen) {
      context.go('/onboarding');
    } else if (!state.isLoggedIn) {
      context.go('/login');
    } else {
      context.go('/roles');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwoBeeColors.splashBg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: TwoBeeColors.primarySoft.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('V1.0', style: TextStyle(color: TwoBeeColors.primarySoft, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              const SizedBox(height: 18),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SplashBadge(Icons.inventory_2_outlined),
                  SizedBox(width: 12),
                  _SplashBadge(Icons.two_wheeler_rounded),
                  SizedBox(width: 12),
                  _SplashBadge(Icons.restaurant_rounded),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                '2Bee',
                style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w800, letterSpacing: -1),
              ),
              const SizedBox(height: 6),
              const Text(
                'Everything delivered across Dhaka',
                style: TextStyle(color: TwoBeeColors.primarySoft, fontSize: 15),
              ),
              const SizedBox(height: 36),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(color: TwoBeeColors.primarySoft, strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashBadge extends StatelessWidget {
  final IconData icon;
  const _SplashBadge(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: TwoBeeColors.primarySoft, size: 26),
    );
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _idx = 0;

  static const _slides = [
    (
      title: 'Fast Parcel Delivery',
      subtitle: 'Send documents, gadgets & packages across Dhaka with live courier verification.',
      icon: Icons.local_shipping_outlined,
      pill: 'Normal & Express Parcel',
    ),
    (
      title: 'Zero-Emission EV Rides',
      subtitle: 'Quick Bike, Eco Auto & Comfort rides with verified helmets and live trip sharing.',
      icon: Icons.two_wheeler_rounded,
      pill: '2Bee EV Fleet',
    ),
    (
      title: '2Bee Curated Food & Home Kitchens',
      subtitle: 'Order from top Dhaka restaurants and hygiene-verified Home Kitchens with live tracking.',
      icon: Icons.restaurant_menu_rounded,
      pill: 'Curated Menus · Live Tracking',
    ),
  ];

  Future<void> _finish() async {
    await ref.read(authControllerProvider.notifier).markOnboardingSeen();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('2Bee', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: TwoBeeColors.primary)),
                  TextButton(onPressed: _finish, child: const Text('Skip')),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  onPageChanged: (i) => setState(() => _idx = i),
                  itemCount: _slides.length,
                  itemBuilder: (_, i) {
                    final s = _slides[i];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(36),
                          decoration: const BoxDecoration(color: TwoBeeColors.surfaceTonal, shape: BoxShape.circle),
                          child: Icon(s.icon, size: 78, color: TwoBeeColors.primary),
                        ),
                        const SizedBox(height: 24),
                        Chip(
                          label: Text(s.pill, style: const TextStyle(fontWeight: FontWeight.w600, color: TwoBeeColors.primary)),
                          backgroundColor: TwoBeeColors.primarySoft.withValues(alpha: 0.4),
                          side: BorderSide.none,
                        ),
                        const SizedBox(height: 16),
                        Text(s.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Text(s.subtitle, textAlign: TextAlign.center, style: const TextStyle(color: TwoBeeColors.textSecondary, height: 1.5)),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _idx == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _idx == i ? TwoBeeColors.primary : TwoBeeColors.borderSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_idx < _slides.length - 1) {
                    _pageCtrl.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                  } else {
                    _finish();
                  }
                },
                child: Text(_idx == _slides.length - 1 ? 'Get Started' : 'Next ->'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phone-OTP Only Login Screen (Continue with Google removed per Business Rule!).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController(text: '01711111111');
  bool _loading = false;
  String? _error;

  Future<void> _sendOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).post('/auth/otp/request', body: {
        'phone': _phoneCtrl.text.trim(),
        'purpose': 'LOGIN',
      });
      if (!mounted) return;
      context.push('/otp', extra: {
        'phone': res['phone'],
        'devHint': res['devOtpHint'],
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: TwoBeeColors.primarySoft.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('2Bee Super-App', style: TextStyle(fontWeight: FontWeight.w700, color: TwoBeeColors.primary)),
                  ),
                  IconButton(
                    tooltip: 'Server Host Settings',
                    icon: const Icon(Icons.settings_ethernet_rounded, color: TwoBeeColors.textSecondary),
                    onPressed: () async {
                      final ctrl = TextEditingController(text: AppConfig.serverOrigin);
                      await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Backend Server URL'),
                          content: TextField(
                            controller: ctrl,
                            decoration: const InputDecoration(
                              labelText: 'Server Origin',
                              hintText: 'http://192.168.1.10:4000',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () async {
                                await AppConfig.setServerOrigin(null);
                                if (ctx.mounted) Navigator.pop(ctx);
                                setState(() {});
                              },
                              child: const Text('Reset'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                await AppConfig.setServerOrigin(ctrl.text);
                                if (ctx.mounted) Navigator.pop(ctx);
                                setState(() {});
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Sign in with Phone', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                'One verified Bangladesh mobile number powers Client, Rider & Merchant access.',
                style: TextStyle(color: TwoBeeColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 28),
              const Text('Mobile Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  prefixText: '+880  ',
                  prefixStyle: TextStyle(fontWeight: FontWeight.w700, color: TwoBeeColors.textPrimary),
                  hintText: '17XX XXXXXX',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: TwoBeeColors.errorText, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _sendOtp,
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Send OTP'),
              ),
              const SizedBox(height: 24),
              const Text('Quick Demo Accounts (Free Dev)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TwoBeeColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ('Client (Alex)', '01711111111'),
                  ('Rider (Rafiqul)', '01712345678'),
                  ("Sultan's Dine", '01722222222'),
                  ("Rina's Kitchen", '01733333333'),
                ].map((pair) {
                  return ActionChip(
                    label: Text(pair.$1, style: const TextStyle(fontSize: 12)),
                    backgroundColor: TwoBeeColors.surfaceCard,
                    onPressed: () => setState(() => _phoneCtrl.text = pair.$2),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => context.go('/onboarding'),
                    child: const Text('Replay Onboarding 1–3', style: TextStyle(fontSize: 12)),
                  ),
                  const Text('·', style: TextStyle(color: TwoBeeColors.textSecondary)),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportLegalScreen())),
                    child: const Text('Terms & Privacy', style: TextStyle(fontSize: 12)),
                  ),
                  const Text('·', style: TextStyle(color: TwoBeeColors.textSecondary)),
                  TextButton(
                    onPressed: () => context.push('/screens'),
                    child: const Text('All Screens', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phone;
  final String? devHint;
  const OtpVerificationScreen({super.key, required this.phone, this.devHint});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpCtrl = TextEditingController();
  int _resendSec = 30;
  Timer? _timer;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.devHint != null) _otpCtrl.text = widget.devHint!;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_resendSec > 0 && mounted) setState(() => _resendSec--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).post('/auth/otp/verify', body: {
        'phone': widget.phone,
        'code': _otpCtrl.text.trim(),
        'purpose': 'LOGIN',
      });
      await ref.read(authControllerProvider.notifier).applyOtpLogin(res);
      if (mounted) context.go('/roles');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OTP Verification')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: TwoBeeColors.surfaceTonal, borderRadius: BorderRadius.circular(8)),
              child: const Text('SMS DISPATCH (FREE DEV)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: TwoBeeColors.primary)),
            ),
            const SizedBox(height: 14),
            Text('Enter 6-digit code sent to ${widget.phone}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (widget.devHint != null)
              Text('Dev OTP: ${widget.devHint}', style: const TextStyle(color: TwoBeeColors.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 10),
              decoration: const InputDecoration(hintText: '123456', counterText: ''),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: TwoBeeColors.errorText)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _verify,
              child: Text(_loading ? 'Verifying...' : 'Verify & Continue'),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _resendSec == 0
                    ? () async {
                        await ref.read(apiClientProvider).post('/auth/otp/request', body: {'phone': widget.phone, 'purpose': 'LOGIN'});
                        setState(() => _resendSec = 30);
                      }
                    : null,
                child: Text(_resendSec == 0 ? 'Resend Code' : 'Resend in ${_resendSec}s'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Unified Brand-Green Role Selection (Blue #2563EC bug fixed -> #006C04!)
class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  String _selected = 'CLIENT';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authControllerProvider.notifier).refreshRoles());
  }

  Future<void> _continue() async {
    setState(() => _loading = true);
    try {
      final authCtrl = ref.read(authControllerProvider.notifier);
      await authCtrl.switchRole(_selected);
      final s = ref.read(authControllerProvider);
      final roles = s.roles ?? {};

      if (!mounted) return;
      if (_selected == 'CLIENT') {
        context.go('/client');
        return;
      }

      if (_selected == 'RIDER') {
        final rider = Map<String, dynamic>.from((roles['rider'] as Map?) ?? {});
        if (rider['registered'] != true) {
          context.go('/rider/register');
        } else {
          context.go('/rider/passcode'); // Always 4-digit passcode created at registration
        }
        return;
      }

      if (_selected == 'MERCHANT') {
        final merchant = Map<String, dynamic>.from((roles['merchant'] as Map?) ?? {});
        if (merchant['registered'] != true) {
          context.go('/merchant/type');
        } else if (merchant['kycStatus'] == 'PENDING') {
          // Business Rule 2c: No passcode needed while pending -> enters Home Pending locked!
          context.go('/merchant/pending');
        } else if (merchant['kycStatus'] == 'NEEDS_CHANGES') {
          context.go('/merchant/needs-changes');
        } else if (merchant['needsPostApprovalPinSetup'] == true) {
          // Business Rule 2c: First login after approval MUST create fixed 6-digit passcode!
          context.go('/merchant/post-approval-pin');
        } else {
          context.go('/merchant/passcode'); // Daily 6-digit login
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(authControllerProvider);
    final rider = (s.roles?['rider'] as Map?) ?? {};
    final merchant = (s.roles?['merchant'] as Map?) ?? {};

    String riderBadge = 'Setup KYC + 4-digit PIN';
    if (rider['registered'] == true) {
      riderBadge = rider['kycStatus'] == 'APPROVED' ? 'Approved · 4-digit PIN' : 'Status: ${rider['kycStatus']}';
    }

    String merchantBadge = 'Register Physical / Home Kitchen';
    if (merchant['registered'] == true) {
      if (merchant['needsPostApprovalPinSetup'] == true) {
        merchantBadge = 'Approved! Set 6-digit PIN';
      } else if (merchant['kycStatus'] == 'APPROVED') {
        merchantBadge = '${merchant['businessName']} · 6-digit PIN';
      } else {
        merchantBadge = 'Status: ${merchant['kycStatus']} (No PIN until approved)';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your 2Bee Role'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/screens'),
            icon: const Icon(Icons.account_tree_outlined, size: 18),
            label: const Text('All Flows'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Log out'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('All roles share your verified phone number. No re-OTP needed when switching.',
                style: TextStyle(color: TwoBeeColors.textSecondary)),
            const SizedBox(height: 18),
            _RoleCard(
              title: 'Client',
              subtitle: 'Order Food, Book EV Rides & Send Parcels',
              badge: 'Ready · Zero Passcode',
              icon: Icons.person_rounded,
              selected: _selected == 'CLIENT',
              onTap: () => setState(() => _selected = 'CLIENT'),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              title: 'Rider Partner',
              subtitle: 'Deliver Food, Parcels, Rides & Zone A→B Multi-Service',
              badge: riderBadge,
              icon: Icons.two_wheeler_rounded,
              selected: _selected == 'RIDER',
              onTap: () => setState(() => _selected = 'RIDER'),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              title: 'Restaurant / Home Kitchen',
              subtitle: 'Split Merchant Panel · Menu, Orders & Weekly Payouts',
              badge: merchantBadge,
              icon: Icons.storefront_rounded,
              selected: _selected == 'MERCHANT',
              onTap: () => setState(() => _selected = 'MERCHANT'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _loading ? null : _continue,
              child: Text(_loading ? 'Opening...' : 'Continue as ${_selected[0]}${_selected.substring(1).toLowerCase()}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? TwoBeeColors.surfaceTonal : TwoBeeColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? TwoBeeColors.primary : TwoBeeColors.borderSoft,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: selected ? TwoBeeColors.primary : TwoBeeColors.surfaceTonal,
              child: Icon(icon, color: selected ? Colors.white : TwoBeeColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: TwoBeeColors.primarySoft.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(badge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: TwoBeeColors.primary)),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? TwoBeeColors.primary : TwoBeeColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

