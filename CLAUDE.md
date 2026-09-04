# CLAUDE.md

Guidance for Claude Code when working in this repository.

## 1. Project Overview

This is a Flutter mobile application built with:

* Clean Architecture
* Cubit / `flutter_bloc`
* `get_it` for dependency injection
* Dio for networking
* AutoRoute for navigation
* `json_serializable` for code generation
* Easy Localization for localization
* Flutter `ThemeExtension` for design tokens

### Architecture

Dependencies flow inward:

```text
presentation → domain ← data
                  ↑
                core
```

Responsibilities:

* `presentation` — UI, Cubits, widgets, routing
* `domain` — business entities, enums, repository contracts
* `data` — API clients, DTOs, mappers, repository implementations
* `core` — networking, storage, services, failures
* `utils` — generic utilities, configuration, DI, extensions

Do not put business logic in `utils/`.

---

## 2. Project Structure

```text
lib/
├── core/
│   ├── networking/
│   ├── storage/
│   └── services/
│
├── data/
│   ├── data_source/
│   │   └── interface/
│   ├── models/
│   │   ├── extensions/
│   │   └── ...
│   └── repositories/
│
├── domain/
│   ├── entity/
│   ├── enum/
│   └── repositories/
│
├── presentation/
│   ├── <feature>/
│   │   ├── cubit/
│   │   ├── widget(s)/
│   │   └── extension(s)/
│   ├── component/
│   ├── widgets/
│   └── router/
│
├── utils/
│   ├── extensions/
│   ├── images/
│   ├── themes/
│   ├── di.dart
│   ├── either.dart
│   └── app_config.dart
│
├── application.dart
└── main.dart
```

Follow the existing structure of the feature being modified. Do not reorganize folders unless explicitly requested.

---

## 3. Entry Point & Configuration

The application uses a **single `main.dart` entry point**.

```text
lib/main.dart
```

There are **no Flutter flavors**.

Environment-specific configuration is provided through Dart compile-time variables using `--dart-define-from-file`.

Configuration should be stored in environment-specific JSON files when applicable:

```text
config/
├── development.json
├── staging.json
└── production.json
```

Example configuration:

```json
{
  "API_END_POINT": "https://api.example.com",
  "MAPBOX_PUBLIC_KEY": "your-key",
  "ENVIRONMENT": "development"
}
```

Run the application with:

```bash
flutter run --dart-define-from-file=config/development.json
```

Build with:

```bash
flutter build apk --dart-define-from-file=config/production.json
```

Typical configuration values include:

```text
API_END_POINT
MAPBOX_PUBLIC_KEY
APPLE_*
GOOGLE_*
ENVIRONMENT
```

`AppConfig` must read configuration from Dart compile-time environment variables using:

```dart
String.fromEnvironment(...)
bool.fromEnvironment(...)
int.fromEnvironment(...)
```

Use the appropriate type for each configuration value.

Do not hardcode environment-specific configuration in the source code.

Do not introduce Flutter flavors or additional environment configuration mechanisms unless explicitly requested.

### Application Startup

The startup flow is:

```text
main.dart
   ↓
EasyLocalization
   ↓
AppConfig
   ↓
Dependency Injection
   ↓
Asset Preloading
   ↓
Mapbox Configuration
   ↓
application.dart
   ↓
runApp()
```

---

# 4. Essential Commands

## Install dependencies

```bash
flutter pub get
```

## Run

Use the single `main.dart` entry point together with `--dart-define-from-file`.

Development:

```bash
flutter run --dart-define-from-file=config/development.json
```

Staging:

```bash
flutter run --dart-define-from-file=config/staging.json
```

Production:

```bash
flutter run --dart-define-from-file=config/production.json
```

Use the project's existing configuration files when available.

Do not duplicate environment values directly in command-line arguments when a configuration file already exists.

## Format

```bash
dart format .
```

## Analyze

```bash
flutter analyze
```

`flutter analyze` must pass without errors before considering a task complete.

## Code generation

Run after changing:

* AutoRoute routes
* `@JsonSerializable` models
* JSON enums
* generated DI-related code
* other code-generation annotations

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

For continuous generation:

```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

## Localization generation

After changing:

```text
assets/langs/en-US.json
```

run:

```bash
flutter pub run easy_localization:generate
```

## Build

Use the same `main.dart` entry point and the appropriate configuration file.

Android:

```bash
flutter build apk --dart-define-from-file=config/production.json
```

iOS:

```bash
flutter build ios --dart-define-from-file=config/production.json
```

Use the appropriate configuration file for the target environment.

---

# 5. Generated Files

Never manually edit generated files.

Examples:

```text
*.g.dart
*.gr.dart
```

Regenerate them using `build_runner`.

Generated files are disposable artifacts and should never contain manually maintained business logic.

---

# 6. Data Flow

API-backed features follow this flow:

```text
API
 ↓
Data Source
 ↓
DTO
 ↓
Mapper
 ↓
Repository
 ↓
Either<Failure, Entity>
 ↓
Cubit
 ↓
UI
```

The presentation layer must never communicate directly with an API.

---

# 7. Data Sources

Data sources are responsible for:

* HTTP communication
* request/response handling
* DTO deserialization
* communicating through `DioClient`

Data sources belong under:

```text
lib/data/data_source/
```

Use narrow interfaces where applicable:

```text
lib/data/data_source/interface/
```

Consumers should depend on the smallest required interface.

Do not expose raw API responses to the domain or presentation layers.

---

# 8. DTOs & Mapping

DTOs belong under:

```text
lib/data/models/
```

Use `json_serializable` for JSON serialization.

DTO → entity conversion belongs under:

```text
lib/data/models/extensions/
```

Keep domain entities independent from API DTOs.

Do not use API DTOs directly in presentation code.

---

# 9. Repositories

Repository contracts belong under:

```text
lib/domain/repositories/
```

Implementations belong under:

```text
lib/data/repositories/
```

Repositories are responsible for:

* calling data sources
* converting DTOs into entities
* converting exceptions into failures
* returning `Either<Failure, T>`

Use the existing base repository mechanism:

```text
lib/domain/repositories/repository.dart
```

Repository operations should follow the existing `on(() async {...})` error-handling pattern.

Do not introduce a second repository error-handling abstraction without a strong reason.

---

# 10. Interface Segregation

The project intentionally uses narrow reader/writer interfaces.

A concrete implementation may implement multiple interfaces:

```text
AuthenticationDataSource
├── ISocialAuthentication
├── ISessionGateway
└── ...
```

Consumers should depend on the narrowest interface required.

Do not depend on a concrete data source or repository when an appropriate interface already exists.

### Dependency Injection Pattern

Register the concrete implementation once:

```dart
di.registerLazySingleton<AuthenticationDataSource>(
  () => AuthenticationDataSource(
    dioClient: di(),
    resolver: di(),
  ),
);
```

Register implemented interfaces as aliases:

```dart
di.registerLazySingleton<ISocialAuthentication>(
  () => di<AuthenticationDataSource>(),
);

di.registerLazySingleton<ISessionGateway>(
  () => di<AuthenticationDataSource>(),
);
```

Follow this pattern for new reader/writer interfaces.

---

# 11. Error Handling

Networking errors follow this flow:

```text
DioException
 ↓
DioClient
 ↓
Exception
 ↓
Repository
 ↓
Failure
 ↓
Cubit
 ↓
UI
```

Known exception types include:

```text
ServerException
InternalException
CancellationException
```

Failures are located under:

```text
lib/core/networking/failures/
lib/core/location/failures/
```

Do not expose networking exceptions directly to the presentation layer.

The UI should operate on domain/application-level failures.

---

# 12. Networking

`DioClient` is the single HTTP entry point.

```text
lib/core/networking/http/dio_client.dart
```

Do not instantiate or use raw `Dio` directly from data sources.

Interceptors are composed per data source using `DioClient.copyWith(...)`.

Example:

```dart
dioClient.copyWith(
  interceptors: [
    resolver.resolve<AuthenticationInterceptor>(),
    resolver.resolve<LanguageInterceptor>(),
  ],
);
```

Only attach interceptors required by the specific data source.

### Authentication

`AuthenticationInterceptor` is responsible for:

* attaching bearer tokens
* handling unauthorized responses
* refreshing tokens
* retrying failed requests

It uses `QueuedInterceptorsWrapper`.

Preserve the existing token refresh and retry behavior when modifying authentication networking.

---

# 13. State Management

Use **Cubit only**.

Do not introduce `Bloc` unless explicitly requested.

Typical structure:

```text
feature/
└── cubit/
    └── feature_cubit/
        ├── feature_cubit.dart
        ├── state/
        │   ├── feature_initial.dart
        │   ├── feature_loading.dart
        │   ├── feature_loaded.dart
        │   └── feature_error.dart
        └── mixin/
            └── feature_emitter.dart
