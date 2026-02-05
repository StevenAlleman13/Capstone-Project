/* test settings tab (unimplemented)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/screens/login_page.dart';

void main() {
  testWidgets('successful login navigates to home', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const Scaffold(body: Center(child: Text('Home'))),
      },
    ));

    // Enter credentials
    await tester.enterText(find.byType(TextFormField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');

    // Tap sign in (disambiguate using the ElevatedButton)
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));

    // Let async auth complete
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('invalid credentials show error', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: const LoginPage()));

    await tester.enterText(find.byType(TextFormField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Invalid credentials'), findsOneWidget);
  });
}
*/