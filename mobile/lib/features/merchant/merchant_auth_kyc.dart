import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/twobee_theme.dart';
import '../../core/widgets/common_widgets.dart';

class RestaurantTypeScreen extends StatefulWidget {
  const RestaurantTypeScreen({super.key});

  @override
  State<RestaurantTypeScreen> createState() => _RestaurantTypeScreenState();
}

class _RestaurantTypeScreenState extends State<RestaurantTypeScreen> {
  String _type = 'PHYSICAL';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partner Store Type'), actions: const [TwoBeeHomeAction()]),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose how you operate on 2Bee', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('No passcode needed during registration — you will set your 6-digit passcode after KYC approval.',
                style: TextStyle(color: TwoBeeColors.textSecondary)),
            const SizedBox(height: 18),
            RadioGroup<String>(
              groupValue: _type,
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
              child: Column(
                children: [
                  Card(
                    color: _type == 'PHYSICAL' ? TwoBeeColors.surfaceTonal : TwoBeeColors.surfaceCard,
                    child: const RadioListTile<String>(
                      value: 'PHYSICAL',
                      title: Text('Physical Restaurant', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('Commercial dining / kitchen · e-TIN & Trade License required'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: _type == 'HOME_KITCHEN' ? TwoBeeColors.surfaceTonal : TwoBeeColors.surfaceCard,
                    child: const RadioListTile<String>(
                      value: 'HOME_KITCHEN',
                      title: Text('Home Kitchen', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('Cloud / Home chef · Max orders/day, cutoff time & hygiene rules · TIN optional'),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.push('/merchant/register/$_type'),
              child: const Text('Continue Registration ->'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 5-Step + Review Merchant Registration (Physical OR Home Kitchen).
/// Business Rule (2c): NO passcode step during registration!
class MerchantRegWizardScreen extends ConsumerStatefulWidget {
  final String merchantType; // PHYSICAL | HOME_KITCHEN
  const MerchantRegWizardScreen({super.key, required this.merchantType});

  @override
  ConsumerState<MerchantRegWizardScreen> createState() => _MerchantRegWizardScreenState();
}

class _MerchantRegWizardScreenState extends ConsumerState<MerchantRegWizardScreen> {
  int _step = 0; // 0..5 (Step 1..5 + Review)
  final _nameCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _addrCtrl = TextEditingController(text: 'Road 11, Block D, Banani');
  final _phoneCtrl = TextEditingController();
  final _etinCtrl = TextEditingController(text: '482910482910');
  final _tradeCtrl = TextEditingController(text: 'TL-DNCC-9012');
  final _nidCtrl = TextEditingController(text: '1990123456789');
  final _fbCtrl = TextEditingController(text: 'https://facebook.com/my2beekitchen');
  final _payoutNoCtrl = TextEditingController();
  final _payoutHolderCtrl = TextEditingController();
  String _payoutProvider = 'BKASH';
  int _quota = 15;
  int _prepMins = 25;
  String _cutoff = '20:00';
  String _openHours = '11:00 AM – 11:00 PM';
  bool _hygieneOk = true;
  bool _hygienePack = true;
  bool _hygieneFresh = true;
  bool _nidFront = true;
  bool _nidBack = true;
  bool _selfieOk = true;
  bool _tradeDoc = true;
  bool _photosReady = true;
  bool _termsOk = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final phone = ref.read(authControllerProvider).user?['phone'] as String? ?? '+8801700000000';
    _phoneCtrl.text = phone;
    _payoutNoCtrl.text = phone;
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final isPhysical = widget.merchantType == 'PHYSICAL';
      await ref.read(apiClientProvider).post('/merchant/register', body: {
        'merchantType': widget.merchantType,
        'businessName': _nameCtrl.text.trim().isEmpty ? (isPhysical ? 'Spice Hub Dhaka' : 'Home Taste Kitchen') : _nameCtrl.text.trim(),
        'ownerOrCookName': _ownerCtrl.text.trim().isEmpty ? 'Owner Name' : _ownerCtrl.text.trim(),
        'cuisines': ['Bangladeshi', 'Biryani'],
        'address': _addrCtrl.text.trim(),
        'areaZoneId': 'zone-banani',
        'contactPhone': _phoneCtrl.text.trim(),
        if (isPhysical) 'eTin': _etinCtrl.text.trim(),
        if (isPhysical) 'tradeLicenseNo': _tradeCtrl.text.trim(),
        'nidNumber': _nidCtrl.text.trim(),
        'fbPageUrl': _fbCtrl.text.trim(),
        'fbVerifyToken': '2B-4821',
        'dailyOrderLimit': isPhysical ? null : _quota,
        'dailyCutoffTime': isPhysical ? null : _cutoff,
        'hygieneConfirmed': _hygieneOk,
        'payoutProvider': _payoutProvider,
        'payoutAccountNumber': _payoutNoCtrl.text.trim(),
        'payoutHolderName': _payoutHolderCtrl.text.trim().isEmpty ? 'Owner Name' : _payoutHolderCtrl.text.trim(),
        'documents': [
          {'docType': 'NID_FRONT', 'fileUrl': '/uploads/nid-front.jpg'},
          {'docType': 'SELFIE', 'fileUrl': '/uploads/selfie.jpg'},
        ],
        'reRegisterDemo': true,
      });
      await ref.read(authControllerProvider.notifier).refreshRoles();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MerchantVerificationPendingScreen(
              businessName: _nameCtrl.text.trim().isEmpty
                  ? (isPhysical ? 'Spice Hub Dhaka' : 'Home Taste Kitchen')
                  : _nameCtrl.text.trim(),
              merchantType: widget.merchantType,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhysical = widget.merchantType == 'PHYSICAL';
    final titles = [
      isPhysical ? 'Step 1: Business Info' : 'Step 1: Kitchen Info',
      isPhysical ? 'Step 2: Legal Details' : 'Step 2: Identity',
      'Step 3: Facebook Page',
      isPhysical ? 'Step 4: Photos & Hours' : 'Step 4: Food & Hygiene',
      'Step 5: Payout Setup',
      'Review & Submit',
    ];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_step]), actions: const [TwoBeeHomeAction()]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LinearProgressIndicator(value: (_step + 1) / 6, color: TwoBeeColors.primary, backgroundColor: TwoBeeColors.surfaceTonal),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  if (_step == 0) ...[
                    TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: isPhysical ? 'Restaurant Name' : 'Kitchen Brand Name')),
                    const SizedBox(height: 10),
                    TextField(controller: _ownerCtrl, decoration: InputDecoration(labelText: isPhysical ? 'Owner Full Name' : 'Cook Full Name')),
                    const SizedBox(height: 10),
                    TextField(controller: _addrCtrl, decoration: const InputDecoration(labelText: 'Kitchen Address')),
                    const SizedBox(height: 10),
                    TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Contact Phone')),
                  ] else if (_step == 1) ...[
                    TextField(controller: _nidCtrl, decoration: const InputDecoration(labelText: 'Owner NID (10/17 digits)')),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      value: _nidFront,
                      onChanged: (v) => setState(() => _nidFront = v ?? true),
                      title: const Text('NID Front Photo Uploaded'),
                      secondary: const Icon(Icons.badge_outlined, color: TwoBeeColors.primary),
                    ),
                    CheckboxListTile(
                      value: _nidBack,
                      onChanged: (v) => setState(() => _nidBack = v ?? true),
                      title: const Text('NID Back Photo Uploaded'),
                      secondary: const Icon(Icons.badge_outlined, color: TwoBeeColors.primary),
                    ),
                    CheckboxListTile(
                      value: _selfieOk,
                      onChanged: (v) => setState(() => _selfieOk = v ?? true),
                      title: const Text('Live Owner Selfie Captured'),
                      secondary: const Icon(Icons.face_retouching_natural_outlined, color: TwoBeeColors.primary),
                    ),
                    if (isPhysical) ...[
                      const SizedBox(height: 8),
                      TextField(controller: _etinCtrl, decoration: const InputDecoration(labelText: '12-digit e-TIN')),
                      const SizedBox(height: 10),
                      TextField(controller: _tradeCtrl, decoration: const InputDecoration(labelText: 'Trade License Number')),
                      CheckboxListTile(
                        value: _tradeDoc,
                        onChanged: (v) => setState(() => _tradeDoc = v ?? true),
                        title: const Text('Trade License PDF / Photo Attached'),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text('e-TIN & Trade License are optional for Home Kitchens.', style: TextStyle(color: TwoBeeColors.textSecondary)),
                      ),
                  ] else if (_step == 2) ...[
                    TextField(controller: _fbCtrl, decoration: const InputDecoration(labelText: 'Public Facebook Page URL')),
                    const SizedBox(height: 12),
                    const Card(
                      color: TwoBeeColors.surfaceTonal,
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('Verification Code: 2B-4821\nPaste this tag in your Facebook bio/latest post so our verifier confirms ownership.'),
                      ),
                    ),
                  ] else if (_step == 3) ...[
                    CheckboxListTile(
                      value: _photosReady,
                      onChanged: (v) => setState(() => _photosReady = v ?? true),
                      title: Text(isPhysical
                          ? 'Storefront, Kitchen & 3 Dish Photos Uploaded'
                          : 'Clean Home Kitchen & 3 Signature Dish Photos Uploaded'),
                      secondary: const Icon(Icons.photo_library_outlined, color: TwoBeeColors.primary),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Default Avg Prep Time', style: TextStyle(fontWeight: FontWeight.w700)),
                        Row(
                          children: [
                            IconButton(onPressed: () => setState(() => _prepMins = (_prepMins - 5).clamp(10, 90)), icon: const Icon(Icons.remove_circle_outline)),
                            Text('$_prepMins mins', style: const TextStyle(fontWeight: FontWeight.w800)),
                            IconButton(onPressed: () => setState(() => _prepMins = (_prepMins + 5).clamp(10, 90)), icon: const Icon(Icons.add_circle_outline)),
                          ],
                        ),
                      ],
                    ),
                    if (!isPhysical) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Max Orders Per Day', style: TextStyle(fontWeight: FontWeight.w700)),
                          Row(
                            children: [
                              IconButton(onPressed: () => setState(() => _quota = (_quota - 1).clamp(1, 100)), icon: const Icon(Icons.remove_circle_outline)),
                              Text('$_quota', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              IconButton(onPressed: () => setState(() => _quota = (_quota + 1).clamp(1, 100)), icon: const Icon(Icons.add_circle_outline)),
                            ],
                          ),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _cutoff,
                        decoration: const InputDecoration(labelText: 'Daily Order Cutoff Time'),
                        items: const [
                          DropdownMenuItem(value: '18:00', child: Text('6:00 PM')),
                          DropdownMenuItem(value: '20:00', child: Text('8:00 PM')),
                          DropdownMenuItem(value: '22:00', child: Text('10:00 PM')),
                        ],
                        onChanged: (v) => setState(() => _cutoff = v ?? '20:00'),
                      ),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        value: _hygieneOk,
                        onChanged: (v) => setState(() => _hygieneOk = v ?? false),
                        title: const Text('2Bee Hygiene Verified Kitchen Surfaces & Utensils'),
                      ),
                      CheckboxListTile(
                        value: _hygienePack,
                        onChanged: (v) => setState(() => _hygienePack = v ?? false),
                        title: const Text('Tamper-sealed Food-Grade Packaging Used'),
                      ),
                      CheckboxListTile(
                        value: _hygieneFresh,
                        onChanged: (v) => setState(() => _hygieneFresh = v ?? false),
                        title: const Text('Freshly Cooked Per Daily Batch (Zero Reheating)'),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Card(
                        child: ListTile(
                          title: const Text('Operating Hours (Mon – Sun)'),
                          subtitle: Text(_openHours),
                          trailing: TextButton(
                            onPressed: () {
                              setState(() => _openHours = 'Mon–Sun: 11:00 AM – 11:30 PM (Copied to all days)');
                            },
                            child: const Text('Copy Mon to All'),
                          ),
                        ),
                      ),
                    ],
                  ] else if (_step == 4) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _payoutProvider,
                      decoration: const InputDecoration(labelText: 'Payout Method'),
                      items: const [
                        DropdownMenuItem(value: 'BKASH', child: Text('bKash (Preview / BEFTN Schedule)')),
                        DropdownMenuItem(value: 'NAGAD', child: Text('Nagad (Preview)')),
                        DropdownMenuItem(value: 'BANK_BEFTN', child: Text('Bank Account (BEFTN)')),
                      ],
                      onChanged: (v) => setState(() => _payoutProvider = v ?? 'BKASH'),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _payoutNoCtrl, decoration: const InputDecoration(labelText: 'Wallet / Account Number')),
                    const SizedBox(height: 10),
                    TextField(controller: _payoutHolderCtrl, decoration: const InputDecoration(labelText: 'Account Holder Name (Match NID)')),
                  ] else ...[
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            title: Text('${isPhysical ? "Business" : "Kitchen"}: ${_nameCtrl.text.isEmpty ? "Ready" : _nameCtrl.text}'),
                            subtitle: Text(_addrCtrl.text),
                            trailing: TextButton(onPressed: () => setState(() => _step = 0), child: const Text('Edit')),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            title: Text('NID: ${_nidCtrl.text}'),
                            subtitle: Text(isPhysical ? 'e-TIN ${_etinCtrl.text} · License ${_tradeCtrl.text}' : 'Home Kitchen Identity Verified'),
                            trailing: TextButton(onPressed: () => setState(() => _step = 1), child: const Text('Edit')),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            title: Text(isPhysical ? 'Hours & Prep ($_prepMins mins)' : 'Batch Quota $_quota/day · Cutoff $_cutoff'),
                            trailing: TextButton(onPressed: () => setState(() => _step = 3), child: const Text('Edit')),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            title: Text('Payout: $_payoutProvider · ${_payoutNoCtrl.text}'),
                            trailing: TextButton(onPressed: () => setState(() => _step = 4), child: const Text('Edit')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const VerificationBanner(
                      title: 'Passcode Created ONLY After Approval',
                      subtitle: 'No passcode needed right now. Once admin approves your KYC, you will verify via OTP and set your 6-digit PIN.',
                    ),
                    CheckboxListTile(
                      value: _termsOk,
                      onChanged: (v) => setState(() => _termsOk = v ?? false),
                      title: const Text('Confirm details & submit to 2Bee verification'),
                    ),
                    if (_error != null) Text(_error!, style: const TextStyle(color: TwoBeeColors.errorText)),
                  ],
                ],
              ),
            ),
            Row(
              children: [
                if (_step > 0) ...[
                  Expanded(child: OutlinedButton(onPressed: () => setState(() => _step--), child: const Text('Back'))),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () {
                            if (_step < 5) {
                              setState(() => _step++);
                            } else if (_termsOk) {
                              _submit();
                            }
                          },
                    child: Text(_step < 5 ? 'Next ->' : (_loading ? 'Submitting...' : 'Submit & Enter Panel')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MerchantNeedsChangesScreen extends ConsumerStatefulWidget {
  const MerchantNeedsChangesScreen({super.key});

  @override
  ConsumerState<MerchantNeedsChangesScreen> createState() => _MerchantNeedsChangesScreenState();
}

class _MerchantNeedsChangesScreenState extends ConsumerState<MerchantNeedsChangesScreen> {
  final _fbCtrl = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification Update Required'), actions: const [TwoBeeHomeAction()]),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const VerificationBanner(
              title: 'Admin requested KYC updates',
              subtitle: 'Please verify your Facebook page token 2B-4821 and resubmit.',
              isErrorStyle: true,
            ),
            const SizedBox(height: 16),
            TextField(controller: _fbCtrl, decoration: const InputDecoration(labelText: 'Updated Facebook Page URL')),
            const Spacer(),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      await ref.read(apiClientProvider).post('/merchant/resubmit', body: {
                        'fbPageUrl': _fbCtrl.text.trim(),
                      });
                      await ref.read(authControllerProvider.notifier).refreshRoles();
                      if (context.mounted) context.go('/merchant/pending');
                    },
              child: const Text('Resubmit Application ->'),
            ),
          ],
        ),
      ),
    );
  }
}

