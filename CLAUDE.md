# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

Only one flavor exists today: **`production`** (`android/app/build.gradle.kts` → `productFlavors { create("production") {...} }`). All build types (`debug`, `release`, and even a leftover `anothercustombuild` entry) map to the same root `.env` file — there is no dev/staging environment wired up yet, despite the flavor-style scaffolding. `.env` is gitignored and must exist locally (see keys in `.env` at repo root: `API_END_POINT`, `MAPBOX_PUBLIC_KEY`, `APPLE_*`, `GOOGLE_*`, `ENVIRONMENT`).

```bash
# Install dependencies
flutter pub get

# Run (only flavor/entry point that exists)
flutter run --flavor production --target lib/main_prod.dart

# Codegen — REQUIRED after editing AutoRoute routes, json_serializable models, or DI-related annotations
flutter pub run build_runner build --delete-conflicting-outputs
flutter pub run build_runner watch --delete-conflicting-outputs   # keep running while developing

# Regenerate after editing assets/langs/en-US.json
flutter pub run easy_localization:generate

# Before every PR
flutter analyze     # must be clean; analysis_options.yaml promotes several lints to errors
dart format .

# Build
flutter build apk --flavor production --target lib/main_prod.dart
```

There is **no `test/` directory** — the project currently has no automated tests. Generated files (`*.g.dart`, `*.gr.dart`) are gitignored and excluded from `flutter analyze` (`analysis_options.yaml`) — regenerate with `build_runner` rather than hand-editing them.

## Architecture

