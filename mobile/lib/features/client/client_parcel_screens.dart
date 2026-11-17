import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/twobee_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../common/shared_screens.dart';

const _parcelZones = [
  {'id': 'zone-banani', 'name': 'Road 11, Banani', 'lat': 23.7937, 'lng': 90.4066},
  {'id': 'zone-uttara', 'name': 'Road 13, Sector 7, Uttara', 'lat': 23.8726, 'lng': 90.3983},
  {'id': 'zone-dhanmondi', 'name': 'Dhanmondi 27, Dhaka', 'lat': 23.7529, 'lng': 90.3736},
  {'id': 'zone-gulshan', 'name': 'Gulshan 1 Avenue, Dhaka', 'lat': 23.7798, 'lng': 90.4167},
];

/// Alias to preserve backwards compatibility across existing routes and catalog.
typedef ParcelHubScreen = ParcelServiceScreen;

/// Direct Person-to-Person (P2P · No Hub) Parcel Service
/// Includes two primary sections:
/// 1. Send Parcel (P2P direct door-to-door courier dispatch)
/// 2. Receive Parcel (Incoming parcels for client, delivery PIN handover, and live tracking)
class ParcelServiceScreen extends ConsumerStatefulWidget {
  final int initialTab; // 0: Send Parcel, 1: Receive Parcel
  const ParcelServiceScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<ParcelServiceScreen> createState() => _ParcelServiceScreenState();
}

class _ParcelServiceScreenState extends ConsumerState<ParcelServiceScreen> {
  late int _activeTab; // 0: Send, 1: Receive

  // --- Send Parcel Wizard State ---
  int _sendStep = 0; // 0: Addresses & Contacts, 1: Package Specs, 2: Review & Payment
  Map<String, dynamic> _pickup = _parcelZones[0];
  Map<String, dynamic> _dropoff = _parcelZones[1];
  String _tier = 'NORMAL_ECO'; // NORMAL_ECO | NEXT_DAY | EXPRESS
  String _sizeClass = 'MEDIUM';
  String _category = 'Electronics & Gadgets';
  double _weightKg = 2.0;
  bool _protected = false;
  final _senderName = TextEditingController(text: 'Tanvir Ahmed');
  final _senderPhone = TextEditingController(text: '+8801711111111');
  final _senderNote = TextEditingController(text: 'Floor 3, Apt 3B');
  final _recipientName = TextEditingController(text: 'Farhana Yasmin');
  final _recipientPhone = TextEditingController(text: '+8801811111111');
  final _recipientNote = TextEditingController(text: 'Direct doorstep delivery');
  final _codGoodsCtrl = TextEditingController(text: '1200');
  final _lengthCtrl = TextEditingController(text: '30');
  final _widthCtrl = TextEditingController(text: '20');
  final _heightCtrl = TextEditingController(text: '15');
  final _declaredValCtrl = TextEditingController(text: '1500');
  final _handlingNoteCtrl = TextEditingController();
  String _payment = 'COD';
  Map<String, dynamic>? _estimate;
  bool _sendLoading = false;