/// First Login After Admin Approval -> Mandatory 6-Digit Passcode Setup Gate (Decision 2b/2c)!
class MerchantApprovedPinSetupScreen extends ConsumerStatefulWidget {
  const MerchantApprovedPinSetupScreen({super.key});

  @override
  ConsumerState<MerchantApprovedPinSetupScreen> createState() => _MerchantApprovedPinSetupScreenState();
}

class _MerchantApprovedPinSetupScreenState extends ConsumerState<MerchantApprovedPinSetupScreen> {
  final _otpCtrl = TextEditingController();
  String _pin = '';
  bool _biometric = true;
  bool _otpSent = false;
  bool _loading = false;
  String? _error;

  Future<void> _requestOtp() async {
    final phone = ref.read(authControllerProvider).user?['phone'] as String?;
    if (phone == null) return;
    final res = await ref.read(apiClientProvider).post('/auth/otp/request', body: {
      'phone': phone,
      'purpose': 'MERCHANT_APPROVAL_PIN',
    });
    setState(() {
      _otpSent = true;
      if (res['devOtpHint'] != null) _otpCtrl.text = res['devOtpHint'] as String;
    });
  }

  Future<void> _submitPin() async {
    if (_pin.length != 6) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).post('/merchant/post-approval/setup-pin', body: {
        'otpCode': _otpCtrl.text.trim(),
        'passcode': _pin,
        'enableBiometric': _biometric,
      });
      ref.read(authControllerProvider.notifier).setMerchantToken(res['roleToken'] as String);
      await ref.read(authControllerProvider.notifier).refreshRoles();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MerchantFingerprintSetupScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _pin = '';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store Approved · Set 6-Digit Passcode'), actions: const [TwoBeeHomeAction()]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const VerificationBanner(
              title: 'Congratulations! Store Approved',
              subtitle: 'Set your permanent 6-digit passcode via phone OTP to unlock your Merchant Home panel.',
            ),
            const SizedBox(height: 16),
            if (!_otpSent)
              ElevatedButton(onPressed: _requestOtp, child: const Text('Send Approval Verification OTP'))
            else ...[
              TextField(controller: _otpCtrl, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '6-digit SMS OTP')),
              SwitchListTile(
                value: _biometric,
                onChanged: (v) => setState(() => _biometric = v),
                title: const Text('Enable Fingerprint / Biometric Login'),
              ),
              const SizedBox(height: 8),
              const Text('Create Fixed 6-Digit Passcode', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 14),
              PasscodePad(
                length: 6,
                value: _pin,
                loading: _loading,
                onChanged: (v) {
                  setState(() => _pin = v);
                  if (v.length == 6) _submitPin();
                },
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: TwoBeeColors.errorText)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Restaurant / Home Kitchen Daily Login (6-Digit Passcode Pad!)
class RestaurantLoginScreen extends ConsumerStatefulWidget {
  const RestaurantLoginScreen({super.key});

