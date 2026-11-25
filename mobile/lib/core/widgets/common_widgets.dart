import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../theme/twobee_theme.dart';

/// AppBar Home button available across screens to jump straight to Client Home (Tab 0).
class TwoBeeHomeAction extends ConsumerWidget {
  const TwoBeeHomeAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Client Home',
      icon: const Icon(Icons.home_rounded),
      onPressed: () {
        ref.read(clientTabIndexProvider.notifier).state = 0;
        Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
        context.go('/client');
      },
    );
  }
}

/// Displays a modern, floating, auto-closing toast notification that automatically dismisses itself.
void showAutoDismissToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 1800),
}) {
  final sm = ScaffoldMessenger.of(context);
  sm.clearSnackBars();
  sm.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      duration: duration,
      content: Text(
        message,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
  );
  // Programmatic dismissal timer guarantees auto-close even when mouse pointer hovers on web/desktop
  Future.delayed(duration, () {
    try {
      sm.clearSnackBars();
    } catch (_) {}
  });
}

/// 4 individual Security/Start PIN digit tiles matching reference mockups.
class PinDigitsRow extends StatelessWidget {
  final String pin;
  const PinDigitsRow({super.key, required this.pin});

  @override
  Widget build(BuildContext context) {
    final chars = pin.padRight(4, '-').split('').take(4).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: chars
          .map(
            (c) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 38,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TwoBeeColors.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: TwoBeeColors.primary, width: 1.5),
              ),
              child: Text(
                c,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: TwoBeeColors.primaryDark),
              ),
            ),
          )
          .toList(),
    );
  }
}

/// High-contrast 4-digit PIN entry field used across Rider pickup/handover flows.
class PinInputBox extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  final String hintText;

  const PinInputBox({
    super.key,
    required this.controller,
    this.maxLength = 4,
    this.hintText = '• • • •',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      cursorColor: TwoBeeColors.primaryDark,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        letterSpacing: 10,
        color: TwoBeeColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 8,
          color: TwoBeeColors.textMuted,
        ),
        counterStyle: const TextStyle(
          color: TwoBeeColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: TwoBeeColors.surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TwoBeeColors.primary, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TwoBeeColors.primary, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TwoBeeColors.primaryDark, width: 2.2),
        ),
      ),
    );
  }
}

class VerificationBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isErrorStyle;
  final VoidCallback? onTap;

  const VerificationBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.isErrorStyle = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isErrorStyle ? TwoBeeColors.errorBg : TwoBeeColors.warningBg;
    final border = isErrorStyle ? TwoBeeColors.errorText.withValues(alpha: 0.35) : TwoBeeColors.warningBorder;
    final fg = isErrorStyle ? TwoBeeColors.errorText : TwoBeeColors.warningText;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(isErrorStyle ? Icons.lock_clock_outlined : Icons.hourglass_top_rounded, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: fg, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: fg, fontSize: 12)),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right_rounded, color: fg),
          ],
        ),
      ),
    );
  }
}

/// Reusable numeric passcode keypad supporting BOTH 4-digit (Rider) and 6-digit (Merchant) modes.
class PasscodePad extends StatelessWidget {
  final int length;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onBiometric;
  final bool loading;

  const PasscodePad({
    super.key,
    required this.length,
    required this.value,
    required this.onChanged,
    this.onBiometric,
    this.loading = false,
  });

  void _tapDigit(String d) {
    if (loading || value.length >= length) return;
    onChanged('$value$d');
  }

