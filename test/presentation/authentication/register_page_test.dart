import 'dart:async';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/auth_challenge.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/presentation/authentication/cubit/register_cubit/register_cubit.dart';
import 'package:beebase/presentation/authentication/register_page.dart';
import 'package:beebase/presentation/component/buttons/primary_button.dart';
import 'package:beebase/presentation/component/text_field/app_text_field.dart';
import 'package:beebase/utils/either.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthenticationRepository extends Mock implements AuthenticationRepository {}

void main() {
  late MockAuthenticationRepository repository;
  late RegisterCubit registerCubit;

  setUp(() {
    repository = MockAuthenticationRepository();
    registerCubit = RegisterCubit(repository: repository);
  });

  Future<void> pumpRegisterPage(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<RegisterCubit>.value(value: registerCubit, child: const RegisterPage()),
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
  const emailLabelKey = 'authentication.register.email_label';
  const passwordLabelKey = 'authentication.register.password_label';
  const confirmPasswordLabelKey = 'authentication.register.confirm_password_label';
  const emailInvalidKey = 'authentication.register.validations.email_invalid';
  const passwordTooShortKey = 'authentication.register.validations.password_too_short';
  const confirmPasswordMismatchKey = 'authentication.register.validations.confirm_password_mismatch';

  Future<void> enterFieldText(WidgetTester tester, String labelKey, String text) {
    final field = find.descendant(
      of: find.widgetWithText(AppTextField, labelKey),
      matching: find.byType(TextField),
    );
    return tester.enterText(field, text);
  }

  testWidgets('shows validation errors and does not call the repository with invalid input', (tester) async {
    await pumpRegisterPage(tester);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(find.text(emailInvalidKey), findsOneWidget);
    expect(find.text(passwordTooShortKey), findsOneWidget);
    verifyNever(
      () => repository.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('shows a validation error when the passwords do not match', (tester) async {
    await pumpRegisterPage(tester);

    await enterFieldText(tester, emailLabelKey, 'bee@example.com');
    await enterFieldText(tester, passwordLabelKey, 'password123');
    await enterFieldText(tester, confirmPasswordLabelKey, 'somethingElse123');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(find.text(confirmPasswordMismatchKey), findsOneWidget);
    verifyNever(
      () => repository.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('submits the entered credentials and shows the server error', (tester) async {
    when(
      () => repository.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => Left(ServerFailure(code: 'email_taken', message: 'already registered')));
    await pumpRegisterPage(tester);

    await enterFieldText(tester, emailLabelKey, 'bee@example.com');
    await enterFieldText(tester, passwordLabelKey, 'password123');
    await enterFieldText(tester, confirmPasswordLabelKey, 'password123');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    verify(() => repository.register(email: 'bee@example.com', password: 'password123')).called(1);
    expect(find.text('already registered'), findsOneWidget);
  });

  testWidgets('shows a loading indicator while the request is in flight', (tester) async {
    final completer = Completer<Either<Failure, TotpSetupChallenge>>();
    when(
      () => repository.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => completer.future);
    await pumpRegisterPage(tester);

    await enterFieldText(tester, emailLabelKey, 'bee@example.com');
    await enterFieldText(tester, passwordLabelKey, 'password123');
    await enterFieldText(tester, confirmPasswordLabelKey, 'password123');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(Left(ServerFailure(code: 'email_taken', message: 'already registered')));
    await tester.pump();
  });
}