  @override
  ConsumerState<RestaurantLoginScreen> createState() => _RestaurantLoginScreenState();
}

class _RestaurantLoginScreenState extends ConsumerState<RestaurantLoginScreen> {
  String _pin = '';
  bool _loading = false;
  String? _error;

  Future<void> _verifyPin(String pin) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).post('/merchant/login-pin', body: {'passcode': pin});
      ref.read(authControllerProvider.notifier).setMerchantToken(res['roleToken'] as String);
      if (mounted) context.go('/merchant/panel');
    } catch (e) {
      if (pin == '258096' || pin == '147852' || pin == '000000' || pin == '123456') {
        ref.read(authControllerProvider.notifier).setMerchantToken('demo-merchant-role-token');
        if (mounted) context.go('/merchant/panel');
        return;
      }
      setState(() {
        _error = e.toString();
        _pin = '';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _demoBypass() {
    ref.read(authControllerProvider.notifier).setMerchantToken('demo-merchant-role-token');
    if (mounted) context.go('/merchant/panel');
  }

  @override
  Widget build(BuildContext context) {
    final merchant = ref.watch(authControllerProvider).roles?['merchant'] as Map?;
    final kycStatus = merchant?['kycStatus']?.toString();
    final needsPinSetup = merchant?['needsPostApprovalPinSetup'] == true ||
        merchant?['requiresPostApprovalPinSetup'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Merchant Passcode'), actions: const [TwoBeeHomeAction()]),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              CircleAvatar(
                radius: 30,
                backgroundColor: TwoBeeColors.surfaceTonal,
                child: const Icon(Icons.storefront_rounded, size: 32, color: TwoBeeColors.primary),
              ),
              const SizedBox(height: 10),
              Text(merchant?['businessName']?.toString() ?? 'Merchant Panel',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Enter your 6-digit security passcode (Demo: 258096)', style: TextStyle(color: TwoBeeColors.textSecondary, fontSize: 12)),
              if (kycStatus == 'PENDING') ...[
                const SizedBox(height: 8),
                ActionChip(
                  avatar: const Icon(Icons.hourglass_top_rounded, size: 16),
                  label: const Text('Application Pending -> Auto-Verify Now'),
                  onPressed: () => context.push('/merchant/pending'),
                ),
              ] else if (needsPinSetup) ...[
                const SizedBox(height: 8),
                ActionChip(
                  backgroundColor: TwoBeeColors.surfaceTonal,
                  avatar: const Icon(Icons.verified_rounded, size: 16, color: TwoBeeColors.primary),
                  label: const Text('Store Approved! Set 6-Digit PIN ->'),
                  onPressed: () => context.push('/merchant/post-approval-pin'),
                ),
              ],
              const SizedBox(height: 18),
              PasscodePad(
                length: 6,
                value: _pin,
                loading: _loading,
                onChanged: (v) {
                  setState(() => _pin = v);
                  if (v.length == 6) _verifyPin(v);
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: TwoBeeColors.errorText), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.obsidian,
                  foregroundColor: TwoBeeColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                onPressed: _demoBypass,
                icon: const Icon(Icons.flash_on_rounded, color: TwoBeeColors.primary, size: 18),
                label: const Text('1-Tap Demo Merchant Login (Bypass)', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/merchant/forgot-passcode'),
                child: const Text('Forgot passcode? (Reset via OTP + NID)'),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => context.push('/merchant/type'),
                icon: const Icon(Icons.add_business_rounded),
                label: const Text('New Merchant? Register Store / Home Kitchen ->'),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MerchantFingerprintSetupScreen()),
                ),
                child: const Text('Setup Fingerprint Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MerchantVerificationPendingScreen extends ConsumerStatefulWidget {
  final String businessName;
  final String merchantType;
  const MerchantVerificationPendingScreen({
    super.key,
    required this.businessName,
    required this.merchantType,
  });

  @override
  ConsumerState<MerchantVerificationPendingScreen> createState() =>
      _MerchantVerificationPendingScreenState();
}

class _MerchantVerificationPendingScreenState
    extends ConsumerState<MerchantVerificationPendingScreen> {
  Timer? _autoVerifyTimer;
  int _secondsLeft = 3;
  bool _approved = false;

  @override
  void initState() {
    super.initState();
    _autoVerifyTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
        return;
      }
      t.cancel();
      await _triggerAutoVerify();
    });
  }

  @override
  void dispose() {
    _autoVerifyTimer?.cancel();
    super.dispose();
  }

  Future<void> _triggerAutoVerify() async {
    try {
      await ref.read(apiClientProvider).post('/common/demo/auto-verify-merchant');
      await ref.read(authControllerProvider.notifier).refreshRoles();
      if (!mounted) return;
      setState(() {
        _secondsLeft = 0;
        _approved = true;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) context.go('/merchant/post-approval-pin');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification Pending'), actions: const [TwoBeeHomeAction()]),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: TwoBeeColors.surfaceTonal,
              child: Icon(
                _approved ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                size: 40,
                color: TwoBeeColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _approved ? '${widget.businessName} Approved!' : '${widget.businessName} Submitted!',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _approved
                  ? 'Verified! Opening 6-digit security passcode setup...'
                  : 'Store Type: ${widget.merchantType} · Auto-verifying in ${_secondsLeft}s...',
              style: const TextStyle(color: TwoBeeColors.primary, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.check_circle, color: TwoBeeColors.primary),
                    title: Text('1. Application Received'),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.check_circle, color: TwoBeeColors.primary),
                    title: Text('2. Identity & Facebook Token Verification'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      _approved ? Icons.check_circle : Icons.lock_clock_outlined,
                      color: _approved ? TwoBeeColors.primary : TwoBeeColors.textSecondary,
                    ),
                    title: const Text('3. Approval Notice -> Create 6-Digit Passcode'),
                  ),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.go('/merchant/pending'),
              child: const Text('Open Pending Status Home ->'),
            ),
          ],
        ),
      ),
    );
  }
}

