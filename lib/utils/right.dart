part of 'either.dart';

final class Right<L, R> extends Either<L, R> {
  const Right(this.value);

  final R value;

  @override
  B fold<B>(B Function(L left) onLeft, B Function(R right) onRight) => onRight(value);

  @override
  bool operator ==(Object other) => identical(this, other) || (other is Right<L, R> && other.value == value);

  @override
  int get hashCode => value.hashCode;
}
