import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/twobee_theme.dart';
import '../../core/widgets/common_widgets.dart';

/// 8-Step Rider KYC Wizard ending with Step 8 Create 4-Digit Passcode (AT registration!) -> Review & Submit
class RiderRegWizardScreen extends ConsumerStatefulWidget {
  const RiderRegWizardScreen({super.key});

  @override
  ConsumerState<RiderRegWizardScreen> createState() => _RiderRegWizardScreenState();
}

class _RiderRegWizardScreenState extends ConsumerState<RiderRegWizardScreen> {
  int _step = 0; // 0..6 (A1 Personal, A2 Docs, A3/4/5 Vehicle, A6/7/8 Carriers, A9 Payout, A10 Terms, Create 4-digit PIN + Review)
  final _nameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController(text: '1997-04-12');
  final _emergNameCtrl = TextEditingController(text: 'Kamal Islam');
  final _emergPhoneCtrl = TextEditingController(text: '+8801812345678');
  final _nidCtrl = TextEditingController(text: '1997269012345');
  final _dlCtrl = TextEditingController(text: 'DK-DL-88241');
  final _dlExpCtrl = TextEditingController(text: '2029-12-31');
  String _ownership = 'OWN'; // OWN | RENTAL
  String _powertrain = 'PETROL';
  final _bikeModelCtrl = TextEditingController(text: 'Honda Livo 110');
  final _plateCtrl = TextEditingController(text: 'DHK-METRO-4421');
  bool _frontCarrier = true;
  bool _rearCarrier = true;
  bool _multiService = true;
  bool _spareHelmet = true;
  String _payoutProvider = 'BKASH';
  final _payoutNoCtrl = TextEditingController();
  bool _t1 = true, _t2 = true, _t3 = true;
  String _passcode = '';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final phone = ref.read(authControllerProvider).user?['phone'] as String? ?? '+8801712345678';
    _payoutNoCtrl.text = phone;
  }

  Future<void> _submit() async {
    if (_passcode.length != 4) {
      setState(() => _error = 'Set your 4-digit rider passcode first');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).post('/rider/register', body: {
        'fullName': _nameCtrl.text.trim().isEmpty ? 'Md. Rafiqul Islam' : _nameCtrl.text.trim(),
        'dob': _dobCtrl.text.trim(),
        'preferredZoneId': 'zone-banani',
        'emergencyName': _emergNameCtrl.text.trim(),
        'emergencyPhone': _emergPhoneCtrl.text.trim(),
        'nidNumber': _nidCtrl.text.trim(),
        'licenseNumber': _dlCtrl.text.trim(),
        'licenseExpiry': _dlExpCtrl.text.trim(),
        'vehicleOwnership': _ownership,
        'powertrain': _ownership == 'RENTAL' ? 'ELECTRIC' : _powertrain,
        'vehicleBrandModel': _ownership == 'RENTAL' ? '2Bee EV Solo (Livo Fleet)' : _bikeModelCtrl.text.trim(),
        'plateNo': _plateCtrl.text.trim(),
        'frontCarrierEnabled': _ownership == 'RENTAL' ? true : _frontCarrier,
        'rearCarrierEnabled': _rearCarrier,
        'multiServiceRequested': (_ownership == 'RENTAL' || _frontCarrier) && _multiService,
        'spareHelmetConfirmed': _spareHelmet,
        'payoutProvider': _payoutProvider,
        'payoutAccountNumber': _payoutNoCtrl.text.trim(),
        'payoutHolderName': _nameCtrl.text.trim().isEmpty ? 'Md. Rafiqul Islam' : _nameCtrl.text.trim(),
        'passcode': _passcode,
      });
      ref.read(authControllerProvider.notifier).setRiderToken(res['roleToken'] as String);
      await ref.read(authControllerProvider.notifier).refreshRoles();
      if (mounted) context.go('/rider/panel');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'A1. Personal Info',
      'A2. Documents',
      'A3–A5. Vehicle Setup',
      'A6–A8. Carriers & Multi-Service',
      'A9. Payout Setup',
      'A10. Terms & Safety',
      'Create 4-Digit Passcode & Review',
    ];

    final hasFront = _ownership == 'RENTAL' || _frontCarrier;

    return Scaffold(
      appBar: AppBar(title: Text(titles[_step])),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LinearProgressIndicator(value: (_step + 1) / 7, color: TwoBeeColors.primary, backgroundColor: TwoBeeColors.surfaceTonal),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  if (_step == 0) ...[
                    TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name (NID Sync)')),
                    const SizedBox(height: 10),
                    TextField(controller: _dobCtrl, decoration: const InputDecoration(labelText: 'Date of Birth (18+)')),
                    const SizedBox(height: 10),
                    TextField(controller: _emergNameCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact Name')),
                    const SizedBox(height: 10),
                    TextField(controller: _emergPhoneCtrl, decoration: const InputDecoration(labelText: 'Emergency Phone')),
                  ] else if (_step == 1) ...[
                    TextField(controller: _nidCtrl, decoration: const InputDecoration(labelText: 'National ID (NID Number)')),
                    const SizedBox(height: 10),
                    TextField(controller: _dlCtrl, decoration: const InputDecoration(labelText: 'Driving License Number')),
                    const SizedBox(height: 10),
                    TextField(controller: _dlExpCtrl, decoration: const InputDecoration(labelText: 'License Expiry Date')),
                    const SizedBox(height: 10),
                    const Card(
                      color: TwoBeeColors.surfaceTonal,
                      child: ListTile(
                        leading: Icon(Icons.verified_user_outlined, color: TwoBeeColors.primary),
                        title: Text('NID Front/Back, DL Front/Back & Selfie'),
                        subtitle: Text('Ready for KYC verification'),
                      ),
                    ),
                  ] else if (_step == 2) ...[
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'OWN', label: Text('Own Bike')),
                        ButtonSegment(value: 'RENTAL', label: Text('Rent EV Bike')),
                      ],
                      selected: {_ownership},
                      onSelectionChanged: (v) => setState(() => _ownership = v.first),
                    ),
                    const SizedBox(height: 12),
                    if (_ownership == 'OWN') ...[
                      DropdownButtonFormField<String>(
                        initialValue: _powertrain,
                        decoration: const InputDecoration(labelText: 'Powertrain'),
                        items: const [
                          DropdownMenuItem(value: 'PETROL', child: Text('Petrol Motorcycle')),
                          DropdownMenuItem(value: 'ELECTRIC', child: Text('Electric Bike')),
                        ],
                        onChanged: (v) => setState(() => _powertrain = v ?? 'PETROL'),
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: _bikeModelCtrl, decoration: const InputDecoration(labelText: 'Brand & Model')),
                      const SizedBox(height: 10),
                      TextField(controller: _plateCtrl, decoration: const InputDecoration(labelText: 'Registration Plate')),
                    ] else
                      const Card(
                        color: TwoBeeColors.surfaceTonal,
                        child: ListTile(
                          leading: Icon(Icons.electric_moped_rounded, color: TwoBeeColors.primary),
                          title: Text('Banani Hub · 2Bee EV Solo (৳250/day)'),
                          subtitle: Text('Pre-fitted front 8kg carrier + rear seat ready for multi-service'),
                        ),
                      ),
                  ] else if (_step == 3) ...[
                    SwitchListTile(
                      value: hasFront,
                      onChanged: _ownership == 'RENTAL' ? null : (v) => setState(() {
                        _frontCarrier = v;
                        if (!v) _multiService = false;
                      }),
                      title: const Text('Front Carrier (35×30×30 cm · Max 8 kg)'),
                      subtitle: const Text('Required to unlock Zone A→B Multi-Service'),
                    ),
                    SwitchListTile(
                      value: _rearCarrier,
                      onChanged: (v) => setState(() => _rearCarrier = v),
                      title: const Text('Rear Carrier / Box (Max 15 kg)'),
                    ),
                    const Divider(),
                    SwitchListTile(
                      value: _multiService && hasFront,
                      onChanged: hasFront ? (v) => setState(() => _multiService = v) : null,
                      title: const Text('Enable Multi-Service (Normal Parcel + Passenger)'),
                      subtitle: Text(hasFront ? 'Carry <=8kg front parcel + matching Zone A→B rider' : 'Locked: Add front carrier to unlock'),
                    ),
                    CheckboxListTile(
                      value: _spareHelmet,
                      onChanged: hasFront ? (v) => setState(() => _spareHelmet = v ?? false) : null,
                      title: const Text('I carry a spare passenger helmet'),
                    ),
                  ] else if (_step == 4) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _payoutProvider,
                      decoration: const InputDecoration(labelText: 'Payout Account'),
                      items: const [
                        DropdownMenuItem(value: 'BKASH', child: Text('bKash (Preview)')),
                        DropdownMenuItem(value: 'NAGAD', child: Text('Nagad (Preview)')),
                        DropdownMenuItem(value: 'ROCKET', child: Text('Rocket (Preview)')),
                        DropdownMenuItem(value: 'BANK_BEFTN', child: Text('Bank Account BEFTN')),
                      ],
                      onChanged: (v) => setState(() => _payoutProvider = v ?? 'BKASH'),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _payoutNoCtrl, decoration: const InputDecoration(labelText: 'Wallet / Account Number')),
                  ] else if (_step == 5) ...[
                    CheckboxListTile(value: _t1, onChanged: (v) => setState(() => _t1 = v ?? false), title: const Text('I accept 2Bee Rider Terms')),
                    CheckboxListTile(value: _t2, onChanged: (v) => setState(() => _t2 = v ?? false), title: const Text('I accept Road Safety & Passenger-First Dropoff Rules')),
                    CheckboxListTile(value: _t3, onChanged: (v) => setState(() => _t3 = v ?? false), title: const Text('My front carrier dims & capacity are accurate')),
                  ] else ...[
                    const Text('Set Permanent 4-Digit Rider Passcode', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text('Avoid 1234 or repeated digits. Used every time you open Rider Panel.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary)),
                    const SizedBox(height: 16),
                    PasscodePad(length: 4, value: _passcode, loading: _loading, onChanged: (v) => setState(() => _passcode = v)),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: TwoBeeColors.errorText)),
                    ],
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
                            if (_step < 6) {
                              if (_step == 5 && !(_t1 && _t2 && _t3)) return;
                              setState(() => _step++);
                            } else {
                              _submit();
                            }
                          },
                    child: Text(_step < 6 ? 'Next ->' : (_loading ? 'Submitting...' : 'Submit & Open Panel')),
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

