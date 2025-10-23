import 'electricity_price.dart';

/// Represents a group of four 15-minute electricity prices for one hour.
///
/// Groups exactly 4 consecutive 15-minute prices (:00, :15, :30, :45)
/// into a single hourly aggregate for simplified display.
class HourlyGroup {
  /// The specific hour (0-23)
  final int hour;

  /// Exactly 4 ElectricityPrice objects for this hour
  /// Ordered by time: :00, :15, :30, :45
  final List<ElectricityPrice> prices;

  /// Creates an [HourlyGroup] with validation.
  ///
  /// Requires exactly 4 prices for the hour.
  HourlyGroup({
    required this.hour,
    required this.prices,
  }) : assert(
          hour >= 0 && hour <= 23,
          'Hour must be between 0 and 23',
        ),
        assert(
          prices.length == 4,
          'HourlyGroup must have exactly 4 prices (:00, :15, :30, :45)',
        );

  /// Average price for this hour in EUR/MWh (with VAT).
  double get averagePrice {
    final sum = prices.fold<double>(
      0.0,
      (sum, price) => sum + price.priceWithVAT,
    );
    return sum / 4;
  }

  /// Average price without VAT in EUR/MWh.
  double get averagePriceNoVAT {
    final sum = prices.fold<double>(
      0.0,
      (sum, price) => sum + price.price,
    );
    return sum / 4;
  }

  /// Minimum price in this hour (with VAT).
  double get minPrice {
    return prices
        .map((p) => p.priceWithVAT)
        .reduce((a, b) => a < b ? a : b);
  }

  /// Maximum price in this hour (with VAT).
  double get maxPrice {
    return prices
        .map((p) => p.priceWithVAT)
        .reduce((a, b) => a > b ? a : b);
  }

  /// The actual price entry with the minimum price.
  ///
  /// Returns the ElectricityPrice object, allowing access to exact timestamp.
  ElectricityPrice get minPriceEntry {
    return prices.reduce(
      (a, b) => a.priceWithVAT < b.priceWithVAT ? a : b,
    );
  }

  /// The actual price entry with the maximum price.
  ///
  /// Returns the ElectricityPrice object, allowing access to exact timestamp.
  ElectricityPrice get maxPriceEntry {
    return prices.reduce(
      (a, b) => a.priceWithVAT > b.priceWithVAT ? a : b,
    );
  }

  /// Display format for the hour: "07:00"
  String get displayHour {
    return '${hour.toString().padLeft(2, '0')}:00';
  }

  /// Display format for hour range: "07:00 - 08:00"
  String get displayHourRange {
    final nextHour = (hour + 1) % 24;
    return '$displayHour - ${nextHour.toString().padLeft(2, '0')}:00';
  }

  /// Returns true if this is the current hour.
  bool get isNowHour {
    final now = DateTime.now();
    return hour == now.hour;
  }

  /// Returns the price for a specific 15-minute interval within this hour.
  ///
  /// [minute] must be 0, 15, 30, or 45.
  /// Returns null if the interval is not found.
  ElectricityPrice? getPriceAtMinute(int minute) {
    if (![0, 15, 30, 45].contains(minute)) {
      return null;
    }

    try {
      return prices.firstWhere((p) => p.timestamp.minute == minute);
    } catch (e) {
      return null;
    }
  }

  /// Returns the average price in EUR/kWh (converted from EUR/MWh).
  double get averagePriceInKWh {
    return averagePrice / 1000;
  }

  /// Returns the formatted average price in EUR/kWh.
  String getFormattedAveragePrice({int decimals = 4}) {
    return averagePriceInKWh.toStringAsFixed(decimals);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is HourlyGroup &&
        other.hour == hour &&
        _listEquals(other.prices, prices);
  }

  /// Helper method to compare two lists of ElectricityPrice
  bool _listEquals(List<ElectricityPrice> a, List<ElectricityPrice> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(hour, Object.hashAll(prices));

  @override
  String toString() {
    return 'HourlyGroup('
        'hour: $displayHour, '
        'avg: ${getFormattedAveragePrice()} EUR/kWh, '
        'min: ${minPriceEntry.formatPrice()} at ${minPriceEntry.timeDisplay}, '
        'max: ${maxPriceEntry.formatPrice()} at ${maxPriceEntry.timeDisplay}'
        ')';
  }

  /// Creates a copy of this [HourlyGroup] with optional field updates.
  HourlyGroup copyWith({
    int? hour,
    List<ElectricityPrice>? prices,
  }) {
    return HourlyGroup(
      hour: hour ?? this.hour,
      prices: prices ?? this.prices,
    );
  }
}
