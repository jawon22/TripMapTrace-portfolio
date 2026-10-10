import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';

void main() {
  testWidgets('App starts on LoginScreen when not logged in', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(isLoggedIn: false, onboardingDone: false));
    expect(find.text('TripMapTrace'), findsOneWidget);
  });
}
