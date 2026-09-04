// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [ApiaryDetailsPage]
class ApiaryDetailsRoute extends PageRouteInfo<ApiaryDetailsRouteArgs> {
  ApiaryDetailsRoute({
    required Apiary apiary,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         ApiaryDetailsRoute.name,
         args: ApiaryDetailsRouteArgs(apiary: apiary, key: key),
         initialChildren: children,
       );

  static const String name = 'ApiaryDetailsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ApiaryDetailsRouteArgs>();
      return WrappedRoute(
        child: ApiaryDetailsPage(apiary: args.apiary, key: args.key),
      );
    },
  );
}

class ApiaryDetailsRouteArgs {
  const ApiaryDetailsRouteArgs({required this.apiary, this.key});

  final Apiary apiary;

  final Key? key;

  @override
  String toString() {
    return 'ApiaryDetailsRouteArgs{apiary: $apiary, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ApiaryDetailsRouteArgs) return false;
    return apiary == other.apiary && key == other.key;
  }

  @override
  int get hashCode => apiary.hashCode ^ key.hashCode;
}

/// generated route for
/// [ApiaryFormPage]
class ApiaryFormRoute extends PageRouteInfo<ApiaryFormRouteArgs> {
  ApiaryFormRoute({Apiary? apiary, Key? key, List<PageRouteInfo>? children})
    : super(
        ApiaryFormRoute.name,
        args: ApiaryFormRouteArgs(apiary: apiary, key: key),
        initialChildren: children,
      );

  static const String name = 'ApiaryFormRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ApiaryFormRouteArgs>(
        orElse: () => const ApiaryFormRouteArgs(),
      );
      return WrappedRoute(
        child: ApiaryFormPage(apiary: args.apiary, key: args.key),
      );
    },
  );
}

class ApiaryFormRouteArgs {
  const ApiaryFormRouteArgs({this.apiary, this.key});

  final Apiary? apiary;

  final Key? key;

  @override
  String toString() {
    return 'ApiaryFormRouteArgs{apiary: $apiary, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ApiaryFormRouteArgs) return false;
    return apiary == other.apiary && key == other.key;
  }

  @override
  int get hashCode => apiary.hashCode ^ key.hashCode;
}

/// generated route for
/// [ApiaryListPage]
class ApiaryListRoute extends PageRouteInfo<void> {
  const ApiaryListRoute({List<PageRouteInfo>? children})
    : super(ApiaryListRoute.name, initialChildren: children);

  static const String name = 'ApiaryListRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return WrappedRoute(child: const ApiaryListPage());
    },
  );
}

/// generated route for
/// [ChangePasswordOtpPage]
class ChangePasswordOtpRoute extends PageRouteInfo<ChangePasswordOtpRouteArgs> {
  ChangePasswordOtpRoute({
    required String currentPassword,
    required String newPassword,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         ChangePasswordOtpRoute.name,
         args: ChangePasswordOtpRouteArgs(
           currentPassword: currentPassword,
           newPassword: newPassword,
           key: key,
         ),
         initialChildren: children,
       );

  static const String name = 'ChangePasswordOtpRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ChangePasswordOtpRouteArgs>();
      return WrappedRoute(
        child: ChangePasswordOtpPage(
          currentPassword: args.currentPassword,
          newPassword: args.newPassword,
          key: args.key,
        ),
      );
    },
  );
}

class ChangePasswordOtpRouteArgs {
  const ChangePasswordOtpRouteArgs({
    required this.currentPassword,
    required this.newPassword,
    this.key,
  });

  final String currentPassword;

  final String newPassword;

  final Key? key;

  @override
  String toString() {
    return 'ChangePasswordOtpRouteArgs{currentPassword: $currentPassword, newPassword: $newPassword, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChangePasswordOtpRouteArgs) return false;
    return currentPassword == other.currentPassword &&
        newPassword == other.newPassword &&
        key == other.key;
  }

  @override
  int get hashCode =>
      currentPassword.hashCode ^ newPassword.hashCode ^ key.hashCode;
}

/// generated route for
/// [ChangePasswordPage]
class ChangePasswordRoute extends PageRouteInfo<void> {
  const ChangePasswordRoute({List<PageRouteInfo>? children})
    : super(ChangePasswordRoute.name, initialChildren: children);

  static const String name = 'ChangePasswordRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ChangePasswordPage();
    },
  );
}

/// generated route for
/// [ForgotPasswordEmailPage]
class ForgotPasswordEmailRoute extends PageRouteInfo<void> {
  const ForgotPasswordEmailRoute({List<PageRouteInfo>? children})
    : super(ForgotPasswordEmailRoute.name, initialChildren: children);