class RiderEnterPasscodeScreen extends ConsumerStatefulWidget {
  const RiderEnterPasscodeScreen({super.key});

  @override
  ConsumerState<RiderEnterPasscodeScreen> createState() => _RiderEnterPasscodeScreenState();
}

class _RiderEnterPasscodeScreenState extends ConsumerState<RiderEnterPasscodeScreen> {
  String _pin = '';
  bool _loading = false;
  String? _error;

  Future<void> _submit(String pin) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).post('/rider/login-pin', body: {'passcode': pin});
      ref.read(authControllerProvider.notifier).setRiderToken(res['roleToken'] as String);
      if (mounted) context.go('/rider/panel');
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
    final name = ref.watch(authControllerProvider).user?['fullName']?.toString() ?? 'Rider';
    return Scaffold(
      appBar: AppBar(title: const Text('Rider Passcode Verification')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const CircleAvatar(radius: 32, backgroundColor: TwoBeeColors.surfaceTonal, child: Icon(Icons.two_wheeler_rounded, size: 32, color: TwoBeeColors.primary)),
              const SizedBox(height: 12),
              Text('Welcome back, $name', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Enter your 4-digit security passcode (Demo: 2580)', style: TextStyle(color: TwoBeeColors.textSecondary)),
              const SizedBox(height: 24),
              PasscodePad(
                length: 4,
                value: _pin,
                loading: _loading,
                onChanged: (v) {
                  setState(() => _pin = v);
                  if (v.length == 4) _submit(v);
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: TwoBeeColors.errorText)),
              ],
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/rider/forgot-passcode'),
                child: const Text('Forgot passcode? (Reset via OTP + NID)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RiderForgotPasscodeScreen extends ConsumerStatefulWidget {
  const RiderForgotPasscodeScreen({super.key});

  @override
  ConsumerState<RiderForgotPasscodeScreen> createState() => _RiderForgotPasscodeScreenState();
}

class _RiderForgotPasscodeScreenState extends ConsumerState<RiderForgotPasscodeScreen> {
  final _otpCtrl = TextEditingController();
  final _nid4Ctrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  bool _sent = false;
  String? _err;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset 4-Digit Rider PIN')),
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
              child: Text(_sent ? 'OTP Sent!' : 'Send SMS OTP'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _otpCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '6-digit SMS OTP')),
            const SizedBox(height: 10),
            TextField(controller: _nid4Ctrl, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'Last 4 digits of NID')),
            const SizedBox(height: 10),
            TextField(controller: _newPinCtrl, keyboardType: TextInputType.number, maxLength: 4, obscureText: true, decoration: const InputDecoration(labelText: 'New 4-digit Passcode')),
            if (_err != null) Text(_err!, style: const TextStyle(color: TwoBeeColors.errorText)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(apiClientProvider).post('/rider/forgot-passcode/reset', body: {
                    'otpCode': _otpCtrl.text.trim(),
                    'nidLast4': _nid4Ctrl.text.trim(),
                    'newPasscode': _newPinCtrl.text.trim(),
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('4-digit Rider PIN reset!')));
                    context.go('/rider/passcode');
                  }
                } catch (e) {
                  setState(() => _err = e.toString());
                }
              },
              child: const Text('Save New 4-Digit Passcode'),
            ),
          ],
        ),
      ),
    );
  }
}

