import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Waypoints representing the shortest road corridor in Banani for food delivery:
/// Sultan's Dine (Road 11) ➔ Kamal Ataturk Ave ➔ Block D ➔ House 42, Road 11
const List<LatLng> kBananiFoodShortestRoute = [
  LatLng(23.7942, 90.4071), // Sultan's Dine Banani, Road 11 (Store)
  LatLng(23.7938, 90.4061), // West on Road 11
  LatLng(23.7932, 90.4052), // Turn South towards Kamal Ataturk Ave
  LatLng(23.7924, 90.4043), // Kamal Ataturk intersection
  LatLng(23.7915, 90.4052), // Turn East onto Block D Road 11
  LatLng(23.7908, 90.4068), // Destination: House 42, Road 11 (Customer Doorstep)
];

const List<String> kRouteInstructions = [
  'Head West on Banani Road 11 towards Block C',
  'Continue straight 120m towards Kamal Ataturk Ave',
  'Turn Left onto Kamal Ataturk Ave (Shortest Road Corridor)',
  'In 200m, Turn Left onto Block D Road 11',
  'Arriving at Customer Doorstep: House 42, Road 11',
  'Arrived! Hand over meal to customer with 4-digit PIN',
];

class FoodOrderLiveState {
  final String orderId;
  final String orderCode;
  final String status; // 'PLACED', 'PREPARING', 'READY_FOR_PICKUP', 'PICKED_UP', 'DELIVERED'
  final int prepTimeMins;
  final int prepSecondsRemaining;
  final double riderProgress; // 0.0 at restaurant to 1.0 at doorstep
  final bool isSimulating;
  final String restaurantName;
  final String restaurantAddress;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String deliveryPin;
  final String riderName;
  final String riderPhone;
  final String riderVehicle;
  final num totalBdt;
  final num subtotalBdt;
  final num riderPayoutBdt;
  final String paymentMethod;
  final List<Map<String, dynamic>> items;

  const FoodOrderLiveState({
    required this.orderId,
    required this.orderCode,
    required this.status,
    required this.prepTimeMins,
    required this.prepSecondsRemaining,
    required this.riderProgress,
    required this.isSimulating,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.deliveryPin,
    required this.riderName,
    required this.riderPhone,
    required this.riderVehicle,
    required this.totalBdt,
    required this.subtotalBdt,
    required this.riderPayoutBdt,
    required this.paymentMethod,
    required this.items,
  });

  LatLng get riderPosition {
    if (kBananiFoodShortestRoute.isEmpty) return const LatLng(23.7942, 90.4071);
    final count = kBananiFoodShortestRoute.length - 1;
    final scaled = (riderProgress.clamp(0.0, 1.0)) * count;
    final index = scaled.floor().clamp(0, count - 1);
    final fraction = scaled - index;

    final p1 = kBananiFoodShortestRoute[index];
    final p2 = kBananiFoodShortestRoute[index + 1];
    final lat = p1.latitude + (p2.latitude - p1.latitude) * fraction;
    final lng = p1.longitude + (p2.longitude - p1.longitude) * fraction;
    return LatLng(lat, lng);
  }

  String get currentTurnInstruction {
    final count = kRouteInstructions.length;
    final index = ((riderProgress.clamp(0.0, 1.0)) * (count - 1)).floor().clamp(0, count - 1);
    return kRouteInstructions[index];
  }

  String get distanceRemainingFormatted {
    final totalDistKm = 1.8;
    final rem = totalDistKm * (1.0 - riderProgress.clamp(0.0, 1.0));
    if (rem <= 0.05) return 'Arrived at Doorstep';
    return '${rem.toStringAsFixed(1)} km · ${(rem * 3.5).ceil().clamp(1, 15)} mins remaining';
  }

