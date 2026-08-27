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
/// [HomePage]
class HomeRoute extends PageRouteInfo<void> {
  const HomeRoute({List<PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const HomePage();
    },
  );
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
/// [ProfilePage]
class ProfileRoute extends PageRouteInfo<void> {
  const ProfileRoute({List<PageRouteInfo>? children})
    : super(ProfileRoute.name, initialChildren: children);

  static const String name = 'ProfileRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ProfilePage();
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