  // --- Receive Parcel State ---
  final _trackingCodeCtrl = TextEditingController();
  List<Map<String, dynamic>> _incomingList = [];
  bool _incomingLoading = false;
  bool _trackSearching = false;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchIncoming();
    });
  }

  @override
  void dispose() {
    _senderName.dispose();
    _senderPhone.dispose();
    _senderNote.dispose();
    _recipientName.dispose();
    _recipientPhone.dispose();
    _recipientNote.dispose();
    _codGoodsCtrl.dispose();
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _declaredValCtrl.dispose();
    _handlingNoteCtrl.dispose();
    _trackingCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchEstimate() async {
    setState(() => _sendLoading = true);
    try {
      final res = await ref.read(apiClientProvider).post('/parcels/estimate', body: {
        'pickupLat': _pickup['lat'],
        'pickupLng': _pickup['lng'],
        'pickupZoneId': _pickup['id'],
        'dropoffLat': _dropoff['lat'],
        'dropoffLng': _dropoff['lng'],
        'dropoffZoneId': _dropoff['id'],
        'tier': _tier,
        'weightKg': _weightKg,
        'isProtected': _protected,
      });
      setState(() => _estimate = res);
    } catch (e) {
      if (mounted) {
        showAutoDismissToast(context, 'Could not calculate estimate: $e');
      }
    } finally {
      if (mounted) setState(() => _sendLoading = false);
    }
  }

  Future<void> _submitBooking() async {
    final total = (_estimate?['breakdown']?['deliveryChargeBdt'] as num?) ?? 95;
    if (_payment == 'STRIPE_SANDBOX') {
      final paid = await showStripeSandboxDialog(context, amountBdt: total, title: 'Parcel Delivery Charge');
      if (!paid) return;
    }
    setState(() => _sendLoading = true);
    try {
      final note = _handlingNoteCtrl.text.trim();
      final res = await ref.read(apiClientProvider).post('/parcels/book', body: {
        'tier': _tier,
        'packageSizeClass': _sizeClass,
        'category': _category,
        'weightKg': _weightKg,
        'lengthCm': double.tryParse(_lengthCtrl.text.trim()) ?? 30,
        'widthCm': double.tryParse(_widthCtrl.text.trim()) ?? 20,
        'heightCm': double.tryParse(_heightCtrl.text.trim()) ?? 15,
        'declaredValueBdt': double.tryParse(_declaredValCtrl.text.trim()) ?? 1000,
        if (note.isNotEmpty) 'handlingNote': note,
        'isProtected': _protected,
        'senderName': _senderName.text.trim(),
        'senderPhone': _senderPhone.text.trim(),
        'pickupAddress': '${_pickup['name']} (${_senderNote.text.trim()})',
        'pickupZoneId': _pickup['id'],
        'pickupLat': _pickup['lat'],
        'pickupLng': _pickup['lng'],
        'recipientName': _recipientName.text.trim(),
        'recipientPhone': _recipientPhone.text.trim(),
        'dropoffAddress': '${_dropoff['name']} (${_recipientNote.text.trim()})',
        'dropoffZoneId': _dropoff['id'],
        'dropoffLat': _dropoff['lat'],
        'dropoffLng': _dropoff['lng'],
        'codCollectBdt': double.tryParse(_codGoodsCtrl.text.trim()) ?? 0,
        'paymentMethod': _payment,
      });
      if (!mounted) return;
      showAutoDismissToast(context, 'Parcel dispatched! Tracking: ${res['shipment']['trackingCode']}');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ParcelTrackingScreen(parcelId: res['shipment']['id'] as String)),
      );
    } catch (e) {
      if (mounted) {
        showAutoDismissToast(context, 'Could not dispatch parcel: $e');
      }
    } finally {
      if (mounted) setState(() => _sendLoading = false);
    }
  }

  Future<void> _fetchIncoming() async {
    setState(() => _incomingLoading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/parcels/incoming');
      if (mounted) {
        setState(() {
          _incomingList = List<Map<String, dynamic>>.from(res['shipments'] as List? ?? []);
        });
      }
    } catch (_) {
      // transient network handling
    } finally {
      if (mounted) setState(() => _incomingLoading = false);
    }
  }

  Future<void> _searchByTrackingCode() async {
    final query = _trackingCodeCtrl.text.trim();
    if (query.isEmpty) {
      showAutoDismissToast(context, 'Please enter a tracking code');
      return;
    }
    setState(() => _trackSearching = true);
    try {
      final res = await ref.read(apiClientProvider).get('/parcels/track/$query');
      final s = res['shipment'] as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ParcelTrackingScreen(parcelId: s['id'] as String)),
      );
    } catch (e) {
      if (mounted) {
        showAutoDismissToast(context, 'No parcel found matching "$query"');
      }
    } finally {
      if (mounted) setState(() => _trackSearching = false);
    }
  }

  Future<void> _createSampleIncomingParcel() async {
    setState(() => _incomingLoading = true);
    try {
      final user = ref.read(authControllerProvider).user;
      final userPhone = (user?['phone'] as String?) ?? '+8801711111111';
      final userName = (user?['fullName'] as String?) ?? 'You (Recipient)';
      await ref.read(apiClientProvider).post('/parcels/book', body: {
        'tier': 'EXPRESS',
        'packageSizeClass': 'SMALL',
        'category': 'Electronics & Gadgets',
        'weightKg': 1.5,
        'lengthCm': 25,
        'widthCm': 20,
        'heightCm': 15,
        'declaredValueBdt': 2500,
        'handlingNote': 'Direct P2P delivery to doorstep. Please call before arrival.',
        'isProtected': true,
        'senderName': 'Tanvir Ahmed',
        'senderPhone': '+8801799887766',
        'pickupAddress': 'Road 11, Banani (House 42)',
        'pickupZoneId': 'zone-banani',
        'pickupLat': 23.7937,
        'pickupLng': 90.4066,
        'recipientName': userName,
        'recipientPhone': userPhone,
        'dropoffAddress': 'Road 13, Sector 7, Uttara (Apt 5B)',
        'dropoffZoneId': 'zone-uttara',
        'dropoffLat': 23.8726,
        'dropoffLng': 90.3983,
        'codCollectBdt': 1200,
        'paymentMethod': 'COD',
      });
      if (mounted) showAutoDismissToast(context, 'Sample incoming parcel dispatched!');
      await _fetchIncoming();
    } catch (e) {
      if (mounted) showAutoDismissToast(context, 'Could not create sample parcel: $e');
    } finally {
      if (mounted) setState(() => _incomingLoading = false);
    }
  }

  Future<void> _advanceDemoParcel(String parcelId) async {
    try {
      await ref.read(apiClientProvider).post('/common/demo/advance-parcel/$parcelId');
      if (mounted) showAutoDismissToast(context, 'Parcel stage updated!');
      await _fetchIncoming();
    } catch (e) {
      if (mounted) showAutoDismissToast(context, 'Stage advance failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _incomingList.where((p) => !['DELIVERED', 'CANCELLED'].contains(p['status'])).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('2Bee Parcel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: TwoBeeColors.primary, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                const Text('P2P Direct Courier · No Hub', style: TextStyle(fontSize: 11, color: TwoBeeColors.textSecondary, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: const [TwoBeeHomeAction()],
      ),
      body: Column(
        children: [
          // Section Tabs: Send Parcel vs Receive Parcel
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: TwoBeeColors.primary,
                  selectedForegroundColor: Colors.white,
                  side: const BorderSide(color: TwoBeeColors.borderSoft),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                segments: [
                  const ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.outbox_rounded, size: 18),
                    label: Text('Send Parcel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.move_to_inbox_rounded, size: 18),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Receive Parcel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        if (activeCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$activeCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                selected: {_activeTab},
                onSelectionChanged: (v) {
                  setState(() => _activeTab = v.first);
                  if (v.first == 1) _fetchIncoming();
                },
              ),
            ),
          ),
          Expanded(
            child: _activeTab == 0 ? _buildSendParcelView() : _buildReceiveParcelView(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SECTION 1: SEND PARCEL VIEW (P2P Direct Door-to-Door, No Hub)
  // =========================================================================
  Widget _buildSendParcelView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: [
        LinearProgressIndicator(
          value: (_sendStep + 1) / 3,
          color: TwoBeeColors.primary,
          backgroundColor: TwoBeeColors.surfaceTonal,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Text(
          'Step ${_sendStep + 1} of 3 · ${_sendStep == 0 ? '1. Sender & Recipient Addresses' : _sendStep == 1 ? '2. Package Specs & Speed' : '3. Route, Fare & Payment'}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TwoBeeColors.textSecondary),
        ),
        const SizedBox(height: 12),

        // Step 0: Addresses & Contacts
        if (_sendStep == 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: TwoBeeColors.surfaceTonal,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TwoBeeColors.borderSoft),
            ),
            child: const Row(
              children: [
                Icon(Icons.electric_moped_rounded, color: TwoBeeColors.primary, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Direct 1-on-1 Courier: EV Rider picks up from sender and delivers straight to recipient.',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: TwoBeeColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // SENDER PICKUP CARD
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: TwoBeeColors.borderSoft)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.trip_origin_rounded, color: TwoBeeColors.primary, size: 18),
                      SizedBox(width: 6),
                      Text('PICKUP FROM (SENDER)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6, color: TwoBeeColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _senderName, decoration: const InputDecoration(labelText: 'Sender Name', prefixIcon: Icon(Icons.person_outline, size: 20))),
                  const SizedBox(height: 8),
                  TextField(controller: _senderPhone, decoration: const InputDecoration(labelText: 'Sender Phone Number', prefixIcon: Icon(Icons.phone_outlined, size: 20))),
                  const SizedBox(height: 10),
                  const Text('Pickup Area / Zone', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    isExpanded: true,
                    initialValue: _pickup,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on_outlined, size: 20)),
                    items: _parcelZones.map((z) => DropdownMenuItem(value: z, child: Text(z['name'] as String))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _pickup = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: _senderNote, decoration: const InputDecoration(labelText: 'Pickup House / Flat / Note', hintText: 'e.g. Floor 3, Apt 3B')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // RECIPIENT DROPOFF CARD
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: TwoBeeColors.borderSoft)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: Colors.deepOrange, size: 18),
                      SizedBox(width: 6),
                      Text('DELIVER TO (RECIPIENT)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6, color: Colors.deepOrange)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _recipientName, decoration: const InputDecoration(labelText: 'Recipient Name', prefixIcon: Icon(Icons.person_outline, size: 20))),
                  const SizedBox(height: 8),
                  TextField(controller: _recipientPhone, decoration: const InputDecoration(labelText: 'Recipient Phone Number', prefixIcon: Icon(Icons.phone_outlined, size: 20))),
                  const SizedBox(height: 10),
                  const Text('Drop-off Area / Zone', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    isExpanded: true,
                    initialValue: _dropoff,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.pin_drop_outlined, size: 20)),
                    items: _parcelZones.map((z) => DropdownMenuItem(value: z, child: Text(z['name'] as String))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _dropoff = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: _recipientNote, decoration: const InputDecoration(labelText: 'Drop-off House / Landmark / Note', hintText: 'e.g. Direct doorstep delivery')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              if (_senderName.text.trim().isEmpty || _recipientName.text.trim().isEmpty) {
                showAutoDismissToast(context, 'Please enter sender and recipient names');
                return;
              }
              await _fetchEstimate();
              if (mounted) setState(() => _sendStep = 1);
            },
            child: const Text('Continue to Package Details ->'),
          ),
          const SizedBox(height: 20),
        ]

        // Step 1: Package Specs & Speed Tier
        else if (_sendStep == 1) ...[
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: TwoBeeColors.borderSoft)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Parcel Category', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      'Documents',
                      'Electronics & Gadgets',
                      'Clothing & Apparel',
                      'Food & Dry Goods',
                      'Fragile & Gifts',
                      'General Package',
                    ].map((c) => ChoiceChip(
                          label: Text(c, style: const TextStyle(fontSize: 12)),
                          selected: _category == c,
                          selectedColor: TwoBeeColors.primary,
                          labelStyle: TextStyle(color: _category == c ? Colors.white : TwoBeeColors.textPrimary, fontWeight: FontWeight.w600),
                          onSelected: (_) => setState(() => _category = c),
                        )).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Weight (kg)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => setState(() => _weightKg = (_weightKg - 0.5).clamp(0.5, 15.0)),
                            icon: const Icon(Icons.remove_circle_outline, color: TwoBeeColors.primary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: TwoBeeColors.surfaceTonal, borderRadius: BorderRadius.circular(8)),
                            child: Text('${_weightKg.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: TwoBeeColors.primary)),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _weightKg = (_weightKg + 0.5).clamp(0.5, 15.0)),
                            icon: const Icon(Icons.add_circle_outline, color: TwoBeeColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [0.5, 1.0, 2.0, 3.0, 5.0, 10.0].map((w) {
                      return ActionChip(
                        label: Text('${w.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 11)),
                        backgroundColor: _weightKg == w ? TwoBeeColors.surfaceTonalAlt : null,
                        onPressed: () => setState(() => _weightKg = w),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Package Size Class', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'DOC', label: Text('Doc')),
                      ButtonSegment(value: 'SMALL', label: Text('Small')),
                      ButtonSegment(value: 'MEDIUM', label: Text('Medium')),
                      ButtonSegment(value: 'LARGE', label: Text('Large')),
                    ],
                    selected: {_sizeClass},
                    onSelectionChanged: (v) {
                      final s = v.first;
                      setState(() {
                        _sizeClass = s;
                        if (s == 'DOC') {
                          _lengthCtrl.text = '30';
                          _widthCtrl.text = '22';
                          _heightCtrl.text = '5';
                        } else if (s == 'SMALL') {
                          _lengthCtrl.text = '25';
                          _widthCtrl.text = '20';
                          _heightCtrl.text = '15';
                        } else if (s == 'MEDIUM') {
                          _lengthCtrl.text = '35';
                          _widthCtrl.text = '25';
                          _heightCtrl.text = '20';
                        } else {
                          _lengthCtrl.text = '45';
                          _widthCtrl.text = '40';
                          _heightCtrl.text = '35';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _lengthCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'L (cm)'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: _widthCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'W (cm)'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: _heightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'H (cm)'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: _declaredValCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Declared Value (৳)')),
                  const SizedBox(height: 10),
                  TextField(controller: _handlingNoteCtrl, decoration: const InputDecoration(labelText: 'Handling Note (e.g. Fragile glass, keep upright)')),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('2Bee Parcel Transit Protection (+৳15)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: const Text('Covers accidental damage or transit loss up to ৳10,000', style: TextStyle(fontSize: 11)),
                    value: _protected,
                    onChanged: (v) => setState(() => _protected = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Delivery Speed Tier', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _tier,
            onChanged: (v) {
              if (v != null) setState(() => _tier = v);
            },
            child: Column(
              children: [
                ('EXPRESS', '⚡ Express Solo Direct (~30-45m)', 'Starts ৳110 · Dedicated EV rider rides straight from pickup to delivery'),
                ('NORMAL_ECO', '🌱 Standard Eco Courier (~1-3h)', 'Starts ৳60 · Cost-effective zero-emission EV courier'),
                ('NEXT_DAY', '📦 Next-Day Saver', 'Starts ৳45 · Scheduled next-day delivery'),
              ]
                  .map((item) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: _tier == item.$1 ? TwoBeeColors.surfaceTonal : TwoBeeColors.surfaceCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: _tier == item.$1 ? TwoBeeColors.primary : TwoBeeColors.borderSoft),
                        ),
                        child: RadioListTile<String>(
                          value: item.$1,
                          title: Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: Text(item.$3, style: const TextStyle(fontSize: 11)),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => setState(() => _sendStep = 0), child: const Text('Back'))),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await _fetchEstimate();
                    if (mounted) setState(() => _sendStep = 2);
                  },
                  child: const Text('Next: Fare & Review ->'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ]

        // Step 2: Review, Map, Breakdown & Payment
        else ...[
          TwoBeeMapPreview(
            pickupLat: (_pickup['lat'] as num).toDouble(),
            pickupLng: (_pickup['lng'] as num).toDouble(),
            dropoffLat: (_dropoff['lat'] as num).toDouble(),
            dropoffLng: (_dropoff['lng'] as num).toDouble(),
            height: 150,
          ),
          const SizedBox(height: 12),
          // Route & Handover Summary Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: TwoBeeColors.borderSoft)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('P2P ROUTE & CONTACT SUMMARY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: TwoBeeColors.primary)),
                  const SizedBox(height: 8),
                  Text('Pickup: ${_senderName.text} · ${_pickup['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text('Phone: ${_senderPhone.text}', style: const TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary)),
                  const Divider(height: 16),
                  Text('Delivery: ${_recipientName.text} · ${_dropoff['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text('Phone: ${_recipientPhone.text}', style: const TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _codGoodsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Collect Goods Value from Recipient (৳)',
                      hintText: '0 if sending a personal gift/prepaid item',
                      prefixIcon: Icon(Icons.payments_outlined, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Payment Selector
          PaymentSelectorCard(selectedMethod: _payment, onSelected: (m) => setState(() => _payment = m)),
          const SizedBox(height: 12),
          // Fare Breakdown Card
          Card(
            color: TwoBeeColors.surfaceTonal,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: TwoBeeColors.borderSoft)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FARE BREAKDOWN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: TwoBeeColors.primary)),
                  const SizedBox(height: 8),
                  _breakdownRow('Base Courier Charge', bdt((_estimate?['breakdown']?['baseFee'] as num?) ?? 60)),
                  _breakdownRow('Distance Charge (~${_estimate?['distanceKm'] ?? "8"} km)', bdt((_estimate?['breakdown']?['distanceFee'] as num?) ?? 45)),
                  _breakdownRow('Weight Charge ($_weightKg kg)', bdt((_estimate?['breakdown']?['weightFee'] as num?) ?? 10)),
                  if (_protected) _breakdownRow('Safe Transit Protection', '৳15'),
                  const Divider(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Delivery Fee', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      Text(bdt((_estimate?['breakdown']?['deliveryChargeBdt'] as num?) ?? 95), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: TwoBeeColors.primary)),
                    ],
                  ),
                  if ((double.tryParse(_codGoodsCtrl.text.trim()) ?? 0) > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'COD Goods Value to collect from receiver: ${bdt(double.tryParse(_codGoodsCtrl.text.trim()) ?? 0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.deepOrange),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Security Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: TwoBeeColors.warningBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: TwoBeeColors.warningBorder)),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: TwoBeeColors.warningText, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Handover Security: A unique 4-digit PIN will be assigned. Recipient must share this PIN with the EV rider to receive the parcel.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: TwoBeeColors.warningText),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => setState(() => _sendStep = 1), child: const Text('Back'))),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _sendLoading ? null : _submitBooking,
                  child: Text(_sendLoading
                      ? 'Requesting Courier...'
                      : 'Request Courier · ${bdt((_estimate?['breakdown']?['deliveryChargeBdt'] as num?) ?? 95)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _breakdownRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // =========================================================================
  // SECTION 2: RECEIVE PARCEL VIEW (Incoming P2P Packages for Client)
  // =========================================================================
  Widget _buildReceiveParcelView() {
    final activeShipments = _incomingList.where((p) => !['DELIVERED', 'CANCELLED'].contains(p['status'])).toList();
    final pastShipments = _incomingList.where((p) => ['DELIVERED', 'CANCELLED'].contains(p['status'])).toList();

    return RefreshIndicator(
      onRefresh: _fetchIncoming,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Quick Track by Code Search Bar
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: TwoBeeColors.borderSoft)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _trackingCodeCtrl,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Enter Tracking Code (e.g. 2B-PCL-1234)',
                        prefixIcon: Icon(Icons.qr_code_scanner_rounded, size: 20),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _searchByTrackingCode(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      minimumSize: Size.zero,
                    ),
                    onPressed: _trackSearching ? null : _searchByTrackingCode,
                    child: _trackSearching
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Track'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ACTIVE INCOMING SHIPMENTS SECTION
          if (_incomingLoading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (activeShipments.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Active Incoming Packages', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: _fetchIncoming,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...activeShipments.map((s) => _buildActiveIncomingCard(s)),
            const SizedBox(height: 14),
          ] else ...[
            // Friendly Empty State when no active incoming packages
            Card(
              color: TwoBeeColors.surfaceTonal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: TwoBeeColors.borderSoft)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.inbox_rounded, color: TwoBeeColors.primary, size: 30),
                    ),
                    const SizedBox(height: 12),
                    const Text('No Incoming Packages Right Now', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 6),
                    const Text(
                      'Any direct person-to-person delivery sent to your phone number will appear here automatically with live courier GPS and your 4-digit Delivery PIN.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_box_outlined, size: 18),
                      label: const Text('Dispatch Sample Incoming Package (Demo Test)'),
                      onPressed: _createSampleIncomingParcel,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // PAST DELIVERIES HISTORY SECTION
          if (pastShipments.isNotEmpty) ...[
            const Text('Past Deliveries Received', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 8),
            ...pastShipments.map((s) => _buildPastReceivedCard(s)),
          ],
        ],
      ),
    );
  }

  // Active Incoming Package Card (Features Delivery PIN prominently for handover!)
  Widget _buildActiveIncomingCard(Map<String, dynamic> s) {
    final courier = s['courier'] as Map?;
    final parcelId = s['id'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: TwoBeeColors.primarySoft, width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header & Tracking Chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: TwoBeeColors.primary, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s['statusBanner']?.toString() ?? 'Courier Heading to You',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: TwoBeeColors.primary),
                    ),
                  ],
                ),
                ActionChip(
                  avatar: const Icon(Icons.copy_rounded, size: 13),
                  label: Text(s['trackingCode'].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                  onPressed: () {
                    showAutoDismissToast(context, 'Tracking Code ${s['trackingCode']} copied!');
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Sender & Destination Details
            Text('From: ${s['senderName']} (${s['pickupAddress']})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 3),
            Text('To You: ${s['dropoffAddress']}', style: const TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary)),
            const SizedBox(height: 6),
            Text('Package: ${s['category']} · ${s['weightKg']} kg', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),

            // Payment Due at Doorstep
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: TwoBeeColors.surfaceTonal, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment at Doorstep:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(
                    (s['codCollectBdt'] as num) > 0
                        ? 'Cash Due: ${bdt(s['codCollectBdt'] as num)}'
                        : 'Prepaid · ৳0 to pay',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: (s['codCollectBdt'] as num) > 0 ? Colors.deepOrange : TwoBeeColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // PROMINENT DELIVERY VERIFICATION PIN TILE
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TwoBeeColors.warningBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TwoBeeColors.warningBorder, width: 1.5),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.key_rounded, color: TwoBeeColors.warningText, size: 18),
                      SizedBox(width: 6),
                      Text('YOUR DELIVERY VERIFICATION PIN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.8, color: TwoBeeColors.warningText)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  PinDigitsRow(pin: s['deliveryPin'].toString()),
                  const SizedBox(height: 6),
                  const Text(
                    '⚠️ Share this 4-digit PIN with the EV courier when they reach your doorstep to verify and release your package.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: TwoBeeColors.warningText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Assigned Courier Info (if assigned)
            if (courier != null) ...[
              Card(
                color: TwoBeeColors.surfaceCard,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: TwoBeeColors.borderSoft)),
                child: ListTile(
                  dense: true,
                  leading: const CircleAvatar(
                    backgroundColor: TwoBeeColors.surfaceTonal,
                    child: Icon(Icons.electric_moped_rounded, color: TwoBeeColors.primary, size: 20),
                  ),
                  title: Text('${courier['name']} · ★${courier['rating']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text('${courier['vehicle'] ?? "Glafit GFR-02"} · ${courier['plateNo'] ?? "DHK-HA-8821"}', style: const TextStyle(fontSize: 11)),
                  trailing: IconButton(
                    icon: const Icon(Icons.chat_outlined, color: TwoBeeColors.primary),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InAppChatScreen(
                          serviceType: 'PARCEL',
                          orderId: parcelId,
                          peerTitle: courier['name'] as String,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Track Live Courier'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ParcelTrackingScreen(parcelId: parcelId)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _advanceDemoParcel(parcelId),
                  child: const Text('⚡ Advance Stage'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Past Delivered Parcel History Card
  Widget _buildPastReceivedCard(Map<String, dynamic> s) {
    final parcelId = s['id'] as String;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: TwoBeeColors.borderSoft)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: TwoBeeColors.surfaceTonal,
          child: Icon(Icons.check_circle_outline_rounded, color: TwoBeeColors.primary),
        ),
        title: Text('${s['trackingCode']} · Delivered', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        subtitle: Text('From: ${s['senderName']} · ${s['category']}', style: const TextStyle(fontSize: 11)),
        trailing: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ParcelTrackingScreen(parcelId: parcelId)),
          ),
          child: const Text('View'),
        ),
      ),
    );
  }
}

/// Parcel 4: Active Shipment & Tracking Screen (Supports both Sender & Receiver views)
class ParcelTrackingScreen extends ConsumerStatefulWidget {
  final String parcelId;
  const ParcelTrackingScreen({super.key, required this.parcelId});

  @override
  ConsumerState<ParcelTrackingScreen> createState() => _ParcelTrackingScreenState();
}

class _ParcelTrackingScreenState extends ConsumerState<ParcelTrackingScreen> {
  Map<String, dynamic>? _shipment;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
    final sock = ref.read(socketServiceProvider);
    sock.joinTracking('parcel', widget.parcelId);
    sock.socket?.off('parcel:status');
    sock.socket?.on('parcel:status', (_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/parcels/${widget.parcelId}');
      setState(() => _shipment = Map<String, dynamic>.from(res['shipment'] as Map));
    } catch (_) {
      // transient
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _advanceDemo() async {
    await ref.read(apiClientProvider).post('/common/demo/advance-parcel/${widget.parcelId}');
    await _load();
  }

  Future<void> _confirmCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Shipment & Refund'),
        content: const Text('Are you sure you want to cancel this parcel? Online charges (if paid) will be refunded automatically.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Parcel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TwoBeeColors.errorText),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(apiClientProvider).post('/parcels/${widget.parcelId}/cancel');
      _load();
    }
  }

  Future<void> _rateParcel() async {
    if (_shipment == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ParcelDeliveredRatingScreen(shipment: _shipment!)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _shipment == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final s = _shipment!;
    final courier = s['courier'] as Map?;

    final user = ref.watch(authControllerProvider).user;
    final userPhone = (user?['phone'] as String?)?.replaceAll(RegExp(r'\D'), '') ?? '';
    final recipientPhone = (s['recipientPhone'] as String?)?.replaceAll(RegExp(r'\D'), '') ?? '';
    final isRecipient = userPhone.isNotEmpty && recipientPhone.isNotEmpty && (userPhone == recipientPhone || userPhone.endsWith(recipientPhone) || recipientPhone.endsWith(userPhone));

    return Scaffold(
      appBar: AppBar(
        title: Text(isRecipient ? 'Incoming Parcel ${s['trackingCode']}' : 'Parcel ${s['trackingCode']}'),
        actions: const [TwoBeeHomeAction()],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status and PIN Card
            Card(
              color: TwoBeeColors.surfaceTonal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: TwoBeeColors.borderSoft)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          s['statusBanner']?.toString() ?? 'Courier En-Route',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: TwoBeeColors.primary),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.copy_rounded, size: 14),
                          label: Text(s['trackingCode'].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                          onPressed: () {
                            showAutoDismissToast(context, 'Tracking code ${s['trackingCode']} copied!');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${s['pickupAddress']} → ${s['dropoffAddress']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 14),

                    // Delivery Verification PIN
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TwoBeeColors.borderSoft),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('DELIVERY SECURITY PIN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.7)),
                              Text(
                                isRecipient ? 'Share with courier upon delivery' : 'Recipient provides to courier',
                                style: const TextStyle(fontSize: 10, color: TwoBeeColors.textSecondary),
                              ),
                            ],
                          ),
                          PinDigitsRow(pin: s['deliveryPin'].toString()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Transit Milestones
                    const Text('TRANSIT MILESTONES (DIRECT P2P)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.7, color: TwoBeeColors.textSecondary)),
                    const SizedBox(height: 6),
                    _milestoneRow('1. Booked & Dispatched', true),
                    _milestoneRow('2. Dedicated Courier Assigned', ['RIDER_ASSIGNED', 'PICKED_UP', 'IN_TRANSIT', 'DELIVERED'].contains(s['status'])),
                    _milestoneRow('3. Picked Up & In Direct Transit', ['PICKED_UP', 'IN_TRANSIT', 'DELIVERED'].contains(s['status'])),
                    _milestoneRow('4. Delivered via 4-Digit PIN Handover', s['status'] == 'DELIVERED'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Courier Card (if assigned)
            if (courier != null) ...[
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: TwoBeeColors.borderSoft)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: TwoBeeColors.surfaceTonal,
                    child: Icon(Icons.electric_moped_rounded, color: TwoBeeColors.primary),
                  ),
                  title: Text('${courier['name']} · ★${courier['rating']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${courier['vehicle'] ?? "Glafit GFR-02"} · ${courier['plateNo'] ?? "DHK-HA-8821"}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.chat_outlined, color: TwoBeeColors.primary),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InAppChatScreen(
                          serviceType: 'PARCEL',
                          orderId: widget.parcelId,
                          peerTitle: courier['name'] as String,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Shipment Details Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: TwoBeeColors.borderSoft)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Package: ${s['category']} (${s['weightKg']} kg)', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Delivery Fee: ${bdt(s['deliveryChargeBdt'] as num)} (${s['paymentMethod']})'),
                    if ((s['codCollectBdt'] as num) > 0)
                      Text(
                        'COD Goods Value: ${bdt(s['codCollectBdt'] as num)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.deepOrange),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showWaybillDialog(s),
                            icon: const Icon(Icons.description_outlined, size: 18),
                            label: const Text('Waybill'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              showAutoDismissToast(context, 'Tracking link copied: https://2bee.app/track/${s['trackingCode']}');
                            },
                            icon: const Icon(Icons.share_outlined, size: 18),
                            label: const Text('Share Link'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (['BOOKED', 'MATCHING', 'RIDER_ASSIGNED', 'PICKED_UP', 'IN_TRANSIT'].contains(s['status'])) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: TwoBeeColors.obsidian),
                onPressed: _advanceDemo,
                icon: const Icon(Icons.fast_forward_rounded),
                label: const Text('Preview: Simulate Next Parcel Stage ->'),
              ),
            ],
            if (['BOOKED', 'MATCHING', 'RIDER_ASSIGNED'].contains(s['status'])) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _confirmCancel,
                child: const Text('Cancel Shipment & Refund'),
              ),
            ],
            if (s['status'] == 'DELIVERED') ...[
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _rateParcel,
                child: Text(s['rating'] == null ? 'Rate Courier & View Receipt ->' : 'View Delivery Receipt & Rating'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _milestoneRow(String title, bool isDone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isDone ? TwoBeeColors.primary : TwoBeeColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
              color: isDone ? TwoBeeColors.textPrimary : TwoBeeColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showWaybillDialog(Map<String, dynamic> s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Waybill · ${s['trackingCode']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${s['senderName']} (${s['pickupAddress']})'),
            const SizedBox(height: 4),
            Text('To: ${s['recipientName']} (${s['dropoffAddress']})'),
            const Divider(),
            Text('Tier: ${s['tier']} · Weight: ${s['weightKg']} kg'),
            Text('Delivery Fee: ${bdt(s['deliveryChargeBdt'] as num)}'),
            if ((s['codCollectBdt'] as num) > 0) Text('COD Goods: ${bdt(s['codCollectBdt'] as num)}'),
            Text('Security PIN: ${s['deliveryPin']}'),
            const SizedBox(height: 6),
            const Text('Zero-Hub Direct Doorstep Courier Delivery', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}

class ParcelDeliveredRatingScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> shipment;
  const ParcelDeliveredRatingScreen({super.key, required this.shipment});

  @override
  ConsumerState<ParcelDeliveredRatingScreen> createState() => _ParcelDeliveredRatingScreenState();
}

class _ParcelDeliveredRatingScreenState extends ConsumerState<ParcelDeliveredRatingScreen> {
  int _stars = 5;
  final _tags = <String>{'Fast Delivery', 'Package Intact'};
  final _commentCtrl = TextEditingController();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.shipment;
    final alreadyRated = s['rating'] != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Parcel Delivered & Receipt'), actions: const [TwoBeeHomeAction()]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
            radius: 36,
            backgroundColor: TwoBeeColors.surfaceTonal,
            child: Icon(Icons.verified_rounded, color: TwoBeeColors.primary, size: 40),
          ),
          const SizedBox(height: 12),
          Text('Shipment ${s['trackingCode']} Delivered!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Direct P2P Handover Confirmed via PIN', textAlign: TextAlign.center, style: const TextStyle(color: TwoBeeColors.textSecondary)),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: TwoBeeColors.borderSoft)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Parcel Summary & Receipt', style: TextStyle(fontWeight: FontWeight.w800)),
                  const Divider(),
                  Text('Route: ${s['pickupAddress']} -> ${s['dropoffAddress']}'),
                  Text('Package: ${s['category']} (${s['weightKg']} kg · ${s['tier']})'),
                  Text('Delivery Charge: ${bdt(s['deliveryChargeBdt'] as num)} (${s['paymentMethod']})'),
                  if ((s['codCollectBdt'] as num) > 0) Text('COD Collected: ${bdt(s['codCollectBdt'] as num)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!alreadyRated) ...[
            const Text('Rate Your Courier Experience', style: TextStyle(fontWeight: FontWeight.w800)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => IconButton(
                  iconSize: 34,
                  onPressed: () => setState(() => _stars = i + 1),
                  icon: Icon(i < _stars ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber),
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Fast Delivery', 'Package Intact', 'Polite Rider', 'On-Time PIN Handover'].map((t) {
                final sel = _tags.contains(t);
                return FilterChip(
                  label: Text(t),
                  selected: sel,
                  onSelected: (v) => setState(() => v ? _tags.add(t) : _tags.remove(t)),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(controller: _commentCtrl, decoration: const InputDecoration(labelText: 'Feedback Note (optional)')),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      await ref.read(apiClientProvider).post('/parcels/${s['id']}/rate', body: {
                        'rating': _stars,
                        'comment': '${_tags.join(", ")} ${_commentCtrl.text.trim()}'.trim(),
                      });
                      if (context.mounted) Navigator.pop(context);
                    },
              child: Text(_saving ? 'Submitting...' : 'Submit Rating & Done'),
            ),
          ] else
            Card(
              color: TwoBeeColors.surfaceTonal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: TwoBeeColors.borderSoft)),
              child: ListTile(
                leading: const Icon(Icons.star_rounded, color: Colors.amber),
                title: Text('Rated ${s['rating']}/5 Stars'),
                subtitle: Text(s['ratingComment']?.toString() ?? 'Thank you for your feedback!'),
              ),
            ),
        ],
      ),
    );
  }
}