Clean architecture, three layers under `lib/`, dependencies point inward (`presentation` → `domain` ← `data`), with `core/` as cross-cutting infrastructure shared by all. Entry point is `lib/main_prod.dart` → `lib/application.dart`. `main()` initializes `EasyLocalization`, loads `AppConfig` (`Enviroment.production` — the enum currently has a single value, so this doesn't actually branch on environment yet), runs `initDi()`, preloads SVG/image assets (`utils/images/preload_resources.dart`), sets the Mapbox access token, then `runApp`.

```text
lib/
 ├─ core/                   # Cross-cutting: networking (DioClient, interceptors, failures), storage, services
 ├─ data/
 │   ├─ data_source/        # API clients; interface/ holds narrow reader/writer interfaces
 │   ├─ models/             # Response/request DTOs; extensions/ holds DTO → entity mappers
 │   └─ repositories/       # *_impl classes: wrap data sources, map to entities, return Either
 ├─ domain/
 │   ├─ entity/             # Core business models
 │   ├─ enum/                # Domain enums
 │   └─ repositories/       # Repository interfaces (reader/writer) + base Repository class
 ├─ presentation/
 │   ├─ <feature>/          # authentication, gear, profile, session, search, user_invites, main, notification
 │   │   ├─ cubit/          #   one subfolder per cubit: *_cubit.dart, *_state.dart (part), mixin/*_emitter.dart (part)
 │   │   ├─ widget(s)/      #   feature-specific UI (naming inconsistent, see Conventions)
 │   │   └─ extension(s)/   #   feature-specific extensions (naming inconsistent, see Conventions)
 │   ├─ component/          # Design-system primitives: AppColor, AppFont/AppTextStyles, AppImage, buttons/, checkbox/
 │   ├─ widgets/            # Shared composite widgets (bottom nav bar, cropper, text field)
 │   └─ router/             # AutoRoute config (app_router.dart), guardes/, wrapper_pages/, placeholders/
 ├─ utils/                  # Either, AppConfig, di, themes/ (ThemeExtensions), extensions/, images/
 ├─ application.dart        # MaterialApp.router + ThemeData.extensions
 └─ main_prod.dart          # Only entry point (single "production" flavor)
```

### Interface segregation is the dominant pattern

The single most important thing to understand: **data sources and repositories are split into narrow reader/writer interfaces**, and one concrete class implements several of them at once.

- A concrete class (e.g. `SessionDataSource`, `AuthenticationDataSource`, `SessionRepositoryImpl`) `implements`/extends multiple small interfaces (`ISessionReader`, `ISessionWriter`, `ISocialAuthentication`, `ISessionGateway`, …).
- Domain interfaces live in `lib/domain/repositories/*.dart`. Data-source interfaces live in `lib/data/data_source/interface/*.dart`.
- Consumers (cubits, repositories) depend on the **narrow interface**, never the concrete class. The UI layer must never call APIs directly — always go through a repository.

In `lib/utils/di.dart` this shows up as: register the concrete class once as a lazy singleton, then register each interface it implements as an alias resolving back to the same instance:

```dart
di
  ..registerLazySingleton<AuthenticationDataSource>(() => AuthenticationDataSource(dioClient: di(), resolver: di()))
  ..registerLazySingleton<ISocialAuthentication>(() => di<AuthenticationDataSource>())
  ..registerLazySingleton<ISessionGateway>(() => di<AuthenticationDataSource>());
```

### Data flow: DTO → entity, exceptions → failures

1. **Data source** (`lib/data/data_source/`) calls `DioClient`, deserializes JSON into response DTOs (`lib/data/models/`). `DioClient._handleDioException` translates `DioException`s into typed exceptions: `ServerException` (4xx with a JSON body), `CancellationException` (timeouts/cancel/bad cert), or `InternalException` (everything else, including no-connection).
2. **Repository** (`lib/data/repositories/*_impl.dart`) extends the base `Repository` (`lib/domain/repositories/repository.dart`) and wraps every call in `on(() async {...})`, which catches `ServerException`, `InternalException`, `CancellationException`, `SignInWithAppleAuthorizationException`, `LocationServiceDisabledException`, and `LocationPermissionException`, returning `Either<Failure, T>` (`Left` = failure, `Right` = success). It maps DTOs to domain entities (`lib/domain/entity/`) using extension methods in `lib/data/models/extensions/` (e.g. `session_extension.dart`).
3. **Cubit** consumes the `Either` via `fold` inside a private per-cubit "emitter" mixin (`cubit/<name>/mixin/<name>_emitter.dart`, `part`-included into the cubit file), which emits a loading state, awaits the repository call, then emits an error or success state. There is **no shared/generic loading-helper mixin** — this loading→fold→emit shape is duplicated by convention across ~34 mixin files. When adding a new cubit, copy the pattern from a similar existing feature (e.g. `gear/cubit/gear_list_cubit/mixin/gear_list_emitter.dart`) rather than looking for a common base to extend.

`Either` is a hand-rolled type in `lib/utils/either.dart` (`fold`, `mapLeft`, `mapRight`, `thenLeft`, `thenRight`) — not the `dartz` package. Failures live in `lib/core/networking/failures/` (`Failure`, `ServerFailure`, `InternalFailure`, `CancellationFailure`) and `lib/core/location/failures/` (`LocationPermissionFailure`).

### Networking

`DioClient` (`lib/core/networking/http/dio_client.dart`) wraps `Dio` and is the single source of HTTP requests; it's registered with `registerFactory` (fresh instance per resolve). Interceptors are **not** attached globally — each data source composes only the interceptors it needs via `dioClient.copyWith(interceptors: [...])`, resolved through an `InterceptorResolver` (a `Map<Type, Interceptor>` lookup) passed into its constructor:

```dart
SessionDataSource({required DioClient dioClient, required InterceptorResolver resolver})
  : _dioClient = dioClient.copyWith(
      interceptors: [resolver.resolve<AuthenticationInterceptor>(), resolver.resolve<LanguageInterceptor>()],
    );
```

`AuthenticationInterceptor` (a `QueuedInterceptorsWrapper`, so requests are serialized rather than needing a manual refresh lock) attaches the bearer token in `onRequest` — or closes the session immediately if no token is stored — and on a `401` in `onError` calls `POST /auth/tokens/refresh`, then retries the original request via `_dioClient.fetch(options)`. Note: `AuthenticationInterceptor` itself pulls `CookiesInterceptor` via a direct `di.get<CookiesInterceptor>()` service-locator call inside its own constructor, rather than receiving it as a constructor parameter like every other interceptor dependency — an inconsistency worth knowing about if you touch this file.

### Navigation (AutoRoute)

`lib/presentation/router/app_router.dart` defines the route tree (`@AutoRouterConfig()`, regenerate `app_router.gr.dart` via `build_runner` after edits). Two top-level branches: `AuthenticationWrapperRoute` (login, unguarded) and `MainWrapperRoute` (guarded by `AuthenticationGuard`, folder `router/guardes/` — note the misspelling), which nests the tab-based `MainRoute` (Sessions/Profile/Notification tabs) plus modal/detail routes (`ProfileEditRoute`, `GearSetupRoute`, `SessionDetailsRoute`, etc.). `AuthenticationGuard` first checks `SessionService.isGuest` (bypasses auth entirely for guest mode), then checks `TokenStorage` for a token, redirecting to `AuthenticationWrapperRoute` if neither holds.

Pages implement `AutoRouteWrapper` and provide their cubit in `wrappedRoute`:

```dart
@override
Widget wrappedRoute(BuildContext context) {
  return BlocProvider(create: (_) => di.get<GearSetupListCubit>()..loadGearSetups(), child: this);
}
```

### Dependency Injection

Single `get_it` container `di` in `lib/utils/di.dart`, populated by `initDi()` and organized into `// #region` blocks (Core, External, Interceptors, Data Source, Mappers, Repositories, Blocs).

- **`registerLazySingleton`** for storage, services, interceptors, data sources, and repositories (interfaces alias back to the concrete singleton — see interface-segregation note above).
- **`registerFactory`** for cubits (a fresh instance per screen), or **`registerFactoryParam`** when a cubit needs a runtime value and/or an injected sibling cubit (e.g. `SessionFormCubit` takes `(GeolocatorCubit, SessionTile?)`; `ManageSessionCubit` takes a `SessionFormCubit` plus a nullable session id).
- `AuthenticationRepositoryImpl` is bootstrapped with `registerFactoryAsync` + `await di.getAsync<...>()` because it needs to hydrate stored tokens before anything else resolves it — preserve this ordering if you touch it.
- **Avoid duplicate cubit creation**: provide a cubit in exactly one place — don't create the same cubit in both a page's `wrappedRoute` and a modal sheet shown from that page.

### Theming & UI

Two separate systems, don't mix them up:

- **Dimensions** (`Spacing`, `AppSize`, `AppRadius`) are `ThemeExtension`s registered on `ThemeData.extensions` in `lib/application.dart`, accessed through context extensions in `lib/utils/extensions/theme_spacing.dart`: `context.spacing`, `context.appSize`, `context.appRadius`. Extend these classes for new dimension constants rather than hardcoding numbers.
- **Colors, typography, and image paths** are plain static-const classes in `lib/presentation/component/`, *not* theme extensions: `AppColor` (`color.dart`), `AppImage` (`image.dart`), and `AppFont`/`AppTextStyles` (both in `font.dart` — `AppFont` holds font-family name strings, `AppTextStyles` holds the ready-made `TextStyle` presets built from them; use `AppTextStyles.*` in widgets, not raw `TextStyle`s). Font family is `AvertaStd` (Bold/Semibold/Regular, declared in `pubspec.yaml`).

Many `AppImage` SVG/PNG assets are eagerly preloaded at startup in `lib/utils/images/preload_resources.dart` — add new frequently-used images there.

### Localization

`easy_localization`, but only one locale is actually wired up today: `assets/langs/en-US.json`, registered as the sole `supportedLocales` entry in `lib/main_prod.dart` (the plural `langs` folder name is a leftover from scaffolding, not a sign of multi-language support). Use `'some.dotted.key'.tr()`. After adding/editing keys, run `flutter pub run easy_localization:generate`. Pick the contextually correct nested key for the screen you're on (e.g. `main.profileEdit.validations.emailRequired`) rather than a similarly named sibling key.

## State Management (BLoC/Cubit)

- **Cubit only** — folders are literally named `cubit/`, there is no `Bloc` usage despite the `flutter_bloc` dependency name.
- State is a `sealed class` with `final class` subtypes (e.g. `GearSetupListInitial/Loading/Loaded/Error`), declared in a `*_state.dart` file included via `part` into the cubit file, alongside `part 'mixin/<name>_emitter.dart'` for the private emitter mixin (see Data flow above).
- Use pattern matching / `is` checks on the sealed state — avoid manual enum-based casting.
- Emit **immutable states** only; use `copyWith` for updates.
- **Always dispose resources** — `ValueNotifier`, `StreamController`, `TextEditingController`:

```dart
@override
void dispose() {
  _myValueNotifier.dispose();
  _myStreamController.close();
  super.dispose();
}
```

### Async operations & widget lifecycle

- **Check `mounted`** after an `await` before touching `context` or calling `setState`.
- Context-dependent getters (e.g. `context.read<T>()`) resolve context at call time — cache them **before** the `await`, not after.

```dart
// ❌ Unsafe: context accessed after await via getter
ProfileCubit get _cubit => context.read<ProfileCubit>();

void _onTap() async {
  final result = await someAsyncOperation();
  if (result != null) {
    _cubit.update(result); // accesses context after await
  }
}

// ✅ Safe: cache before await AND check mounted
void _onTap() async {
  final cubit = _cubit;
  final result = await someAsyncOperation();
  if (result != null && mounted) {
    cubit.update(result);
  }
}
```

## Conventions

- `snake_case` file names, `PascalCase` class names; target ≤200 lines per file.
- `always_use_package_imports` is enforced (`analysis_options.yaml`) — use `package:ft_mobile/...`, never relative imports. `implicit-casts`/`implicit-dynamic` are disabled (`strong-mode`).
- `prefer_single_quotes`, `require_trailing_commas`, `prefer_const_constructors` are lints; `unused_import`, `dead_code`, `invalid_assignment` are promoted to **errors** — `flutter analyze` gates every PR.
- **Two folder-naming inconsistencies exist** — follow whatever the feature you're editing already uses, don't "fix" it as a drive-by: singular vs. plural widget folders (`presentation/session/widget` is singular; `presentation/user_invites/widgets` and top-level `presentation/widgets` are plural), and singular vs. plural extension folders (`presentation/profile/extension`, `presentation/authentication/extension` are singular; `presentation/gear/extensions`, `presentation/session/extensions` are plural).
- Generic, business-logic-free helpers and constants go in `lib/utils/` (e.g. `Either`, `AppConfig`, `di`, theme extensions) — no business logic there.
