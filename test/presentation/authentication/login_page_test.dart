import 'dart:async';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/auth_challenge.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/presentation/authentication/cubit/login_cubit/login_cubit.dart';
import 'package:beebase/presentation/authentication/login_page.dart';
import 'package:beebase/utils/either.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

void main() {
  late MockAuthenticationRepository repository;
  late LoginCubit loginCubit;

  setUp(() {
    repository = MockAuthenticationRepository();
    loginCubit = LoginCubit(repository: repository);
  });

  Future<void> pumpLoginPage(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<LoginCubit>.value(
          value: loginCubit,
          child: const LoginPage(),
        ),
      ),
    );
  }

  testWidgets(
    'shows validation errors and does not call the repository with invalid input',
    (tester) async {
      await pumpLoginPage(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
      verifyNever(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    },
  );

  testWidgets('submits the entered credentials and shows the server error', (
    tester,
  ) async {
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => Left(
        ServerFailure(
          code: 'invalid_credentials',
          message: 'invalid email or password',
        ),
      ),
    );
    await pumpLoginPage(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'bee@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    verify(
      () => repository.login(email: 'bee@example.com', password: 'password123'),
    ).called(1);
    expect(find.text('invalid email or password'), findsOneWidget);
  });

  testWidgets('shows a loading indicator while the request is in flight', (
    tester,
  ) async {
    final completer = Completer<Either<Failure, AuthChallenge>>();
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => completer.future);
    await pumpLoginPage(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'bee@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Resolve the pending future so the test doesn't leak a timer/state change.
    // Resolved with a failure (not success) so the widget doesn't attempt to
    // navigate through auto_route, which isn't wired up in this test's tree.
    completer.complete(
      Left(
        ServerFailure(
          code: 'invalid_credentials',
          message: 'invalid email or password',
        ),
      ),
    );
    await tester.pump();
  });
}