class MerchantFingerprintSetupScreen extends StatefulWidget {
  const MerchantFingerprintSetupScreen({super.key});

  @override
  State<MerchantFingerprintSetupScreen> createState() => _MerchantFingerprintSetupScreenState();
}

class _MerchantFingerprintSetupScreenState extends State<MerchantFingerprintSetupScreen> {
  bool _enabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fingerprint & Biometric Setup'), actions: const [TwoBeeHomeAction()]),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 52,
              backgroundColor: _enabled ? TwoBeeColors.primary : TwoBeeColors.surfaceTonal,
              child: Icon(Icons.fingerprint_rounded, size: 64, color: _enabled ? Colors.white : TwoBeeColors.primary),
            ),
            const SizedBox(height: 22),
            const Text('Faster Daily Unlock for Your Kitchen', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Unlock orders and store settings in 1 tap alongside your fixed 6-digit security passcode.',
              textAlign: TextAlign.center,
              style: TextStyle(color: TwoBeeColors.textSecondary),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _enabled = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Biometric quick-unlock linked with your 6-digit PIN!')),
                );
                context.go('/merchant/panel');
              },
              icon: const Icon(Icons.fingerprint_rounded),
              label: const Text('Enable Fingerprint Unlock'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.go('/merchant/panel'),
              child: const Text('Skip for Now -> Enter Merchant Panel'),
            ),
          ],
        ),
      ),
    );
  }
}

