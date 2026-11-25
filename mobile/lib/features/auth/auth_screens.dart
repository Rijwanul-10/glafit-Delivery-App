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
    } else if (state.needsProfileSetup) {
      context.go('/register-profile');
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: TwoBeeColors.primary.withValues(alpha: 0.15),
                  borderRadius: TwoBeeRadii.pill,
                  border: Border.all(color: TwoBeeColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  '⚡ 100% ELECTRIC FLEET',
                  style: TextStyle(
                    color: TwoBeeColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _SplashBadge(Icons.inventory_2_rounded),
                  SizedBox(width: 14),
                  _SplashBadge(Icons.two_wheeler_rounded),
                  SizedBox(width: 14),
                  _SplashBadge(Icons.restaurant_rounded),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                '2Bee',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Dhaka’s Electric Delivery Super-App',
                style: TextStyle(
                  color: TwoBeeColors.primarySoft,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: TwoBeeColors.primary,
                  strokeWidth: 2.8,
                ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TwoBeeColors.obsidianCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: TwoBeeColors.primary, size: 28),
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
      backgroundColor: TwoBeeColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: TwoBeeColors.primary.withValues(alpha: 0.15),
                      borderRadius: TwoBeeRadii.pill,
                    ),
                    child: const Text(
                      '2BEE SUPER-APP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: TwoBeeColors.primaryAccent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _finish,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: TwoBeeColors.textSecondary,
                      ),
                    ),
                  ),
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
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: TwoBeeColors.surfaceCard,
                            shape: BoxShape.circle,
                            boxShadow: TwoBeeShadows.softCard,
                            border: Border.all(color: TwoBeeColors.borderSoft),
                          ),
                          child: Center(
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: TwoBeeColors.surfaceTonal,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(s.icon, size: 64, color: TwoBeeColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: TwoBeeColors.surfaceTonal,
                            borderRadius: TwoBeeRadii.pill,
                          ),
                          child: Text(
                            s.pill,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: TwoBeeColors.primaryAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            s.subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: TwoBeeColors.textSecondary,
                              height: 1.5,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: _idx == i ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _idx == i ? TwoBeeColors.primary : TwoBeeColors.borderSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (_idx < _slides.length - 1) {
                        _pageCtrl.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      } else {
                        _finish();
                      }
                    },
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: TwoBeeColors.obsidian,
                        shape: BoxShape.circle,
                        boxShadow: TwoBeeShadows.dockNav,
                      ),
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _sendOtp() async {
    final raw = _phoneCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Please enter your Bangladesh phone number');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).post('/auth/otp/request', body: {
        'phone': raw,
        'purpose': 'LOGIN',
      });
      if (!mounted) return;
      context.push('/otp', extra: {
        'phone': res['phone'],
        'devHint': res['devOtpHint'],
        'isNewUser': res['isNewUser'] == true || res['needsProfileSetup'] == true,
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
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
                    child: const Text('2Bee Super-App', style: TextStyle(fontWeight: FontWeight.w700, color: TwoBeeColors.primaryDark)),
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
                'Enter your Bangladesh mobile number. New users set up a quick profile after verifying OTP.',
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
  final bool isNewUser;
  const OtpVerificationScreen({super.key, required this.phone, this.devHint, this.isNewUser = false});

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
    _otpCtrl.dispose();
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
      if (!mounted) return;
      final needsProfile = res['needsProfileSetup'] == true || ref.read(authControllerProvider).needsProfileSetup;
      context.go(needsProfile ? '/register-profile' : '/roles');
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: TwoBeeColors.surfaceTonal, borderRadius: BorderRadius.circular(8)),
                  child: const Text('SMS DISPATCH (FREE DEV)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: TwoBeeColors.primaryDark)),
                ),
                if (widget.isNewUser)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: TwoBeeColors.primary.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
                    child: const Text('NEW USER · PROFILE SETUP NEXT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: TwoBeeColors.primaryDark)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Enter 6-digit code sent to ${widget.phone}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (widget.devHint != null)
              Text('Dev OTP: ${widget.devHint}', style: const TextStyle(color: TwoBeeColors.primaryDark, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 10, color: TwoBeeColors.textPrimary),
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

/// Short initial user profile registration shown right after OTP for new phone numbers.
class CompleteUserProfileScreen extends ConsumerStatefulWidget {
  const CompleteUserProfileScreen({super.key});

  @override
  ConsumerState<CompleteUserProfileScreen> createState() => _CompleteUserProfileScreenState();
}

class _CompleteUserProfileScreenState extends ConsumerState<CompleteUserProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Please enter your full name (at least 2 characters)');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).completeUserProfile(
            fullName: name,
            email: _emailCtrl.text.trim(),
          );
      if (mounted) context.go('/roles');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(authControllerProvider).user?['phone']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: TwoBeeColors.surfaceTonal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'NEW ACCOUNT SETUP',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: TwoBeeColors.primaryDark, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Complete Your Profile', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text(
                'Link your basic profile to your verified phone number. Role-specific details (Rider or Merchant KYC) are completed inside those roles.',
                style: TextStyle(color: TwoBeeColors.textSecondary, height: 1.4, fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (phone.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: TwoBeeColors.surfaceTonal,
                    borderRadius: TwoBeeRadii.inner,
                    border: Border.all(color: TwoBeeColors.primary.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: TwoBeeColors.primaryDark, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('VERIFIED PHONE NUMBER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: TwoBeeColors.primaryDark, letterSpacing: 0.5)),
                            const SizedBox(height: 2),
                            Text(phone, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: TwoBeeColors.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const Text('Full Name *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Tanvir Hasan',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Email Address (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'name@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: TwoBeeColors.errorText, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.primary,
                  foregroundColor: TwoBeeColors.textPrimary,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: TwoBeeColors.textPrimary, strokeWidth: 2))
                    : const Text('Save Profile & Continue ➔', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          await ref.read(authControllerProvider.notifier).logout();
                          if (context.mounted) context.go('/login');
                        },
                  child: const Text('Use a different phone number'),
                ),
              ),
            ],
          ),
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

      if (!mounted) return;
      if (_selected == 'CLIENT') {
        context.go('/client');
        return;
      }

      if (_selected == 'RIDER') {
        context.go('/rider/passcode'); // Always opens Rider Passcode panel first (with Register option inside!)
        return;
      }

      if (_selected == 'MERCHANT') {
        context.go('/merchant/passcode'); // Always opens 6-digit Merchant Passcode panel first (with Register option inside!)
        return;
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
      backgroundColor: TwoBeeColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: TwoBeeColors.scaffoldBg,
        title: const Text(
          'Choose Your 2Bee Role',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'One verified Bangladesh phone number powers all roles. No re-OTP required when switching.',
                style: TextStyle(color: TwoBeeColors.textSecondary, height: 1.4, fontSize: 13),
              ),
              const SizedBox(height: 20),
              _RoleCard(
                title: 'Client',
                subtitle: 'Order Food, Book EV Rides & Send Parcels',
                badge: 'Ready · Zero Passcode',
                icon: Icons.shopping_bag_outlined,
                selected: _selected == 'CLIENT',
                onTap: () => setState(() => _selected = 'CLIENT'),
              ),
              const SizedBox(height: 14),
              _RoleCard(
                title: 'Rider Partner',
                subtitle: 'Deliver Food, Parcels, Rides & Zone A→B Multi-Service',
                badge: riderBadge,
                icon: Icons.two_wheeler_rounded,
                selected: _selected == 'RIDER',
                onTap: () => setState(() => _selected = 'RIDER'),
              ),
              const SizedBox(height: 14),
              _RoleCard(
                title: 'Merchant',
                subtitle: 'Physical Restaurant & Home Kitchen · Menu, Orders & Weekly Payouts',
                badge: merchantBadge,
                icon: Icons.storefront_rounded,
                selected: _selected == 'MERCHANT',
                onTap: () => setState(() => _selected = 'MERCHANT'),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  boxShadow: TwoBeeShadows.emeraldGlow,
                  borderRadius: TwoBeeRadii.pill,
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TwoBeeColors.primary,
                    foregroundColor: TwoBeeColors.textPrimary,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                  ),
                  onPressed: _loading ? null : _continue,
                  child: Text(
                    _loading
                        ? 'Opening...'
                        : 'Continue as ${_selected[0]}${_selected.substring(1).toLowerCase()} ->',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: TwoBeeRadii.card,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: TwoBeeColors.surfaceCard,
            borderRadius: TwoBeeRadii.card,
            boxShadow: selected ? TwoBeeShadows.emeraldGlow : TwoBeeShadows.softCard,
            border: Border.all(
              color: selected ? TwoBeeColors.primary : TwoBeeColors.borderSoft,
              width: selected ? 2.2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: selected
                      ? TwoBeeColors.primary.withValues(alpha: 0.15)
                      : TwoBeeColors.surfaceTonal,
                  borderRadius: TwoBeeRadii.inner,
                ),
                child: Icon(
                  icon,
                  color: selected ? TwoBeeColors.primaryAccent : TwoBeeColors.textSecondary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: TwoBeeColors.surfaceTonal,
                        borderRadius: TwoBeeRadii.pill,
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: TwoBeeColors.primaryAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: selected ? TwoBeeColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? TwoBeeColors.primary : TwoBeeColors.borderSoft,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 16, color: TwoBeeColors.textPrimary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