```

States use sealed classes:

```dart
sealed class FeatureState {}
```

Variants:

```dart
final class FeatureInitial extends FeatureState {}

final class FeatureLoading extends FeatureState {}

final class FeatureLoaded extends FeatureState {}

final class FeatureError extends FeatureState {}
```

Use pattern matching or type checks on sealed states.

Avoid manual enum-based state management.

States must be immutable.

Use `copyWith` for state updates.

---

# 14. Cubit Emitter Pattern

Existing Cubits use private emitter mixins.

There is intentionally no generic loading/fold/emit helper.

When creating a new Cubit:

1. Find an existing Cubit with similar behavior.
2. Follow its structure.
3. Reuse the existing emitter pattern.
4. Do not introduce a new generic abstraction unless required.

Consistency with existing Cubits is preferred over theoretical architectural improvements.

---

# 15. Cubit Lifecycle

Dispose every resource owned by a Cubit.

Examples:

```dart
@override
void dispose() {
  _valueNotifier.dispose();
  _streamController.close();
  _textController.dispose();
  super.dispose();
}
```

Dispose:

* `ValueNotifier`
* `StreamController`
* `TextEditingController`
* stream subscriptions
* other disposable resources

Never leave owned resources undisposed.

---

# 16. Dependency Injection

DI is centralized in:

```text
lib/utils/di.dart
```

The project uses `get_it`.

### Registration Rules

Use `registerLazySingleton` for long-lived dependencies such as:

* storage
* services
* interceptors
* data sources
* repositories

Use `registerFactory` for short-lived objects such as:

* Cubits
* screen-specific dependencies

Use `registerFactoryParam` when runtime parameters are required.

Avoid duplicate Cubit creation.

A Cubit should be provided in one clearly defined location.

### Authentication Repository

`AuthenticationRepositoryImpl` is initialized asynchronously because stored tokens must be hydrated before the repository is used.

Preserve the existing initialization order when modifying DI.

---

# 17. Navigation

Navigation uses AutoRoute.

Main configuration:

```text
lib/presentation/router/app_router.dart
```

After modifying routes, regenerate:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Protected routes use:

```text
AuthenticationGuard
```

Pages that own Cubits should normally provide them through `AutoRouteWrapper`.

Example:

```dart
@override
Widget wrappedRoute(BuildContext context) {
  return BlocProvider(
    create: (_) => di<FeatureCubit>(),
    child: this,
  );
}
```

Do not create the same Cubit in multiple places.

---

# 18. Theming & Design System

Do not hardcode reusable design values in widgets.

The project uses `ThemeExtension` for design tokens.

## Dimensions

Use:

```dart
context.spacing
context.appSize
context.appRadius
```

Add new reusable dimensions to the existing theme extensions instead of hardcoding values.

## Colors

Use:

```dart
context.colors
```

Do not use static color constants directly in widgets.

New colors must support both light and dark themes and implement the required `copyWith` / `lerp` behavior.

## Typography

Use:

```dart
context.textStyles
```

Do not create arbitrary reusable `TextStyle`s inside widgets.

New text styles belong in `AppTextStyles`.

## New Theme Extensions

When introducing a new themed design token:

1. Create a `ThemeExtension`.
2. Provide light and dark values.
3. Register it in the theme.
4. Add a context extension.
5. Use the context extension from UI code.

Use the existing generic theme-extension helper.

Do not duplicate:

```dart
Theme.of(context).extension<T>() ?? fallback
```

throughout the project.

---

# 19. Images & Assets

Image constants are defined in:

```text
lib/presentation/component/image.dart
```

Use `AppImage`.

Frequently used assets may be preloaded through:

```text
lib/utils/images/preload_resources.dart
```

Add newly introduced frequently-used assets to the preload list when appropriate.

Do not introduce duplicate asset path constants.

---

# 20. Localization

Localization uses `easy_localization`.

Currently the application uses:

```text
assets/langs/en-US.json
```

Use:

```dart
'some.dotted.key'.tr()
```

Every user-facing string must be localized.

This includes:

* labels
* buttons
* validation messages
* error messages
* snackbars
* empty states
* server error mappings
* permission messages

Never add hardcoded user-facing English strings.

Use the most context-specific localization key available.

Example:

```text
main.profileEdit.validations.emailRequired
```

After changing localization files:

```bash
flutter pub run easy_localization:generate
```

---

# 21. JSON Enums

Enums crossing the API boundary must use `json_serializable` code generation.

For backend values using `SCREAMING_SNAKE_CASE`:

```dart
@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum InspectionType {
  routine,
  queen,
}
```

Do not manually create enum serialization maps:

```dart
Map<Enum, String>
```

Do not manually implement `fromJson` / `toJson` when standard code generation can handle the mapping.

Use `@JsonValue` only when an individual wire value does not follow the enum's general naming convention.

Client-only enums that never cross the API boundary do not require JSON annotations.

Regenerate code after changing serialized enums:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

# 22. Code Style

Follow the existing Dart lint configuration.

General rules:

* `snake_case` filenames
* `PascalCase` classes
* `camelCase` members
* prefer `const`
* prefer single quotes
* use trailing commas
* use package imports
* avoid unnecessary nesting
* keep files reasonably small
* keep widgets focused
* keep business logic outside widgets

Use:

```dart
import 'package:ft_mobile/...';
```

Do not use relative imports.

---

# 23. One Class Per File

Prefer one class per file.

Keep sealed class hierarchies together using `part` / `part of` when required by Dart library rules.

A `StatefulWidget` and its corresponding `State<T>` may remain in the same file.

Do not split classes mechanically when doing so reduces readability.

---

# 24. Class Modifiers

Mark classes `final` by default.

Use another modifier only when the class is intentionally designed for inheritance or implementation:

```text
abstract
base
interface
sealed
```

### Testing Exception

Classes mocked externally with Mocktail cannot be `final` if they are used like:

```dart
class MockFeature extends Mock implements Feature {}
```

Keep such types implementable when required by the test architecture.

---

# 25. UI Composition

Avoid large or deeply nested `build()` methods.

Prefer extracting meaningful sections into private widgets:

```dart
class _Header extends StatelessWidget {
  const _Header();
}
```

Prefer private widgets when a section:

* has its own responsibility
* contains multiple widgets
* can rebuild independently
* improves readability

Use `_buildX()` methods only for small/trivial fragments.

Do not allow a single `build()` method to become difficult to understand.

---

# 26. Existing Naming Inconsistencies

Some legacy folder naming inconsistencies exist:

```text
widget/
widgets/

