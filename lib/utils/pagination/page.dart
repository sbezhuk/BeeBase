/// A generic accumulated paginated result: not "this page's items" but
/// "everything known so far, plus whether more can be fetched." Deliberately
/// carries no `page`/`limit`/`total` — a caller that needs page bookkeeping
/// (e.g. which page to request next) owns that itself; this type only
/// carries what every paginated list screen needs to render.
final class Page<T> {
  const Page({required this.items, required this.hasNext});

  final List<T> items;
  final bool hasNext;
}
