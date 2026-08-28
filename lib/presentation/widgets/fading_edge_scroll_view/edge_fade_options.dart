final class EdgeFadeOptions {
  const EdgeFadeOptions({
    required this.topFadeHeight,
    required this.bottomFadeHeight,
    this.topFadeValue = 0,
    this.bottomFadeValue = 0,
  });

  final double topFadeHeight;
  final double bottomFadeHeight;
  final double topFadeValue;
  final double bottomFadeValue;

  EdgeFadeOptions copyWith({double? topFadeValue, double? bottomFadeValue}) {
    return EdgeFadeOptions(
      topFadeHeight: topFadeHeight,
      bottomFadeHeight: bottomFadeHeight,
      topFadeValue: topFadeValue ?? this.topFadeValue,
      bottomFadeValue: bottomFadeValue ?? this.bottomFadeValue,
    );
  }
}
