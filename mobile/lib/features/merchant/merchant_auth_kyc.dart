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
      appBar: AppBar(title: const Text('Partner Store Type')),
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
  String _cutoff = '20:00';
  bool _hygieneOk = true;
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
      });
      await ref.read(authControllerProvider.notifier).refreshRoles();
      if (mounted) context.go('/merchant/pending');
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
      appBar: AppBar(title: Text(titles[_step])),
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
                    if (isPhysical) ...[
                      const SizedBox(height: 10),
                      TextField(controller: _etinCtrl, decoration: const InputDecoration(labelText: '12-digit e-TIN')),
                      const SizedBox(height: 10),
                      TextField(controller: _tradeCtrl, decoration: const InputDecoration(labelText: 'Trade License Number')),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text('e-TIN is optional for Home Kitchens.', style: TextStyle(color: TwoBeeColors.textSecondary)),
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
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: _hygieneOk,
                        onChanged: (v) => setState(() => _hygieneOk = v ?? false),
                        title: const Text('I accept 2Bee Home Kitchen Hygiene & Fresh-Batch Standards'),
                      ),
                    ] else
                      const Card(
                        child: ListTile(
                          leading: Icon(Icons.camera_alt_outlined, color: TwoBeeColors.primary),
                          title: Text('Storefront, Kitchen & Dish Photos Ready'),
                          subtitle: Text('Default hours: Mon–Sun 11:00 AM – 11:00 PM'),
                        ),
                      ),
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
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Store Type: ${widget.merchantType}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('Name: ${_nameCtrl.text.isEmpty ? "Ready" : _nameCtrl.text}'),
                            Text('NID: ${_nidCtrl.text}'),
                            if (!isPhysical) Text('Home Kitchen Cap: $_quota orders/day · Cutoff $_cutoff'),
                            const SizedBox(height: 8),
                            const Text('Security Note: Passcode is NOT required now. After admin approves your KYC, your approval notice will ask you to set your permanent 6-digit passcode.',
                                style: TextStyle(fontSize: 12, color: TwoBeeColors.primary)),
                          ],
                        ),
                      ),
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
      appBar: AppBar(title: const Text('Verification Update Required')),
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
      if (mounted) context.go('/merchant/panel');
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
      appBar: AppBar(title: const Text('Store Approved · Set 6-Digit Passcode')),
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
    final merchant = ref.watch(authControllerProvider).roles?['merchant'] as Map?;
    return Scaffold(
      appBar: AppBar(title: const Text('Merchant Passcode')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              CircleAvatar(
                radius: 32,
                backgroundColor: TwoBeeColors.surfaceTonal,
                child: const Icon(Icons.storefront_rounded, size: 34, color: TwoBeeColors.primary),
              ),
              const SizedBox(height: 12),
              Text(merchant?['businessName']?.toString() ?? 'Merchant Panel',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Enter your 6-digit security passcode', style: TextStyle(color: TwoBeeColors.textSecondary)),
              const SizedBox(height: 24),
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
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: TwoBeeColors.errorText), textAlign: TextAlign.center),
              ],
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/merchant/forgot-passcode'),
                child: const Text('Forgot passcode? (Reset via OTP + NID)'),
              ),
            ],
          ),
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
      appBar: AppBar(title: const Text('Reset 6-Digit Passcode')),
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