  static const String name = 'ForgotPasswordEmailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return WrappedRoute(child: const ForgotPasswordEmailPage());
    },
  );
}

/// generated route for
/// [ForgotPasswordOtpPage]
class ForgotPasswordOtpRoute extends PageRouteInfo<ForgotPasswordOtpRouteArgs> {
  ForgotPasswordOtpRoute({
    required String flowToken,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         ForgotPasswordOtpRoute.name,
         args: ForgotPasswordOtpRouteArgs(flowToken: flowToken, key: key),
         initialChildren: children,
       );

  static const String name = 'ForgotPasswordOtpRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ForgotPasswordOtpRouteArgs>();
      return WrappedRoute(
        child: ForgotPasswordOtpPage(flowToken: args.flowToken, key: args.key),
      );
    },
  );
}

class ForgotPasswordOtpRouteArgs {
  const ForgotPasswordOtpRouteArgs({required this.flowToken, this.key});

  final String flowToken;

  final Key? key;

  @override
  String toString() {
    return 'ForgotPasswordOtpRouteArgs{flowToken: $flowToken, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ForgotPasswordOtpRouteArgs) return false;
    return flowToken == other.flowToken && key == other.key;
  }

  @override
  int get hashCode => flowToken.hashCode ^ key.hashCode;
}

/// generated route for
/// [HiveDetailsPage]
class HiveDetailsRoute extends PageRouteInfo<HiveDetailsRouteArgs> {
  HiveDetailsRoute({
    required Hive hive,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         HiveDetailsRoute.name,
         args: HiveDetailsRouteArgs(hive: hive, key: key),
         initialChildren: children,
       );

  static const String name = 'HiveDetailsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HiveDetailsRouteArgs>();
      return WrappedRoute(
        child: HiveDetailsPage(hive: args.hive, key: args.key),
      );
    },
  );
}

class HiveDetailsRouteArgs {
  const HiveDetailsRouteArgs({required this.hive, this.key});

  final Hive hive;

  final Key? key;

  @override
  String toString() {
    return 'HiveDetailsRouteArgs{hive: $hive, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HiveDetailsRouteArgs) return false;
    return hive == other.hive && key == other.key;
  }

  @override
  int get hashCode => hive.hashCode ^ key.hashCode;
}

/// generated route for
/// [HiveFormPage]
class HiveFormRoute extends PageRouteInfo<HiveFormRouteArgs> {
  HiveFormRoute({
    required String apiaryId,
    Hive? hive,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         HiveFormRoute.name,
         args: HiveFormRouteArgs(apiaryId: apiaryId, hive: hive, key: key),
         initialChildren: children,
       );

  static const String name = 'HiveFormRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HiveFormRouteArgs>();
      return WrappedRoute(
        child: HiveFormPage(
          apiaryId: args.apiaryId,
          hive: args.hive,
          key: args.key,
        ),
      );
    },
  );
}

class HiveFormRouteArgs {
  const HiveFormRouteArgs({required this.apiaryId, this.hive, this.key});

  final String apiaryId;

  final Hive? hive;

  final Key? key;

  @override
  String toString() {
    return 'HiveFormRouteArgs{apiaryId: $apiaryId, hive: $hive, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HiveFormRouteArgs) return false;
    return apiaryId == other.apiaryId && hive == other.hive && key == other.key;
  }

  @override
  int get hashCode => apiaryId.hashCode ^ hive.hashCode ^ key.hashCode;
}

/// generated route for
/// [HiveListPage]
class HiveListRoute extends PageRouteInfo<HiveListRouteArgs> {
  HiveListRoute({
    required String apiaryId,
    required String apiaryName,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         HiveListRoute.name,
         args: HiveListRouteArgs(
           apiaryId: apiaryId,
           apiaryName: apiaryName,
           key: key,
         ),
         initialChildren: children,
       );

  static const String name = 'HiveListRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HiveListRouteArgs>();
      return WrappedRoute(
        child: HiveListPage(
          apiaryId: args.apiaryId,
          apiaryName: args.apiaryName,
          key: args.key,
        ),
      );
    },
  );
}

class HiveListRouteArgs {
  const HiveListRouteArgs({
    required this.apiaryId,
    required this.apiaryName,
    this.key,
  });

  final String apiaryId;

  final String apiaryName;

  final Key? key;

  @override
  String toString() {
    return 'HiveListRouteArgs{apiaryId: $apiaryId, apiaryName: $apiaryName, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HiveListRouteArgs) return false;
    return apiaryId == other.apiaryId &&
        apiaryName == other.apiaryName &&
        key == other.key;
  }

  @override
  int get hashCode => apiaryId.hashCode ^ apiaryName.hashCode ^ key.hashCode;
}

