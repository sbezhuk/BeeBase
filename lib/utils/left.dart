part of 'either.dart';

final class Left<L, R> extends Either<L, R> {
  const Left(this.value);

  final L value;

  @override
  B fold<B>(B Function(L left) onLeft, B Function(R right) onRight) => onLeft(value);

  @override
  bool operator ==(Object other) => identical(this, other) || (other is Left<L, R> && other.value == value);

  @override
  int get hashCode => value.hashCode;
}