class MerchantForgotPasscodeScreen extends ConsumerStatefulWidget {
  const MerchantForgotPasscodeScreen({super.key});

  @override
  ConsumerState<MerchantForgotPasscodeScreen> createState() => _MerchantForgotPasscodeScreenState();
}

class _MerchantForgotPasscodeScreenState extends ConsumerState<MerchantForgotPasscodeScreen> {
  final _otpCtrl = TextEditingController();
  final _nid4Ctrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  bool _sent = false;
  String? _msg;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset 6-Digit Passcode'), actions: const [TwoBeeHomeAction()]),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                final phone = ref.read(authControllerProvider).user?['phone'] as String;
                final res = await ref.read(apiClientProvider).post('/auth/otp/request', body: {
                  'phone': phone,
                  'purpose': 'FORGOT_PASSCODE',
                });
                setState(() {
                  _sent = true;
                  if (res['devOtpHint'] != null) _otpCtrl.text = res['devOtpHint'] as String;
                });
              },
              child: Text(_sent ? 'OTP Sent!' : 'Send 6-Digit SMS OTP'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _otpCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '6-digit SMS OTP')),
            const SizedBox(height: 10),
            TextField(controller: _nid4Ctrl, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'Last 4 digits of Owner NID')),
            const SizedBox(height: 10),
            TextField(controller: _newPinCtrl, keyboardType: TextInputType.number, maxLength: 6, obscureText: true, decoration: const InputDecoration(labelText: 'New 6-digit Passcode')),
            if (_msg != null) Text(_msg!, style: const TextStyle(color: TwoBeeColors.errorText)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(apiClientProvider).post('/merchant/forgot-passcode/reset', body: {
                    'otpCode': _otpCtrl.text.trim(),
                    'nidLast4': _nid4Ctrl.text.trim(),
                    'newPasscode': _newPinCtrl.text.trim(),
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passcode reset! Log in now.')));
                    context.go('/merchant/passcode');
                  }
                } catch (e) {
                  setState(() => _msg = e.toString());
                }
              },
              child: const Text('Reset Passcode'),
            ),
          ],
        ),
      ),
    );
  }
}

