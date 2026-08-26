import 'dart:async';

import 'package:beebase/core/networking/failures/failure.dart';
import 'package:beebase/domain/entity/user.dart';
import 'package:beebase/domain/repositories/authentication_repository.dart';
import 'package:beebase/presentation/authentication/cubit/authentication_cubit/authentication_cubit.dart';
import 'package:beebase/presentation/authentication/cubit/register_cubit/register_cubit.dart';
import 'package:beebase/presentation/authentication/register_page.dart';
import 'package:beebase/utils/either.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

class MockAuthenticationCubit extends MockCubit<AuthenticationState>
    implements AuthenticationCubit {}

void main() {
  late MockAuthenticationRepository repository;
  late MockAuthenticationCubit authenticationCubit;
  late RegisterCubit registerCubit;

  setUp(() {
    repository = MockAuthenticationRepository();
    authenticationCubit = MockAuthenticationCubit();
    registerCubit = RegisterCubit(
      repository: repository,
      authenticationCubit: authenticationCubit,
    );
  });

  Future<void> pumpRegisterPage(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<RegisterCubit>.value(
          value: registerCubit,
          child: const RegisterPage(),
        ),
      ),
    );
  }

  testWidgets(
    'shows validation errors and does not call the repository with invalid input',
    (tester) async {
      await pumpRegisterPage(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign up'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
      verifyNever(
        () => repository.register(
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
      () => repository.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => Left(
        ServerFailure(code: 'email_taken', message: 'already registered'),
      ),
    );
    await pumpRegisterPage(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'bee@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign up'));
    await tester.pumpAndSettle();

    verify(
      () => repository.register(
        email: 'bee@example.com',
        password: 'password123',
      ),
    ).called(1);
    expect(find.text('already registered'), findsOneWidget);
  });

  testWidgets('shows a loading indicator while the request is in flight', (
    tester,
  ) async {
    final completer = Completer<Either<Failure, User>>();
    when(
      () => repository.register(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => completer.future);
    await pumpRegisterPage(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'bee@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign up'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(
      Left(ServerFailure(code: 'email_taken', message: 'already registered')),
    );
    await tester.pump();
  });
}
