import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/twobee_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../client/client_food_screens.dart';
import '../client/client_parcel_screens.dart';
import '../client/client_ride_screens.dart';
import '../client/client_shell.dart';
import '../merchant/merchant_auth_kyc.dart';
import '../merchant/merchant_shell_panels.dart';
import '../rider/rider_shell_multiservice.dart';
import 'shared_screens.dart';

/// Complete 2Bee Flows & Screens Explorer: lets testers walk through every step naturally
/// OR open any individual screen across Client, Rider, and Split Merchant (Physical / Home Kitchen).
class AllScreensExplorerScreen extends ConsumerStatefulWidget {
  const AllScreensExplorerScreen({super.key});

  @override
  ConsumerState<AllScreensExplorerScreen> createState() => _AllScreensExplorerScreenState();
}

class _AllScreensExplorerScreenState extends ConsumerState<AllScreensExplorerScreen> {
  bool _busy = false;

  Future<void> _demoQuickLogin({
    required String phone,
    String role = 'CLIENT',
    String? pin,
    String? targetRoute,
  }) async {
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      final req = await api.post('/auth/otp/request', body: {'phone': phone, 'purpose': 'LOGIN'});
      final ver = await api.post('/auth/otp/verify', body: {
        'phone': req['phone'],
        'code': req['devOtpHint'] ?? '123456',
        'purpose': 'LOGIN',
      });
      await ref.read(authControllerProvider.notifier).applyOtpLogin(ver);
      await ref.read(authControllerProvider.notifier).switchRole(role);
      if (role == 'RIDER' && pin != null) {
        final r = await api.post('/rider/login-pin', body: {'passcode': pin});
        ref.read(authControllerProvider.notifier).setRiderToken(r['roleToken'] as String);
      } else if (role == 'MERCHANT' && pin != null) {
        final m = await api.post('/merchant/login-pin', body: {'passcode': pin});
        ref.read(authControllerProvider.notifier).setMerchantToken(m['roleToken'] as String);
      }
      if (!mounted) return;
      if (targetRoute != null) {
        context.go(targetRoute);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static final _sampleParcel = <String, dynamic>{
    'id': 'sample-parcel',
    'trackingCode': '2B-P8421',
    'pickupAddress': 'Road 11, Banani',
    'dropoffAddress': 'Road 13, Sector 7, Uttara',
    'recipientName': 'Farhana Yasmin',
    'category': 'Documents',
    'tier': 'NORMAL_ECO',
    'weightKg': 2.0,
    'deliveryChargeBdt': 95,
    'riderPayoutBdt': 80,
    'codCollectBdt': 500,
    'paymentMethod': 'COD',
    'deliveryPin': '4821',
    'status': 'DELIVERED',
  };

  static final _sampleRide = <String, dynamic>{
    'id': 'sample-ride',
    'tripCode': '2B-R7391',
    'pickupAddress': 'Banani Road 11',
    'dropoffAddress': 'Uttara Sector 7',
    'fleetTier': '2BEE_EV_SOLO',
    'distanceKm': 9.2,
    'totalFareBdt': 165,
    'riderPayoutBdt': 135,
    'startPin': '7391',
    'paymentMethod': 'COD',
    'user': {'fullName': 'Tanvir Ahmed'},
    'status': 'COMPLETED',
  };

  static final _sampleBatch = <String, dynamic>{
    'id': 'sample-batch',
    'batchCode': 'MULTI-2B99',
    'originZoneId': 'zone-banani',
    'destinationZoneId': 'zone-uttara',
    'status': 'PASSENGER_PICKUP_PENDING',
    'totalPayoutBdt': 215,
    'rideTrip': _sampleRide,
    'parcelShipment': _sampleParcel,
  };

  static final _sampleFoodOrder = <String, dynamic>{
    'id': 'sample-food',
    'orderCode': '2B-F1042',
    'status': 'DELIVERED',
    'totalBdt': 540,
    'deliveryAddress': 'House 42, Road 11, Banani',
    'paymentMethod': 'STRIPE_SANDBOX',
    'merchant': {'businessName': "Sultan's Dine Banani"},
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All 2Bee Screens & Flows'), actions: const [TwoBeeHomeAction()]),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: TwoBeeColors.obsidian,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('1-TAP LIVE DEMO ACCOUNT JUMP', style: TextStyle(color: TwoBeeColors.primarySoft, fontWeight: FontWeight.w800, fontSize: 12)),
                      const SizedBox(height: 6),
                      const Text('Jump straight into any active role with real seeded backend data:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(minimumSize: const Size(120, 36)),
                            onPressed: _busy ? null : () => _demoQuickLogin(phone: '+8801711111111', role: 'CLIENT', targetRoute: '/client'),
                            child: const Text('Client App'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(minimumSize: const Size(120, 36)),
                            onPressed: _busy ? null : () => _demoQuickLogin(phone: '+8801712345678', role: 'RIDER', pin: '2580', targetRoute: '/rider/panel'),
                            child: const Text('Rider Panel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(minimumSize: const Size(120, 36)),
                            onPressed: _busy ? null : () => _demoQuickLogin(phone: '+8801722222222', role: 'MERCHANT', pin: '258096', targetRoute: '/merchant/panel'),
                            child: const Text("Restaurant (Sultan's)"),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(minimumSize: const Size(120, 36)),
                            onPressed: _busy ? null : () => _demoQuickLogin(phone: '+8801733333333', role: 'MERCHANT', pin: '147852', targetRoute: '/merchant/panel'),
                            child: const Text("Home Kitchen (Rina's)"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _SectionGroup(
                title: '01 · Entry, Auth & Role Switching',
                items: [
                  ('Splash Screen (V1.0)', () => context.go('/splash')),
                  ('Onboarding Slides (1/3, 2/3, 3/3)', () => context.go('/onboarding')),
                  ('Login (Phone-OTP Only)', () => context.go('/login')),
                  ('Role Selection (Client / Rider / Merchant)', () => context.go('/roles')),
                ],
              ),
              _SectionGroup(
                title: '02 · Client Home, Food, Parcel & Ride',
                items: [
                  ('Client 4-Tab Home Shell', () => context.go('/client')),
                  ('Food Delivery Mobile', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodHomeScreen()))),
                  ('Search & Filter', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodSearchScreen()))),
                  ('Favorites (Restaurants & Dishes)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()))),
                  ('Cart Screen', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()))),
                  ('Checkout (COD / Stripe / MFS Preview)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()))),
                  ('Order Placed (Preview)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => FoodOrderPlacedScreen(order: _sampleFoodOrder)))),
                  ('Food Delivered & Dual Rating (Preview)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => FoodDeliveredRatingScreen(order: _sampleFoodOrder)))),
                  ('Parcel 1–3: Hub, Specs & Pay Wizard', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParcelHubScreen()))),
                  ('Parcel Delivered Rating & Receipt (Preview)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => ParcelDeliveredRatingScreen(shipment: _sampleParcel)))),
                  ('Ride 1: Map Radar & Location Selector', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RideLocationScreen()))),
                  ('Ride 2: Choose EV Bike Tier (Preview)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideTierScreen(
                        pickup: const {'name': 'Banani Road 11', 'lat': 23.7937, 'lng': 90.4066, 'id': 'zone-banani'},
                        dropoff: const {'name': 'Uttara Sector 3', 'lat': 23.8648, 'lng': 90.3974, 'id': 'zone-uttara'},
                        estimate: const {
                          'ok': true,
                          'distanceKm': 10.4,
                          'etaMins': 12,
                          'tiers': [
                            {
                              'id': '2BEE_EV_SOLO',
                              'name': '2Bee EV Solo Bike',
                              'subtitle': 'Glafit GFR-02 EV · Solo Commute',
                              'totalFareBdt': 185,
                              'etaMins': 12,
                            },
                            {
                              'id': '2BEE_EV_EXPRESS',
                              'name': '2Bee EV Express Bike',
                              'subtitle': 'Glafit LOM Priority · Instant Dispatch',
                              'totalFareBdt': 235,
                              'etaMins': 13,
                            },
                          ],
                        },
                      )))),
                  ('Ride 3: Rider Matching Radar (Preview)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RideMatchingRadarScreen(tripId: 'sample-ride')))),
                  ('Ride 4: Active Trip & Driver En-Route (Preview)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RideActiveTripScreen(tripId: 'sample-ride')))),
                  ('Ride 5: Trip Completion & Rating (Preview)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideCompletionRatingScreen(trip: _sampleRide)))),
                  ('Edit Client Profile', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditClientProfileScreen()))),
                  ('Saved Addresses', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAddressesScreen()))),
                ],
              ),
              _SectionGroup(
                title: '03 · Merchant Registration & Post-Approval 6-Digit Auth',
                items: [
                  ('Store Type (Physical vs Home Kitchen)', () => context.push('/merchant/type')),
                  ('Physical Restaurant 6-Step Reg', () => context.push('/merchant/register/PHYSICAL')),
                  ('Home Kitchen 6-Step Reg', () => context.push('/merchant/register/HOME_KITCHEN')),
                  ('Verification Pending (Checklist)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantVerificationPendingScreen(businessName: 'New 2Bee Kitchen', merchantType: 'HOME_KITCHEN')))),
                  ('Merchant Home Pending (Locked Closed)', () => context.push('/merchant/pending')),
                  ('Merchant Needs Changes', () => context.push('/merchant/needs-changes')),
                  ('Post-Approval OTP -> Create 6-Digit PIN', () => context.push('/merchant/post-approval-pin')),
                  ('Fingerprint & Biometric Setup', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantFingerprintSetupScreen()))),
                  ('Merchant 6-Digit Passcode Login', () => context.push('/merchant/passcode')),
                  ('Forgot Passcode (OTP + NID Last 4)', () => context.push('/merchant/forgot-passcode')),
                ],
              ),
              _SectionGroup(
                title: '04 · Split Merchant Panel (Physical & Home Kitchen)',
                items: [
                  ('Merchant 4-Tab Panel (Home | Orders | Wallet | Store)', () => context.go('/merchant/panel')),
                  ('Menu Manager', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantMenuScreen()))),
                  ('Add / Edit Dish Screen', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddOrEditMenuItemScreen()))),
                  ('Payout Statement (Sample View)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantPayoutStatementScreen(summary: {'grossSalesBdt': 12500, 'commissionBdt': 1875, 'netEarningsBdt': 10625, 'commissionRatePct': 15, 'payoutSchedule': 'Weekly Friday'}, transactions: [])))),
                  ('Promotions & Offers', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantPromotionsScreen()))),
                  ('Customer Reviews', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantReviewsScreen()))),
                  ('Staff Accounts & Home Kitchen Settings', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantStaffAndSettingsScreen(isHomeKitchen: true)))),
                  ('Merchant Security (6-Digit PIN & 48h Hold)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantSecurityScreen()))),
                ],
              ),
              _SectionGroup(
                title: '05 · Rider KYC (A1–A10 + Review) & Operations',
                items: [
                  ('Rider 9-Step KYC (A1–A10 + 4-Digit PIN + Review)', () => context.push('/rider/register')),
                  ('Rider Enter 4-Digit Passcode', () => context.push('/rider/passcode')),
                  ('Rider Forgot Passcode (OTP + NID Last 4)', () => context.push('/rider/forgot-passcode')),
                  ('Rider 4-Tab Panel (Home | Jobs | Wallet | Profile)', () => context.go('/rider/panel')),
                  ('Looking for Requests (Radar & 15s Offer Sheets)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LookingForRequestsScreen()))),
                  ('Carrying Setup (Multi-Service Mode)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CarryingSetupScreen()))),
                  ('Multi-Service Unavailable Explanation', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MultiServiceUnavailableScreen(reason: 'Express parcels, Food orders & Ride-first trips never support co-ride batching.')))),
                  ('Bike Rental Home (Glafit / 2Bee EV)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BikeRentalHomeScreen()))),
                  ('Rider Security (4-Digit PIN & 48h Hold)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderSecurityScreen()))),
                ],
              ),
              _SectionGroup(
                title: '06 · Rider Multi-Service Step-by-Step Screens (Preview)',
                items: [
                  ('Passenger Pickup (Multi-Service Step 1)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => PassengerPickupScreen(batch: _sampleBatch)))),
                  ('Multi-Service Live (Stop 1 Pax -> Stop 2 Parcel)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => MultiServiceLiveScreen(batch: _sampleBatch)))),
                  ('Passenger Dropoff & Fare Collection', () => Navigator.push(context, MaterialPageRoute(builder: (_) => PassengerDropoffScreen(batch: _sampleBatch)))),
                  ('Final Parcel Delivery (Stop 2 OTP & POD)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => FinalParcelDeliveryScreen(batch: _sampleBatch)))),
                  ('Batch Completion Summary', () => Navigator.push(context, MaterialPageRoute(builder: (_) => BatchCompletionSummaryScreen(batch: _sampleBatch)))),
                  ('Rider Service Detail (Exclusive Dual Legs)', () => Navigator.push(context, MaterialPageRoute(builder: (_) => RiderServiceDetailScreen(serviceType: 'MULTI', title: 'Service Detail · MULTI-2B99', data: _sampleBatch)))),
                ],
              ),
              _SectionGroup(
                title: '07 · Shared Safety, Notifications & Legal',
                items: [
                  ('Notifications Center', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
                  ('Emergency SOS Safety Sheet', () => showSosSafetySheet(context, ref, role: 'CLIENT')),
                  ('Help & Support Center', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportLegalScreen()))),
                  ('Terms of Service', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsAndPrivacyScreen(initialTab: 0)))),
                  ('Privacy Policy', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsAndPrivacyScreen(initialTab: 1)))),
                ],
              ),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black38,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _SectionGroup extends StatelessWidget {
  final String title;
  final List<(String, VoidCallback)> items;
  const _SectionGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: title.startsWith('01') || title.startsWith('06'),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        children: [
          for (final item in items)
            ListTile(
              dense: true,
              title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: TwoBeeColors.primary),
              onTap: item.$2,
            ),
        ],
      ),
    );
  }
}

