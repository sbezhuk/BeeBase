import 'dart:async';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/auth_challenge.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/presentation/authentication/cubit/login_cubit/login_cubit.dart';
import 'package:beebase/presentation/authentication/login_page.dart';
import 'package:beebase/presentation/component/buttons/primary_button.dart';
import 'package:beebase/presentation/component/text_field/app_text_field.dart';
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

  // No EasyLocalization ancestor is pumped in these tests, so `.tr()` falls
  // back to returning the key itself — match against those raw keys rather
  // than the translated copy. Same reason AppTextField (a plain TextField
  // with its label rendered as a sibling Text, not TextFormField.decoration)
  // and PrimaryButton (a custom InkWell, not ElevatedButton) need
  // type/label-based finders instead of the widgetWithText(TextFormField/
  // ElevatedButton, ...) shape used elsewhere.
  const emailLabelKey = 'authentication.login.email_label';
  const passwordLabelKey = 'authentication.login.password_label';
  const emailInvalidKey = 'authentication.login.validations.email_invalid';
  const passwordTooShortKey = 'authentication.login.validations.password_too_short';

  Future<void> enterFieldText(WidgetTester tester, String labelKey, String text) {
    final field = find.descendant(
      of: find.widgetWithText(AppTextField, labelKey),
      matching: find.byType(TextField),
    );
    return tester.enterText(field, text);
  }

  testWidgets(
    'shows validation errors and does not call the repository with invalid input',
    (tester) async {
      await pumpLoginPage(tester);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();

      expect(find.text(emailInvalidKey), findsOneWidget);
      expect(find.text(passwordTooShortKey), findsOneWidget);
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

    await enterFieldText(tester, emailLabelKey, 'bee@example.com');
    await enterFieldText(tester, passwordLabelKey, 'password123');
    await tester.tap(find.byType(PrimaryButton));
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

    await enterFieldText(tester, emailLabelKey, 'bee@example.com');
    await enterFieldText(tester, passwordLabelKey, 'password123');
    await tester.tap(find.byType(PrimaryButton));
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
