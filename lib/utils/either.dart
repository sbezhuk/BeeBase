part 'left.dart';
part 'right.dart';

/// A hand-rolled Either type: [Left] represents failure, [Right] success.
sealed class Either<L, R> {
  const Either();

  B fold<B>(B Function(L left) onLeft, B Function(R right) onRight);

  bool get isLeft => this is Left<L, R>;

  bool get isRight => this is Right<L, R>;

  Either<L, R2> mapRight<R2>(R2 Function(R right) f) {
    return fold((left) => Left(left), (right) => Right(f(right)));
  }

  Either<L2, R> mapLeft<L2>(L2 Function(L left) f) {
    return fold((left) => Left(f(left)), (right) => Right(right));
  }

  Either<L, R2> thenRight<R2>(Either<L, R2> Function(R right) f) {
    return fold((left) => Left(left), f);
  }

  Either<L2, R> thenLeft<L2>(Either<L2, R> Function(L left) f) {
    return fold(f, (right) => Right(right));
  }
}
