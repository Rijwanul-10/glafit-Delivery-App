import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../config/app_config.dart';
import '../services/food_order_sync_service.dart';
import '../theme/twobee_theme.dart';

class FoodpandaShortestRouteMap extends StatelessWidget {
  final FoodOrderLiveState orderState;
  final double height;
  final bool showTurnByTurnBanner;
  final VoidCallback? onToggleSimulation;
  final VoidCallback? onStepForward;

  const FoodpandaShortestRouteMap({
    super.key,
    required this.orderState,
    this.height = 240,
    this.showTurnByTurnBanner = true,
    this.onToggleSimulation,
    this.onStepForward,
  });

  @override
  Widget build(BuildContext context) {
    final riderPos = orderState.riderPosition;
    final storePos = kBananiFoodShortestRoute.first;
    final dropoffPos = kBananiFoodShortestRoute.last;
    final isEnRoute = orderState.status == 'PICKED_UP';
    final isDelivered = orderState.status == 'DELIVERED';

    return Container(
      decoration: BoxDecoration(
        borderRadius: TwoBeeRadii.card,
        border: Border.all(color: TwoBeeColors.borderSoft),
        boxShadow: TwoBeeShadows.softCard,
      ),
      child: ClipRRect(
        borderRadius: TwoBeeRadii.card,
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: isEnRoute ? riderPos : storePos,
                  initialZoom: 14.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate: AppConfig.mapTileUrl,
                    userAgentPackageName: 'app.twobee.mobile',
                  ),
                  // Foodpanda Shortest Path Route Polylines
                  PolylineLayer(
                    polylines: [
                      // Outer glow polyline (Foodpanda aesthetic)
                      Polyline(
                        points: kBananiFoodShortestRoute,
                        strokeWidth: 8.0,
                        color: TwoBeeColors.primary.withValues(alpha: 0.35),
                      ),
                      // Core crisp shortest road route
                      Polyline(
                        points: kBananiFoodShortestRoute,
                        strokeWidth: 4.5,
                        color: TwoBeeColors.primaryDark,
                      ),
                    ],
                  ),
                  // Markers
                  MarkerLayer(
                    markers: [
                      // 1. Restaurant Marker (Sultan's Dine)
                      Marker(
                        point: storePos,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: TwoBeeColors.obsidian,
                            shape: BoxShape.circle,
                            border: Border.all(color: TwoBeeColors.primary, width: 2),
                            boxShadow: TwoBeeShadows.softCard,
                          ),
                          child: const Icon(Icons.restaurant_rounded, color: TwoBeeColors.primary, size: 22),
                        ),
                      ),
                      // 2. Customer Destination Marker
                      Marker(
                        point: dropoffPos,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.redAccent.shade700,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: TwoBeeShadows.softCard,
                          ),
                          child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                      // 3. Live Rider Marker (EV Bike with Radar Pulse)
                      if (isEnRoute || isDelivered)
                        Marker(
                          point: riderPos,
                          width: 52,
                          height: 52,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulsing radar glow
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: TwoBeeColors.primary.withValues(alpha: 0.25),
                                  border: Border.all(color: TwoBeeColors.primary.withValues(alpha: 0.5), width: 1.5),
                                ),
                              ),
                              // Core bike badge
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: TwoBeeColors.obsidian,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: TwoBeeColors.primary, width: 2),
                                ),
                                child: const Icon(Icons.electric_moped_rounded, color: TwoBeeColors.primary, size: 20),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Foodpanda-Style Turn-by-Turn Navigation HUD (Top Banner)
              if (showTurnByTurnBanner && isEnRoute)
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: TwoBeeColors.obsidian.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: TwoBeeColors.primary.withValues(alpha: 0.6)),
                      boxShadow: TwoBeeShadows.dockNav,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: TwoBeeColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.turn_right_rounded, color: Colors.black, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                orderState.currentTurnInstruction,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: TwoBeeColors.primaryDark,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('SHORTEST ROUTE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    orderState.distanceRemainingFormatted,
                                    style: const TextStyle(color: TwoBeeColors.primarySoft, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Floating Demo Controls (Bottom Left / Right)
              if (isEnRoute)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: TwoBeeColors.obsidian.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: TwoBeeColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onToggleSimulation != null)
                          InkWell(
                            onTap: onToggleSimulation,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    orderState.isSimulating ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                    color: TwoBeeColors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    orderState.isSimulating ? 'Pause GPS' : 'Live GPS Demo',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (onStepForward != null) ...[
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: onStepForward,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: TwoBeeColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('Step ➔', style: TextStyle(color: TwoBeeColors.primary, fontSize: 10, fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