/// generated route for
/// [HomePage]
class HomeRoute extends PageRouteInfo<void> {
  const HomeRoute({List<PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return WrappedRoute(child: const HomePage());
    },
  );
}

/// generated route for
/// [InspectionDetailsPage]
class InspectionDetailsRoute extends PageRouteInfo<InspectionDetailsRouteArgs> {
  InspectionDetailsRoute({
    required Inspection inspection,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         InspectionDetailsRoute.name,
         args: InspectionDetailsRouteArgs(inspection: inspection, key: key),
         initialChildren: children,
       );

  static const String name = 'InspectionDetailsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<InspectionDetailsRouteArgs>();
      return WrappedRoute(
        child: InspectionDetailsPage(
          inspection: args.inspection,
          key: args.key,
        ),
      );
    },
  );
}

class InspectionDetailsRouteArgs {
  const InspectionDetailsRouteArgs({required this.inspection, this.key});

  final Inspection inspection;

  final Key? key;

  @override
  String toString() {
    return 'InspectionDetailsRouteArgs{inspection: $inspection, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! InspectionDetailsRouteArgs) return false;
    return inspection == other.inspection && key == other.key;
  }

  @override
  int get hashCode => inspection.hashCode ^ key.hashCode;
}

/// generated route for
/// [InspectionFormPage]
class InspectionFormRoute extends PageRouteInfo<InspectionFormRouteArgs> {
  InspectionFormRoute({
    required String hiveId,
    Inspection? inspection,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         InspectionFormRoute.name,
         args: InspectionFormRouteArgs(
           hiveId: hiveId,
           inspection: inspection,
           key: key,
         ),
         initialChildren: children,
       );

  static const String name = 'InspectionFormRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<InspectionFormRouteArgs>();
      return WrappedRoute(
        child: InspectionFormPage(
          hiveId: args.hiveId,
          inspection: args.inspection,
          key: args.key,
        ),
      );
    },
  );
}

class InspectionFormRouteArgs {
  const InspectionFormRouteArgs({
    required this.hiveId,
    this.inspection,
    this.key,
  });

  final String hiveId;

  final Inspection? inspection;

  final Key? key;

  @override
  String toString() {
    return 'InspectionFormRouteArgs{hiveId: $hiveId, inspection: $inspection, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! InspectionFormRouteArgs) return false;
    return hiveId == other.hiveId &&
        inspection == other.inspection &&
        key == other.key;
  }

  @override
  int get hashCode => hiveId.hashCode ^ inspection.hashCode ^ key.hashCode;
}

/// generated route for
/// [InspectionListPage]
class InspectionListRoute extends PageRouteInfo<InspectionListRouteArgs> {
  InspectionListRoute({
    required String hiveId,
    required String hiveName,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         InspectionListRoute.name,
         args: InspectionListRouteArgs(
           hiveId: hiveId,
           hiveName: hiveName,
           key: key,
         ),
         initialChildren: children,
       );

  static const String name = 'InspectionListRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<InspectionListRouteArgs>();
      return WrappedRoute(
        child: InspectionListPage(
          hiveId: args.hiveId,
          hiveName: args.hiveName,
          key: args.key,
        ),
      );
    },
  );
}

class InspectionListRouteArgs {
  const InspectionListRouteArgs({
    required this.hiveId,
    required this.hiveName,
    this.key,
  });

  final String hiveId;

  final String hiveName;

  final Key? key;

  @override
  String toString() {
    return 'InspectionListRouteArgs{hiveId: $hiveId, hiveName: $hiveName, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! InspectionListRouteArgs) return false;
    return hiveId == other.hiveId &&
        hiveName == other.hiveName &&
        key == other.key;
  }

  @override
  int get hashCode => hiveId.hashCode ^ hiveName.hashCode ^ key.hashCode;
}

/// generated route for
/// [LoginOtpPage]
class LoginOtpRoute extends PageRouteInfo<LoginOtpRouteArgs> {
  LoginOtpRoute({
    required String challengeToken,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         LoginOtpRoute.name,
         args: LoginOtpRouteArgs(challengeToken: challengeToken, key: key),
         initialChildren: children,
       );

  static const String name = 'LoginOtpRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LoginOtpRouteArgs>();
      return WrappedRoute(
        child: LoginOtpPage(challengeToken: args.challengeToken, key: args.key),
      );
    },
  );
}

class LoginOtpRouteArgs {
  const LoginOtpRouteArgs({required this.challengeToken, this.key});

  final String challengeToken;

  final Key? key;

  @override
  String toString() {
    return 'LoginOtpRouteArgs{challengeToken: $challengeToken, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LoginOtpRouteArgs) return false;
    return challengeToken == other.challengeToken && key == other.key;
  }

