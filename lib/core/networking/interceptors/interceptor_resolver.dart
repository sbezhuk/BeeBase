import 'package:dio/dio.dart';

/// Looks up a registered [Interceptor] instance by its runtime type, so data
/// sources can compose only the interceptors they need without depending on
/// the DI container directly.
final class InterceptorResolver {
  const InterceptorResolver(this._interceptors);

  final Map<Type, Interceptor> _interceptors;

  T resolve<T extends Interceptor>() {
    final interceptor = _interceptors[T];
    if (interceptor == null) {
      throw StateError('No interceptor registered for type $T');
    }
    return interceptor as T;
  }
}
