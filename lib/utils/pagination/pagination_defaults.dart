/// Shared page/limit defaults, matching the backend's own defaults
/// (`page=1`, `limit=20`) so every paginated list starts from the same
/// place without repeating magic numbers per feature.
final class PaginationDefaults {
  const PaginationDefaults._();

  static const int firstPage = 1;
  static const int defaultLimit = 20;
}
