import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:mayorapp/unauthorized_screen.dart'; // Adjust import path as necessary
import 'package:mayorapp/main.dart'; // For MyApp, if needed for navigation context

// Create a mock for FirebaseAuth.
// It's better to use build_runner and @GenerateMocks for more complex scenarios,
// but for a simple signOut, a manual mock can suffice if direct instance mocking is hard.
class MockFirebaseAuth extends Mock implements FirebaseAuth {
  // If testing state changes based on auth, you might need to mock authStateChanges()
  // For this screen, primarily testing the signOut call.
  @override
  Future<void> signOut() {
    return super.noSuchMethod(
      Invocation.method(#signOut, []),
      returnValue: Future<void>.value(),
      returnValueForMissingStub: Future<void>.value(),
    );
  }
}

// It's often difficult to directly mock FirebaseAuth.instance.
// A common approach is to pass FirebaseAuth instance via constructor,
// or use a mocking framework that supports static instance mocking (like mocktail's registerFallbackValue with a plugin).
// For this test, we'll try to verify UI and if the button has an onPressed.
// Verifying the actual call to FirebaseAuth.instance.signOut() might be brittle
// without a more sophisticated test setup or DI.

void main() {
  // Late initialization of the mock
  late MockFirebaseAuth mockFirebaseAuth;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    // In a real app with DI, you would provide this mock.
    // For now, we can't easily inject it into FirebaseAuth.instance directly in tests
    // without more setup (like a test harness that sets up Firebase for tests).
  });


  testWidgets('UnauthorizedScreen displays correctly and Sign Out button is present', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MaterialApp(home: UnauthorizedScreen()));

    // Verify that the title is present.
    expect(find.text('Unauthorized'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);

    // Verify the main informational text.
    expect(find.text('Access Denied'), findsOneWidget);
    expect(find.textContaining('your account is not authorized', findRichText: true), findsOneWidget);
    
    // Verify the Icon is present
    expect(find.byIcon(Icons.gpp_maybe_outlined), findsOneWidget);

    // Verify the "Sign Out" button is present.
    final signOutButtonFinder = find.widgetWithText(ElevatedButton, 'Sign Out');
    expect(signOutButtonFinder, findsOneWidget);

    // At this point, testing the actual FirebaseAuth.instance.signOut() call
    // within the button's onPressed without a proper DI/mocking setup for Firebase services
    // is difficult and can be flaky.
    // We've confirmed the button is there. A more involved test could use a mock navigator
    // to verify navigation, or a mock FirebaseAuth instance if it were injectable.

    // Example of how you might try to tap, though verifying the internal call is the tricky part.
    // For now, we'll just ensure it doesn't crash on tap.
    // No specific check for signOut being called due to mocking limitations here.
    // In a full setup, you would:
    // 1. Inject MockFirebaseAuth.
    // 2. when(mockFirebaseAuth.signOut()).thenAnswer((_) async => {});
    // 3. await tester.tap(signOutButtonFinder);
    // 4. await tester.pumpAndSettle(); // Allow time for async operations and navigation
    // 5. verify(mockFirebaseAuth.signOut()).called(1);
    // 6. Verify navigation, e.g., expect(find.byType(LoginScreen or MyApp's initial route), findsOneWidget);
    
    // Basic tap test to ensure no crash
    await tester.tap(signOutButtonFinder);
    await tester.pump(); // Process the tap

    // Due to the navigation `Navigator.of(context).pushAndRemoveUntil(...)`,
    // the UnauthorizedScreen itself will be removed from the widget tree.
    // We can't easily verify the navigation target without a more complex setup
    // involving mock navigators or a full app wrapper with routes.
  });
}
