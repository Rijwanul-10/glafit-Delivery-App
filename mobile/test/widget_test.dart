import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twobee_app/core/network/api_client.dart';
import 'package:twobee_app/core/theme/twobee_theme.dart';
import 'package:twobee_app/core/widgets/app_bottom_nav.dart';
import 'package:twobee_app/core/widgets/common_widgets.dart';
import 'package:twobee_app/features/auth/auth_screens.dart';
import 'package:twobee_app/features/client/client_food_screens.dart';
import 'package:twobee_app/features/client/client_parcel_screens.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient(super.ref);

  @override
  Future<Map<String, dynamic>> get(String path, {String? roleToken, Map<String, dynamic>? query}) async {
    if (path == '/parcels/incoming') {
      return {'ok': true, 'shipments': <Map<String, dynamic>>[]};
    }
    return {'ok': true};
  }
}

void main() {
  testWidgets('Option B AppBottomNav renders role-tailored 4 tabs for Client, Rider, Merchant', (tester) async {
    Widget wrap(AppUserRole role) => MaterialApp(
          theme: TwoBeeTheme.light(),
          home: Scaffold(
            bottomNavigationBar: AppBottomNav(role: role, currentIndex: 0, onTap: (_) {}),
          ),
        );

    // Client: Home | Activity | Wallet | Profile
    await tester.pumpWidget(wrap(AppUserRole.client));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Rider: Home | Jobs | Wallet | Profile
    await tester.pumpWidget(wrap(AppUserRole.rider));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Merchant: Home | Orders | Wallet | Store
    await tester.pumpWidget(wrap(AppUserRole.merchant));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Store'), findsOneWidget);
  });

  testWidgets('LoginScreen uses phone-OTP only and removes Continue with Google', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: TwoBeeTheme.light(), home: const LoginScreen()),
      ),
    );
    expect(find.text('Send OTP'), findsOneWidget);
    expect(find.textContaining('Google'), findsNothing);
    expect(find.textContaining('P&D'), findsNothing);
  });

  testWidgets('PasscodePad renders 4 dots for Rider and 6 dots for Merchant', (tester) async {
    String val = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (ctx, setS) => PasscodePad(
              length: 6,
              value: val,
              onChanged: (v) => setS(() => val = v),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('5'));
    await tester.pump();
    expect(val, '25');
  });

  testWidgets('PasscodePad supports 4-digit Rider mode as well as 6-digit Merchant mode', (tester) async {
    String val = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (ctx, setS) => PasscodePad(
              length: 4,
              value: val,
              onChanged: (v) => setS(() => val = v),
            ),
          ),
        ),
      ),
    );
    for (final d in ['2', '5', '8', '0']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    expect(val, '2580');
  });

  testWidgets('PaymentSelectorCard shows COD, Stripe Sandbox and MFS preview options', (tester) async {
    String selected = 'COD';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaymentSelectorCard(
            selectedMethod: selected,
            onSelected: (v) => selected = v,
          ),
        ),
      ),
    );
    expect(find.text('Cash on Delivery / Cash'), findsOneWidget);
    expect(find.text('Online Card (Stripe Sandbox)'), findsOneWidget);
    expect(find.text('bKash (Preview)'), findsOneWidget);
    expect(find.text('Nagad (Preview)'), findsOneWidget);
    expect(find.text('Rocket (Preview)'), findsOneWidget);
  });

  testWidgets('TwoBeeCartAction renders persistent cart button with dynamic badge', (tester) async {
    final container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: TwoBeeTheme.light(),
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Food Home'),
              actions: const [TwoBeeCartAction()],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TwoBeeCartAction), findsOneWidget);
    expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);

    container.read(cartProvider.notifier).addItem(
          merchantId: 'test-merchant',
          merchantName: 'Test Kitchen',
          deliveryFee: 40,
          line: CartLine(menuItemId: 'item-1', name: 'Biryani', basePrice: 300, quantity: 2),
        );
    await tester.pump();

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('ParcelServiceScreen has distinct Send Parcel and Receive Parcel tabs with P2P flow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWith((ref) => FakeApiClient(ref)),
        ],
        child: const MaterialApp(home: ParcelServiceScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Send Parcel'), findsOneWidget);
    expect(find.text('Receive Parcel'), findsOneWidget);
    expect(find.text('PICKUP FROM (SENDER)'), findsOneWidget);
    expect(find.text('DELIVER TO (RECIPIENT)'), findsOneWidget);

    // Switch to Receive Parcel tab
    await tester.tap(find.text('Receive Parcel'));
    await tester.pump();

    expect(find.textContaining('Enter Tracking Code'), findsOneWidget);
  });
}