extension/
extensions/
```

Do not fix these as part of an unrelated task.

When modifying an existing feature, follow that feature's current naming convention.

Only perform broad renaming/refactoring when explicitly requested.

---

# 27. Testing

When changing behavior:

* update existing tests where necessary
* add tests for new business logic
* preserve existing test patterns
* avoid testing implementation details unnecessarily

Prefer testing:

* Cubit state transitions
* repository behavior
* mappers
* validation
* business rules
* error handling

Do not add tests merely to increase coverage without meaningful behavioral value.

---

# 28. Git & PR Checklist

Before considering a task complete:

1. Implement only the requested change.
2. Follow the existing architecture.
3. Reuse existing components and abstractions.
4. Avoid unnecessary refactoring.
5. Remove unused code introduced by the change.
6. Regenerate generated files when required.
7. Format the code.
8. Run static analysis.
9. Run relevant tests when applicable.
10. Do not manually modify generated files.
11. Do not modify unrelated functionality.

Required checks:

```bash
dart format .
flutter analyze
```

Run tests relevant to the modified functionality.

---

# 29. General Rules for Claude

When working on this repository:

### Before coding

* Inspect the existing implementation.
* Find a similar feature if one exists.
* Understand how the current architecture solves the problem.
* Reuse existing components, services, extensions and abstractions.

### While coding

* Make the smallest clean change that solves the task.
* Preserve existing behavior unless explicitly asked to change it.
* Follow the surrounding feature's conventions.
* Prefer existing abstractions over creating new ones.
* Keep business logic in the appropriate architectural layer.
* Do not introduce unnecessary dependencies.
* Do not introduce new architectural patterns without justification.
* Do not duplicate existing functionality.

### Avoid

* drive-by refactoring
* unrelated formatting changes
* unnecessary file renaming
* duplicate services or repositories
* duplicate Cubits
* hardcoded user-facing strings
* hardcoded theme values
* direct API calls from UI
* manually edited generated files
* unnecessary abstractions
* new dependencies when an existing solution is sufficient

### When architecture is unclear

Search the repository for an existing implementation of the same or similar problem and follow that pattern.

Consistency with the existing codebase is preferred over introducing a theoretically cleaner but inconsistent solution.

### Final principle

> Make the smallest clean change that solves the requested task while preserving the existing architecture, conventions and behavior.
