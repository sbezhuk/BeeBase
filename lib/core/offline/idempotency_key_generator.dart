import 'dart:math';

/// Generates a client-side idempotency token in RFC 4122 v4 UUID format.
///
/// Distinct from [LocalIdGenerator]: that one deliberately produces a
/// `local-`-prefixed, non-UUID string precisely *because* it must never be
/// mistaken for a real backend id. This generator is for the opposite case —
/// a value handed to the server as a legitimate idempotency key — which for
/// most create endpoints travels as an opaque `Idempotency-Key` header (see
/// `IdempotencyKeyHeader`), format-agnostic to the server, so those callers
/// use [LocalIdGenerator.generate] directly. Media's upload endpoint is the
/// exception: its idempotency token travels as the `media_id` *form field*
/// and doubles as the new resource's id, so it has to actually be a
/// well-formed UUID or the server rejects it — see
/// `MediaRepositoryImpl._attachOffline`.
abstract final class IdempotencyKeyGenerator {
  static final _random = Random();

  static String generate() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx
    String hex(int start, int end) =>
        bytes.sublist(start, end).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}