  void _backspace() {
    if (loading || value.isEmpty) return;
    onChanged(value.substring(0, value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(length, (i) {
            final filled = i < value.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? TwoBeeColors.primary : TwoBeeColors.surfaceCard,
                border: Border.all(
                  color: filled ? TwoBeeColors.primaryDark : TwoBeeColors.textMuted.withValues(alpha: 0.45),
                  width: 1.5,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((d) => _KeyButton(label: d, onTap: () => _tapDigit(d))).toList(),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            onBiometric != null
                ? _KeyButton(
                    icon: Icons.fingerprint_rounded,
                    tint: TwoBeeColors.primary,
                    bg: TwoBeeColors.primarySoft.withValues(alpha: 0.45),
                    onTap: onBiometric!,
                  )
                : const SizedBox(width: 84, height: 54),
            _KeyButton(label: '0', onTap: () => _tapDigit('0')),
            _KeyButton(icon: Icons.backspace_outlined, onTap: _backspace),
          ],
        ),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final Color? bg;
  final Color? tint;
  final VoidCallback onTap;

  const _KeyButton({this.label, this.icon, this.bg, this.tint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: bg ?? TwoBeeColors.surfaceCard,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Container(
            width: 72,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: TwoBeeColors.borderSoft),
            ),
            child: label != null
                ? Text(label!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: TwoBeeColors.textPrimary))
                : Icon(icon, color: tint ?? TwoBeeColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Interactive Payment Method Picker enforcing:
/// - Functional Option 1: COD / Cash
/// - Functional Option 2: Online (Stripe Free Sandbox)
/// - Preview-only options: bKash, Nagad, Rocket (marked cleanly non-functional until live credentials)
class PaymentSelectorCard extends StatelessWidget {
  final String selectedMethod; // COD | STRIPE_SANDBOX
  final ValueChanged<String> onSelected;
  final bool showCod;

  const PaymentSelectorCard({
    super.key,
    required this.selectedMethod,
    required this.onSelected,
    this.showCod = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            if (showCod)
              _PaymentTile(
                title: 'Cash on Delivery / Cash',
                subtitle: 'Pay exact cash to courier upon handover',
                icon: Icons.payments_outlined,
                selected: selectedMethod == 'COD',
                onTap: () => onSelected('COD'),
              ),
            const SizedBox(height: 8),
            _PaymentTile(
              title: 'Online Card (Stripe Sandbox)',
              subtitle: 'Free test gateway · 4242 •••• 4242',
              icon: Icons.credit_card_rounded,
              selected: selectedMethod == 'STRIPE_SANDBOX',
              badge: 'TEST ACTIVE',
              onTap: () => onSelected('STRIPE_SANDBOX'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Bangladesh MFS (UI Preview — Coming Soon)',
              style: TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['bKash', 'Nagad', 'Rocket'].map((mfs) {
                return ActionChip(
                  avatar: const Icon(Icons.schedule_rounded, size: 15, color: TwoBeeColors.textSecondary),
                  label: Text('$mfs (Preview)'),
                  backgroundColor: TwoBeeColors.surfaceTonal,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$mfs gateway is in UI preview mode. Select Cash or Stripe Sandbox to transact.'),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  const _PaymentTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? TwoBeeColors.surfaceTonal : TwoBeeColors.scaffoldBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? TwoBeeColors.primary : TwoBeeColors.borderSoft, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? TwoBeeColors.primary : TwoBeeColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: TwoBeeColors.primarySoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(badge!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary)),
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

/// Interactive Free Stripe Sandbox Card Confirmation Dialog (Zero API fee)
Future<bool> showStripeSandboxDialog(BuildContext context, {required num amountBdt, required String title}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: TwoBeeColors.primary),
          SizedBox(width: 8),
          Text('Stripe Test Sandbox'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Amount: ${bdt(amountBdt)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TwoBeeColors.primary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TwoBeeColors.surfaceTonal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Test Visa Card', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text('4242  4242  4242  4242', style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                Text('Exp: 12/30 · CVC: 424', style: TextStyle(fontSize: 12, color: TwoBeeColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Pay ${bdt(amountBdt)} (Sandbox)'),
        ),
      ],
    ),
  );
  return result == true;
}

class TwoBeeMapPreview extends StatefulWidget {
  final double pickupLat;
  final double pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final double? riderLat;
  final double? riderLng;
  final double height;

  const TwoBeeMapPreview({
    super.key,
    this.pickupLat = 23.7937,
    this.pickupLng = 90.4066,
    this.dropoffLat,
    this.dropoffLng,
    this.riderLat,
    this.riderLng,
    this.height = 190,
  });

  @override
  State<TwoBeeMapPreview> createState() => _TwoBeeMapPreviewState();
}

class _TwoBeeMapPreviewState extends State<TwoBeeMapPreview> {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(covariant TwoBeeMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.riderLat != null &&
        widget.riderLng != null &&
        (widget.riderLat != oldWidget.riderLat || widget.riderLng != oldWidget.riderLng)) {
      try {
        _mapController.move(
          LatLng(widget.riderLat!, widget.riderLng!),
          _mapController.camera.zoom,
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(
      widget.riderLat ?? widget.pickupLat,
      widget.riderLng ?? widget.pickupLng,
    );
    final markers = <Marker>[
      Marker(
        point: LatLng(widget.pickupLat, widget.pickupLng),
        width: 36,
        height: 36,
        child: const Icon(Icons.trip_origin, color: TwoBeeColors.primary, size: 28),
      ),
      if (widget.dropoffLat != null && widget.dropoffLng != null)
        Marker(
          point: LatLng(widget.dropoffLat!, widget.dropoffLng!),
          width: 36,
          height: 36,
          child: const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 30),
        ),
      if (widget.riderLat != null && widget.riderLng != null)
        Marker(
          point: LatLng(widget.riderLat!, widget.riderLng!),
          width: 40,
          height: 40,
          child: Container(
            decoration: const BoxDecoration(color: TwoBeeColors.obsidian, shape: BoxShape.circle),
            child: const Icon(Icons.two_wheeler_rounded, color: TwoBeeColors.primarySoft, size: 22),
          ),
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: TwoBeeRadii.card,
        border: Border.all(color: TwoBeeColors.borderSoft),
        boxShadow: TwoBeeShadows.softCard,
      ),
      child: ClipRRect(
        borderRadius: TwoBeeRadii.card,
        child: SizedBox(
          height: widget.height,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: 12.8),
            children: [
              TileLayer(
                urlTemplate: AppConfig.mapTileUrl,
                userAgentPackageName: 'app.twobee.mobile',
              ),
              if (widget.dropoffLat != null && widget.dropoffLng != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [LatLng(widget.pickupLat, widget.pickupLng), LatLng(widget.dropoffLat!, widget.dropoffLng!)],
                      strokeWidth: 4,
                      color: TwoBeeColors.primary,
                    ),
                  ],
                ),
              MarkerLayer(markers: markers),
            ],
          ),
        ),
      ),
    );
  }
}