  @override
  int get hashCode => challengeToken.hashCode ^ key.hashCode;
}

/// generated route for
/// [LoginPage]
class LoginRoute extends PageRouteInfo<void> {
  const LoginRoute({List<PageRouteInfo>? children})
    : super(LoginRoute.name, initialChildren: children);

  static const String name = 'LoginRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return WrappedRoute(child: const LoginPage());
    },
  );
}

/// generated route for
/// [MainPage]
class MainRoute extends PageRouteInfo<void> {
  const MainRoute({List<PageRouteInfo>? children})
    : super(MainRoute.name, initialChildren: children);

  static const String name = 'MainRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const MainPage();
    },
  );
}

/// generated route for
/// [ProfileEditPage]
class ProfileEditRoute extends PageRouteInfo<ProfileEditRouteArgs> {
  ProfileEditRoute({
    required User user,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         ProfileEditRoute.name,
         args: ProfileEditRouteArgs(user: user, key: key),
         initialChildren: children,
       );

  static const String name = 'ProfileEditRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ProfileEditRouteArgs>();
      return WrappedRoute(
        child: ProfileEditPage(user: args.user, key: args.key),
      );
    },
  );
}

class ProfileEditRouteArgs {
  const ProfileEditRouteArgs({required this.user, this.key});

  final User user;

  final Key? key;

  @override
  String toString() {
    return 'ProfileEditRouteArgs{user: $user, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ProfileEditRouteArgs) return false;
    return user == other.user && key == other.key;
  }

  @override
  int get hashCode => user.hashCode ^ key.hashCode;
}

/// generated route for
/// [ProfilePage]
class ProfileRoute extends PageRouteInfo<void> {
  const ProfileRoute({List<PageRouteInfo>? children})
    : super(ProfileRoute.name, initialChildren: children);

  static const String name = 'ProfileRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return WrappedRoute(child: const ProfilePage());
    },
  );
}

/// generated route for
/// [RegisterPage]
class RegisterRoute extends PageRouteInfo<void> {
  const RegisterRoute({List<PageRouteInfo>? children})
    : super(RegisterRoute.name, initialChildren: children);

  static const String name = 'RegisterRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return WrappedRoute(child: const RegisterPage());
    },
  );
}

/// generated route for
/// [ResetPasswordPage]
class ResetPasswordRoute extends PageRouteInfo<ResetPasswordRouteArgs> {
  ResetPasswordRoute({
    required String resetToken,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         ResetPasswordRoute.name,
         args: ResetPasswordRouteArgs(resetToken: resetToken, key: key),
         initialChildren: children,
       );

  static const String name = 'ResetPasswordRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ResetPasswordRouteArgs>();
      return WrappedRoute(
        child: ResetPasswordPage(resetToken: args.resetToken, key: args.key),
      );
    },
  );
}

class ResetPasswordRouteArgs {
  const ResetPasswordRouteArgs({required this.resetToken, this.key});

  final String resetToken;

  final Key? key;

  @override
  String toString() {
    return 'ResetPasswordRouteArgs{resetToken: $resetToken, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ResetPasswordRouteArgs) return false;
    return resetToken == other.resetToken && key == other.key;
  }

  @override
  int get hashCode => resetToken.hashCode ^ key.hashCode;
}

/// generated route for
/// [ResetPasswordSuccessPage]
class ResetPasswordSuccessRoute extends PageRouteInfo<void> {
  const ResetPasswordSuccessRoute({List<PageRouteInfo>? children})
    : super(ResetPasswordSuccessRoute.name, initialChildren: children);

  static const String name = 'ResetPasswordSuccessRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ResetPasswordSuccessPage();
    },
  );
}

/// generated route for
/// [TotpSetupPage]
class TotpSetupRoute extends PageRouteInfo<TotpSetupRouteArgs> {
  TotpSetupRoute({
    required TotpSetupChallenge challenge,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         TotpSetupRoute.name,
         args: TotpSetupRouteArgs(challenge: challenge, key: key),
         initialChildren: children,
       );

  static const String name = 'TotpSetupRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<TotpSetupRouteArgs>();
      return WrappedRoute(
        child: TotpSetupPage(challenge: args.challenge, key: args.key),
      );
    },
  );
}

class TotpSetupRouteArgs {
  const TotpSetupRouteArgs({required this.challenge, this.key});

  final TotpSetupChallenge challenge;

  final Key? key;

  @override
  String toString() {
    return 'TotpSetupRouteArgs{challenge: $challenge, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TotpSetupRouteArgs) return false;
    return challenge == other.challenge && key == other.key;
  }

  @override
  int get hashCode => challenge.hashCode ^ key.hashCode;
}
