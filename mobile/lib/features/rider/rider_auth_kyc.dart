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
  int _step = 0; // 0..8: A1 Personal, A2 Docs, A3 Choice, A4/A5 Bike/Rental, A6/7/8 Carriers, A9 Payout, A10 Terms, Create PIN, Review & Submit
  final _nameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController(text: '1997-04-12');
  String _gender = 'Male';
  String _zoneId = 'zone-banani';
  final _emergNameCtrl = TextEditingController(text: 'Kamal Islam');
  final _emergRelCtrl = TextEditingController(text: 'Brother');
  final _emergPhoneCtrl = TextEditingController(text: '+8801812345678');
  final _nidCtrl = TextEditingController(text: '1997269012345');
  final _dlCtrl = TextEditingController(text: 'DK-DL-88241');
  final _dlExpCtrl = TextEditingController(text: '2029-12-31');
  bool _dlFront = true, _dlBack = true, _nidFront = true, _nidBack = true, _selfieOk = true;
  String _ownership = 'OWN'; // OWN | RENTAL
  String _powertrain = 'PETROL';
  final _bikeModelCtrl = TextEditingController(text: 'Honda Livo 110');
  final _yearCtrl = TextEditingController(text: '2024');
  final _plateCtrl = TextEditingController(text: 'DHK-METRO-4421');
  String _rentalHub = 'Banani Hub';
  String _rentalPlan = 'DAILY';
  String _handoverSlot = 'Tomorrow 10:00 AM';
  bool _frontCarrier = true;
  bool _rearCarrier = true;
  bool _multiService = true;
  bool _spareHelmet = true;
  final _fLenCtrl = TextEditingController(text: '35');
  final _fWidCtrl = TextEditingController(text: '30');
  final _fHgtCtrl = TextEditingController(text: '30');
  String _payoutTab = 'MFS';
  String _payoutProvider = 'BKASH';
  String _walletType = 'PERSONAL';
  bool _instantCashout = true;
  final _payoutNoCtrl = TextEditingController();
  bool _t1 = true, _t2 = true, _t3 = true;
  String _passcode = '';
  bool _biometric = true;
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
      setState(() => _error = 'Set your 4-digit rider passcode on the previous step');
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
        'preferredZoneId': _zoneId,
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
        'payoutProvider': _payoutTab == 'BANK' ? 'BANK_BEFTN' : _payoutProvider,
        'payoutAccountNumber': _payoutNoCtrl.text.trim(),
        'payoutHolderName': _nameCtrl.text.trim().isEmpty ? 'Md. Rafiqul Islam' : _nameCtrl.text.trim(),
        'passcode': _passcode,
        'reRegisterDemo': true,
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
    final hasFront = _ownership == 'RENTAL' || _frontCarrier;
    final titles = [
      'A1. Personal Info',
      'A2. Documents & Selfie',
      'A3. Vehicle Choice',
      _ownership == 'OWN' ? 'A4. Own Bike Details' : 'A5. Rental Bike Setup',
      _ownership == 'RENTAL'
          ? 'A8. Carriers (Rented Bike)'
          : (hasFront ? 'A6. Carriers & Multi-Service' : 'A7. No Front Carrier'),
      'A9. Payout Setup',
      'A10. Terms & Safety',
      'Create 4-Digit Passcode',
      'Review & Submit',
    ];
    final phone = ref.read(authControllerProvider).user?['phone'] as String? ?? '+8801712345678';
    final volCm3 = (double.tryParse(_fLenCtrl.text) ?? 35) * (double.tryParse(_fWidCtrl.text) ?? 30) * (double.tryParse(_fHgtCtrl.text) ?? 30);

    return Scaffold(
      appBar: AppBar(title: Text(titles[_step]), actions: const [TwoBeeHomeAction()]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LinearProgressIndicator(value: (_step + 1) / 9, color: TwoBeeColors.primary, backgroundColor: TwoBeeColors.surfaceTonal),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Step ${_step + 1} of 9', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TwoBeeColors.textSecondary)),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  if (_step == 0) ...[
                    TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name (NID Sync)')),
                    const SizedBox(height: 10),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'Verified Mobile Phone (Read-Only)'),
                      child: Text(phone, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _dobCtrl, decoration: const InputDecoration(labelText: 'Date of Birth (18+)')),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [ButtonSegment(value: 'Male', label: Text('Male')), ButtonSegment(value: 'Female', label: Text('Female'))],
                      selected: {_gender},
                      onSelectionChanged: (v) => setState(() => _gender = v.first),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _zoneId,
                      decoration: const InputDecoration(labelText: 'Preferred Working Zone (Surge Rate Hint)'),
                      items: const [
                        DropdownMenuItem(value: 'zone-banani', child: Text('Banani / Gulshan (High Demand · 1.4x)')),
                        DropdownMenuItem(value: 'zone-uttara', child: Text('Uttara Hub (Steady Multi-Service)')),
                        DropdownMenuItem(value: 'zone-dhanmondi', child: Text('Dhanmondi / Mirpur')),
                      ],
                      onChanged: (v) => setState(() => _zoneId = v ?? 'zone-banani'),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _emergNameCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact Name')),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _emergRelCtrl, decoration: const InputDecoration(labelText: 'Relation'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _emergPhoneCtrl, decoration: const InputDecoration(labelText: 'Emergency Phone'))),
                      ],
                    ),
                  ] else if (_step == 1) ...[
                    TextField(controller: _nidCtrl, decoration: const InputDecoration(labelText: 'National ID (10/17 digits)')),
                    const SizedBox(height: 10),
                    TextField(controller: _dlCtrl, decoration: const InputDecoration(labelText: 'Driving License Number')),
                    const SizedBox(height: 10),
                    TextField(controller: _dlExpCtrl, decoration: const InputDecoration(labelText: 'License Expiry Date')),
                    const SizedBox(height: 10),
                    CheckboxListTile(value: _dlFront, onChanged: (v) => setState(() => _dlFront = v ?? true), title: const Text('Driving License Front Photo Uploaded')),
                    CheckboxListTile(value: _dlBack, onChanged: (v) => setState(() => _dlBack = v ?? true), title: const Text('Driving License Back Photo Uploaded')),
                    CheckboxListTile(value: _nidFront, onChanged: (v) => setState(() => _nidFront = v ?? true), title: const Text('NID Front Photo Uploaded')),
                    CheckboxListTile(value: _nidBack, onChanged: (v) => setState(() => _nidBack = v ?? true), title: const Text('NID Back Photo Uploaded')),
                    CheckboxListTile(value: _selfieOk, onChanged: (v) => setState(() => _selfieOk = v ?? true), title: const Text('Live Selfie Holding License Captured')),
                  ] else if (_step == 2) ...[
                    const Text('How will you ride with 2Bee?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Card(
                      color: _ownership == 'OWN' ? TwoBeeColors.surfaceTonal : TwoBeeColors.surfaceCard,
                      child: ListTile(
                        leading: const Icon(Icons.two_wheeler_rounded, color: TwoBeeColors.primary, size: 30),
                        title: const Text('I Have My Own Bike (A4)', style: TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: const Text('Petrol or Electric · Verify carrier sizes in Step 5'),
                        trailing: Icon(_ownership == 'OWN' ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: TwoBeeColors.primary),
                        onTap: () => setState(() => _ownership = 'OWN'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      color: _ownership == 'RENTAL' ? TwoBeeColors.surfaceTonal : TwoBeeColors.surfaceCard,
                      child: ListTile(
                        leading: const Icon(Icons.electric_moped_rounded, color: TwoBeeColors.primary, size: 30),
                        title: const Text('Rent a 2Bee EV Bike (A5)', style: TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: const Text('Pre-fitted Front 8kg & Rear 15kg carriers · Free battery swaps'),
                        trailing: Icon(_ownership == 'RENTAL' ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: TwoBeeColors.primary),
                        onTap: () => setState(() {
                          _ownership = 'RENTAL';
                          _frontCarrier = true;
                        }),
                      ),
                    ),
                  ] else if (_step == 3) ...[
                    if (_ownership == 'OWN') ...[
                      DropdownButtonFormField<String>(
                        initialValue: _powertrain,
                        decoration: const InputDecoration(labelText: 'Powertrain'),
                        items: const [
                          DropdownMenuItem(value: 'PETROL', child: Text('Petrol Motorcycle')),
                          DropdownMenuItem(value: 'ELECTRIC', child: Text('Electric Bike / EV')),
                        ],
                        onChanged: (v) => setState(() => _powertrain = v ?? 'PETROL'),
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: _bikeModelCtrl, decoration: const InputDecoration(labelText: 'Brand & Model')),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _yearCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Model Year'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: _plateCtrl, decoration: const InputDecoration(labelText: 'Registration Plate'))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Card(
                        color: TwoBeeColors.surfaceTonal,
                        child: ListTile(
                          leading: Icon(Icons.camera_alt_outlined, color: TwoBeeColors.primary),
                          title: Text('Bike Side Photo & Reg Paper Ready'),
                          subtitle: Text('BRTA Blue Book / EV receipt verified'),
                        ),
                      ),
                    ] else ...[
                      DropdownButtonFormField<String>(
                        initialValue: _rentalHub,
                        decoration: const InputDecoration(labelText: 'Select 2Bee Fleet Hub'),
                        items: const [
                          DropdownMenuItem(value: 'Banani Hub', child: Text('Banani Hub (Road 11)')),
                          DropdownMenuItem(value: 'Mirpur Hub', child: Text('Mirpur 10 Hub')),
                          DropdownMenuItem(value: 'Uttara Hub', child: Text('Uttara Sector 7 Hub')),
                        ],
                        onChanged: (v) => setState(() => _rentalHub = v ?? 'Banani Hub'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _rentalPlan,
                        decoration: const InputDecoration(labelText: 'Select Rental Plan'),
                        items: const [
                          DropdownMenuItem(value: 'DAILY', child: Text('Daily Plan · ৳250 / day')),
                          DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly Saver · ৳1,500 / week')),
                          DropdownMenuItem(value: 'RENT_TO_OWN', child: Text('Rent-to-Own · ৳320 / day')),
                        ],
                        onChanged: (v) => setState(() => _rentalPlan = v ?? 'DAILY'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _handoverSlot,
                        decoration: const InputDecoration(labelText: 'Handover Date & Time Slot'),
                        items: const [
                          DropdownMenuItem(value: 'Tomorrow 10:00 AM', child: Text('Tomorrow · 10:00 AM')),
                          DropdownMenuItem(value: 'Tomorrow 02:00 PM', child: Text('Tomorrow · 02:00 PM')),
                        ],
                        onChanged: (v) => setState(() => _handoverSlot = v ?? 'Tomorrow 10:00 AM'),
                      ),
                      const SizedBox(height: 10),
                      const Card(
                        color: TwoBeeColors.surfaceTonal,
                        child: ListTile(
                          leading: Icon(Icons.battery_charging_full_rounded, color: TwoBeeColors.primary),
                          title: Text('Glafit LOM / 2Bee EV Solo Assigned'),
                          subtitle: Text('Pre-fitted Front 8kg rack + Rear 15kg carrier + 2 free swaps/day'),
                        ),
                      ),
                    ],
                  ] else if (_step == 4) ...[
                    SwitchListTile(
                      value: hasFront,
                      onChanged: _ownership == 'RENTAL'
                          ? null
                          : (v) => setState(() {
                                _frontCarrier = v;
                                if (!v) _multiService = false;
                              }),
                      title: const Text('Front Carrier Fitted (Max 8.0 kg)'),
                      subtitle: const Text('Required to unlock Zone A→B Multi-Service'),
                    ),
                    if (hasFront) ...[
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _fLenCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'L (cm)'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: _fWidCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'W (cm)'))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: _fHgtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'H (cm)'))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Computed Front Capacity: ${(volCm3 / 1000).toStringAsFixed(1)}L / 8.0 kg max · Front Carrier Photo Ready',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TwoBeeColors.primary)),
                    ] else
                      const VerificationBanner(
                        title: 'A7. Multi-Service Locked (No Front Carrier)',
                        subtitle: 'Add a verified front carrier to carry <= 8 kg parcels while keeping the rear pillion seat open for passengers.',
                        isErrorStyle: true,
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
                      subtitle: Text(hasFront ? 'Zone A→B matching ready' : 'Locked until front carrier added'),
                    ),
                    CheckboxListTile(
                      value: _spareHelmet,
                      onChanged: hasFront ? (v) => setState(() => _spareHelmet = v ?? false) : null,
                      title: const Text('I carry a spare passenger helmet'),
                    ),
                  ] else if (_step == 5) ...[
                    SegmentedButton<String>(
                      segments: const [ButtonSegment(value: 'MFS', label: Text('MFS Wallet')), ButtonSegment(value: 'BANK', label: Text('Bank BEFTN'))],
                      selected: {_payoutTab},
                      onSelectionChanged: (v) => setState(() => _payoutTab = v.first),
                    ),
                    const SizedBox(height: 12),
                    if (_payoutTab == 'MFS') ...[
                      DropdownButtonFormField<String>(
                        initialValue: _payoutProvider,
                        decoration: const InputDecoration(labelText: 'MFS Provider (Preview / Settlement)'),
                        items: const [
                          DropdownMenuItem(value: 'BKASH', child: Text('bKash')),
                          DropdownMenuItem(value: 'NAGAD', child: Text('Nagad')),
                          DropdownMenuItem(value: 'ROCKET', child: Text('Rocket')),
                        ],
                        onChanged: (v) => setState(() => _payoutProvider = v ?? 'BKASH'),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [ButtonSegment(value: 'PERSONAL', label: Text('Personal')), ButtonSegment(value: 'MERCHANT', label: Text('Merchant'))],
                        selected: {_walletType},
                        onSelectionChanged: (v) => setState(() => _walletType = v.first),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextField(controller: _payoutNoCtrl, decoration: InputDecoration(labelText: _payoutTab == 'BANK' ? 'Bank Account Number' : 'MFS Mobile Number')),
                    SwitchListTile(
                      value: _instantCashout,
                      onChanged: (v) => setState(() => _instantCashout = v),
                      title: const Text('Daily Instant Cash-out (up to ৳2,000/day after 5 trips)'),
                    ),
                  ] else if (_step == 6) ...[
                    const VerificationBanner(
                      title: '2Bee Certified Rider Standard',
                      subtitle: 'Review safety rules and multi-service compliance below.',
                    ),
                    const SizedBox(height: 8),
                    const ExpansionTile(title: Text('1. Rider Conduct & Uniform'), children: [Padding(padding: EdgeInsets.all(12), child: Text('Polite customer communication, verified phone & clean 2Bee gear.'))]),
                    const ExpansionTile(title: Text('2. Front & Rear Payload Limits'), children: [Padding(padding: EdgeInsets.all(12), child: Text('Front rack <= 8 kg / 31.5L; Rear carrier <= 15 kg.'))]),
                    const ExpansionTile(title: Text('3. Zone A→B Multi-Service Safety'), children: [Padding(padding: EdgeInsets.all(12), child: Text('Normal parcels only; Passenger MUST be dropped before Parcel delivery.'))]),
                    const ExpansionTile(title: Text('4. Weekly Friday Settlement & EV Rentals'), children: [Padding(padding: EdgeInsets.all(12), child: Text('Rental auto-debit settles daily; payout account updates carry a 48h hold.'))]),
                    CheckboxListTile(value: _t1, onChanged: (v) => setState(() => _t1 = v ?? false), title: const Text('I accept 2Bee Rider Terms')),
                    CheckboxListTile(value: _t2, onChanged: (v) => setState(() => _t2 = v ?? false), title: const Text('I accept Passenger-First Dropoff Safety')),
                    CheckboxListTile(value: _t3, onChanged: (v) => setState(() => _t3 = v ?? false), title: const Text('All submitted documents & dimensions are accurate')),
                  ] else if (_step == 7) ...[
                    const Text('Create Permanent 4-Digit Rider Passcode', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text('Avoid 1234 or 0000. Required at registration and every daily login.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary)),
                    const SizedBox(height: 16),
                    PasscodePad(length: 4, value: _passcode, loading: _loading, onChanged: (v) => setState(() => _passcode = v)),
                    const SizedBox(height: 10),
                    SwitchListTile(value: _biometric, onChanged: (v) => setState(() => _biometric = v), title: const Text('Enable Fingerprint Quick-Unlock')),
                  ] else ...[
                    const Text('Registration Summary · Review & Edit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          ListTile(title: Text('Personal: ${_nameCtrl.text.isEmpty ? "Md. Rafiqul Islam" : _nameCtrl.text} ($_gender)'), subtitle: Text('Zone: $_zoneId · Emerg: ${_emergNameCtrl.text}'), trailing: TextButton(onPressed: () => setState(() => _step = 0), child: const Text('Edit'))),
                          const Divider(height: 1),
                          ListTile(title: Text('NID ${_nidCtrl.text} · DL ${_dlCtrl.text}'), subtitle: const Text('5/5 KYC Photos & Selfie Ready'), trailing: TextButton(onPressed: () => setState(() => _step = 1), child: const Text('Edit'))),
                          const Divider(height: 1),
                          ListTile(title: Text('Vehicle: ${_ownership == "RENTAL" ? "2Bee EV Rental ($_rentalHub · $_rentalPlan)" : "${_bikeModelCtrl.text} (${_plateCtrl.text})"}'), trailing: TextButton(onPressed: () => setState(() => _step = 3), child: const Text('Edit'))),
                          const Divider(height: 1),
                          ListTile(title: Text('Carriers: ${hasFront ? "Front 8kg + Rear" : "Rear Only (No Multi-Service)"}'), subtitle: Text('Multi-Service: ${(hasFront && _multiService) ? "Enabled" : "Locked"}'), trailing: TextButton(onPressed: () => setState(() => _step = 4), child: const Text('Edit'))),
                          const Divider(height: 1),
                          ListTile(title: Text('Payout: ${_payoutTab == "BANK" ? "BEFTN" : _payoutProvider} · ${_payoutNoCtrl.text}'), trailing: TextButton(onPressed: () => setState(() => _step = 5), child: const Text('Edit'))),
                          const Divider(height: 1),
                          ListTile(title: Text('Security Passcode: ${_passcode.length == 4 ? "4-Digit PIN Set ✓" : "Not Set"}'), trailing: TextButton(onPressed: () => setState(() => _step = 7), child: const Text('Edit'))),
                        ],
                      ),
                    ),
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
                            if (_step == 6 && !(_t1 && _t2 && _t3)) return;
                            if (_step == 7 && _passcode.length != 4) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter 4 digits')));
                              return;
                            }
                            if (_step < 8) {
                              setState(() => _step++);
                            } else {
                              _submit();
                            }
                          },
                    child: Text(_step < 8 ? 'Next ->' : (_loading ? 'Submitting...' : 'Submit Application ->')),
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
      if (pin == '2580' || pin == '0000' || pin == '1234') {
        ref.read(authControllerProvider.notifier).setRiderToken('demo-rider-role-token');
        if (mounted) context.go('/rider/panel');
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
    ref.read(authControllerProvider.notifier).setRiderToken('demo-rider-role-token');
    if (mounted) context.go('/rider/panel');
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(authControllerProvider).user?['fullName']?.toString() ?? 'Rider';
    return Scaffold(
      appBar: AppBar(title: const Text('Rider Passcode Verification'), actions: const [TwoBeeHomeAction()]),
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
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwoBeeColors.obsidian,
                  foregroundColor: TwoBeeColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: TwoBeeRadii.pill),
                ),
                onPressed: _demoBypass,
                icon: const Icon(Icons.flash_on_rounded, color: TwoBeeColors.primary, size: 18),
                label: const Text('1-Tap Demo Rider Login (Bypass)', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/rider/forgot-passcode'),
                child: const Text('Forgot passcode? (Reset via OTP + NID)'),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => context.push('/rider/register'),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('New Rider? Register / Setup KYC ->'),
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
      appBar: AppBar(title: const Text('Reset 4-Digit Rider PIN'), actions: const [TwoBeeHomeAction()]),
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