  String get formattedPrepTimer {
    if (prepSecondsRemaining <= 0) return '00:00';
    final m = (prepSecondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (prepSecondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  FoodOrderLiveState copyWith({
    String? orderId,
    String? orderCode,
    String? status,
    int? prepTimeMins,
    int? prepSecondsRemaining,
    double? riderProgress,
    bool? isSimulating,
    String? restaurantName,
    String? restaurantAddress,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    String? deliveryPin,
    String? riderName,
    String? riderPhone,
    String? riderVehicle,
    num? totalBdt,
    num? subtotalBdt,
    num? riderPayoutBdt,
    String? paymentMethod,
    List<Map<String, dynamic>>? items,
  }) {
    return FoodOrderLiveState(
      orderId: orderId ?? this.orderId,
      orderCode: orderCode ?? this.orderCode,
      status: status ?? this.status,
      prepTimeMins: prepTimeMins ?? this.prepTimeMins,
      prepSecondsRemaining: prepSecondsRemaining ?? this.prepSecondsRemaining,
      riderProgress: riderProgress ?? this.riderProgress,
      isSimulating: isSimulating ?? this.isSimulating,
      restaurantName: restaurantName ?? this.restaurantName,
      restaurantAddress: restaurantAddress ?? this.restaurantAddress,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryPin: deliveryPin ?? this.deliveryPin,
      riderName: riderName ?? this.riderName,
      riderPhone: riderPhone ?? this.riderPhone,
      riderVehicle: riderVehicle ?? this.riderVehicle,
      totalBdt: totalBdt ?? this.totalBdt,
      subtotalBdt: subtotalBdt ?? this.subtotalBdt,
      riderPayoutBdt: riderPayoutBdt ?? this.riderPayoutBdt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      items: items ?? this.items,
    );
  }
}

class FoodOrderSyncNotifier extends StateNotifier<FoodOrderLiveState> {
  Timer? _countdownTimer;
  Timer? _simulationTimer;

  FoodOrderSyncNotifier()
      : super(
          const FoodOrderLiveState(
            orderId: 'ord-live-1',
            orderCode: '2B-F1042',
            status: 'PLACED',
            prepTimeMins: 20,
            prepSecondsRemaining: 20 * 60,
            riderProgress: 0.0,
            isSimulating: false,
            restaurantName: "Sultan's Dine Banani",
            restaurantAddress: 'House 42, Road 11, Banani Block D',
            customerName: 'Tanvir Ahmed',
            customerPhone: '+880 1711-223344',
            deliveryAddress: 'House 42, Road 11, Banani (Apt 3B)',
            deliveryPin: '4821',
            riderName: 'Shakil Hasan (Glafit EV)',
            riderPhone: '+880 1733-333333',
            riderVehicle: 'Glafit GFR-02 EV Bike',
            totalBdt: 620,
            subtotalBdt: 540,
            riderPayoutBdt: 95,
            paymentMethod: 'COD',
            items: [
              {'name': 'Kacchi Biryani (Full)', 'qty': 1, 'price': 480},
              {'name': 'Special Borhani (500ml)', 'qty': 1, 'price': 140},
            ],
          ),
        );

  /// Merchant accepts new order with prep time (starts live preparation countdown)
  void acceptOrder({int prepMins = 20}) {
    _countdownTimer?.cancel();
    state = state.copyWith(
      status: 'PREPARING',
      prepTimeMins: prepMins,
      prepSecondsRemaining: prepMins * 60,
      riderProgress: 0.0,
      isSimulating: false,
    );

    // Start 1-second countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.prepSecondsRemaining > 0) {
        state = state.copyWith(prepSecondsRemaining: state.prepSecondsRemaining - 1);
      } else {
        timer.cancel();
      }
    });
  }

  /// Add extra minutes to prep countdown if kitchen is busy
  void addPrepTime(int extraMins) {
    state = state.copyWith(
      prepSecondsRemaining: state.prepSecondsRemaining + (extraMins * 60),
    );
  }

  /// Merchant marks food handed over to rider! Transitions food status to PICKED_UP
  void deliveredToRider() {
    _countdownTimer?.cancel();
    state = state.copyWith(
      status: 'PICKED_UP',
      prepSecondsRemaining: 0,
      riderProgress: 0.05, // rider starts moving from restaurant
    );
    // Automatically start smooth simulation so the rider's live location moves along the route
    startAutoSimulation();
  }

  /// Manually advance rider progress along shortest road route
  void advanceRiderProgress(double delta) {
    final next = (state.riderProgress + delta).clamp(0.0, 1.0);
    state = state.copyWith(riderProgress: next);
  }

  /// Start or toggle live rider movement simulation along shortest path
  void toggleSimulation() {
    if (state.isSimulating) {
      stopAutoSimulation();
    } else {
      startAutoSimulation();
    }
  }

  void startAutoSimulation() {
    _simulationTimer?.cancel();
    state = state.copyWith(isSimulating: true);

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (state.riderProgress < 1.0) {
        final next = (state.riderProgress + 0.08).clamp(0.0, 1.0);
        state = state.copyWith(riderProgress: next);
      } else {
        timer.cancel();
        state = state.copyWith(isSimulating: false);
      }
    });
  }

  void stopAutoSimulation() {
    _simulationTimer?.cancel();
    state = state.copyWith(isSimulating: false);
  }

  /// Rider verifies customer PIN & completes delivery
  bool verifyPinAndComplete(String enteredPin) {
    if (enteredPin.trim() == state.deliveryPin.trim()) {
      _simulationTimer?.cancel();
      _countdownTimer?.cancel();
      state = state.copyWith(
        status: 'DELIVERED',
        riderProgress: 1.0,
        isSimulating: false,
      );
      return true;
    }
    return false;
  }

  /// Reset demo flow for testing
  void resetToPreparing({int mins = 15}) {
    acceptOrder(prepMins: mins);
  }

  void resetToPlaced() {
    _countdownTimer?.cancel();
    _simulationTimer?.cancel();
    state = state.copyWith(
      status: 'PLACED',
      prepSecondsRemaining: 20 * 60,
      riderProgress: 0.0,
      isSimulating: false,
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _simulationTimer?.cancel();
    super.dispose();
  }
}

final foodOrderSyncProvider = StateNotifierProvider<FoodOrderSyncNotifier, FoodOrderLiveState>((ref) {
  return FoodOrderSyncNotifier();
});
