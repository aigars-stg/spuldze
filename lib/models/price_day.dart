import 'electricity_price.dart';
import 'hourly_group.dart';

/// Represents electricity prices for a full day.
///
/// Contains a list of 15-minute interval electricity prices (96 per day)
/// and provides convenient methods to analyze and group the price data.
/// Can group 96 prices into 24 hourly aggregates for simplified display.
class PriceDay {
  /// The list of electricity prices for this day (96 for 15-min intervals, or 24 for hourly)
  final List<ElectricityPrice> prices;

  /// The date this price data is for (normalized to midnight)
  final DateTime date;

  /// Creates a [PriceDay] instance.
  ///
  /// [prices] - List of hourly electricity prices
  /// [date] - Optional date override. If not provided, uses the date
  ///          from the first price in the list.
  PriceDay({
    required this.prices,
    DateTime? date,
  }) : date = date ?? _normalizeDateToMidnight(prices.isNotEmpty
          ? prices.first.timestamp
          : DateTime.now());

  /// Normalizes a DateTime to midnight (00:00:00)
  static DateTime _normalizeDateToMidnight(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  /// Creates a [PriceDay] from a JSON map.
  ///
  /// Expected JSON format:
  /// ```json
  /// {
  ///   "prices": [
  ///     {"timestamp": 1234567890, "price": 45.67},
  ///     {"timestamp": 1234571490, "price": 48.23}
  ///   ]
  /// }
  /// ```
  factory PriceDay.fromJson(Map<String, dynamic> json) {
    final pricesJson = json['prices'] as List<dynamic>;
    final prices = pricesJson
        .map((priceJson) => ElectricityPrice.fromJson(priceJson as Map<String, dynamic>))
        .toList()
      ..sort(); // Sort chronologically

    return PriceDay(prices: prices);
  }

  /// Converts this [PriceDay] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'prices': prices.map((price) => price.toJson()).toList(),
    };
  }

  /// Returns true if this price data is empty.
  bool get isEmpty => prices.isEmpty;

  /// Returns true if this price data is not empty.
  bool get isNotEmpty => prices.isNotEmpty;

  /// Returns the number of price intervals in this day (96 for 15-min, 24 for hourly).
  int get priceCount => prices.length;

  /// Returns the number of hourly prices in this day (for backward compatibility).
  @Deprecated('Use priceCount instead. This assumes 24 hours which may not be accurate for 15-min data.')
  int get hourCount => prices.length;

  /// Groups 15-minute interval prices into 24 hourly groups.
  ///
  /// Each [HourlyGroup] contains exactly 4 prices (:00, :15, :30, :45)
  /// for that hour. If the data doesn't have complete 15-minute intervals,
  /// hours with incomplete data will be omitted.
  ///
  /// Returns a list of [HourlyGroup] objects, one for each hour (0-23).
  /// The list may have fewer than 24 items if some hours are missing data.
  List<HourlyGroup> get groupedByHour {
    final groups = <HourlyGroup>[];

    for (int hour = 0; hour < 24; hour++) {
      // Find all prices for this hour
      final hourPrices = prices
          .where((p) => p.timestamp.hour == hour)
          .toList()
        ..sort(); // Ensure chronological order

      // Only create a group if we have exactly 4 prices (complete hour)
      if (hourPrices.length == 4) {
        groups.add(HourlyGroup(
          hour: hour,
          prices: hourPrices,
        ));
      } else if (hourPrices.isNotEmpty) {
        // Log incomplete data for debugging
        // In production, you might want to handle this differently
        // e.g., still create the group with partial data
      }
    }

    return groups;
  }

  /// Gets the hourly group for a specific hour (0-23).
  ///
  /// Returns null if the hour doesn't have complete 15-minute data.
  HourlyGroup? getHourlyGroup(int hour) {
    if (hour < 0 || hour > 23) return null;

    try {
      return groupedByHour.firstWhere((g) => g.hour == hour);
    } catch (e) {
      return null;
    }
  }

  /// Gets the average price for a specific hour (0-23).
  ///
  /// Averages the 4 x 15-minute prices for that hour.
  /// Returns null if the hour doesn't have complete data.
  double? getHourlyAveragePrice(int hour, {bool includeVAT = true}) {
    final group = getHourlyGroup(hour);
    if (group == null) return null;

    return includeVAT ? group.averagePrice : group.averagePriceNoVAT;
  }

  /// Gets the minimum price for the day.
  ///
  /// [includeVAT] - Whether to consider prices with VAT (default: true)
  /// Returns null if there are no prices.
  ElectricityPrice? getMinPrice({bool includeVAT = true}) {
    if (prices.isEmpty) return null;

    return prices.reduce((curr, next) =>
        curr.compareByPrice(next, includeVAT: includeVAT) <= 0 ? curr : next);
  }

  /// Gets the maximum price for the day.
  ///
  /// [includeVAT] - Whether to consider prices with VAT (default: true)
  /// Returns null if there are no prices.
  ElectricityPrice? getMaxPrice({bool includeVAT = true}) {
    if (prices.isEmpty) return null;

    return prices.reduce((curr, next) =>
        curr.compareByPrice(next, includeVAT: includeVAT) >= 0 ? curr : next);
  }

  /// Calculates the average price for the day.
  ///
  /// [includeVAT] - Whether to calculate with VAT included (default: true)
  /// Returns null if there are no prices.
  double? getAveragePrice({bool includeVAT = true}) {
    if (prices.isEmpty) return null;

    final sum = prices.fold<double>(
      0.0,
      (sum, price) => sum + (includeVAT ? price.priceWithVAT : price.price),
    );

    return sum / prices.length;
  }

  /// Gets the formatted average price in EUR/kWh.
  ///
  /// [includeVAT] - Whether to include VAT (default: true)
  /// [decimals] - Number of decimal places (default: 4)
  /// Returns null if there are no prices.
  String? getFormattedAveragePrice({
    bool includeVAT = true,
    int decimals = 4,
  }) {
    final avg = getAveragePrice(includeVAT: includeVAT);
    if (avg == null) return null;

    final avgInKWh = avg / 1000; // Convert EUR/MWh to EUR/kWh
    return avgInKWh.toStringAsFixed(decimals);
  }

  /// Gets the price for the current 15-minute interval.
  ///
  /// Rounds current time to nearest 15-minute interval (00, 15, 30, 45)
  /// and returns the matching price.
  /// Returns null if no price data exists for the current interval.
  ElectricityPrice? getCurrentPrice() {
    if (prices.isEmpty) return null;

    final now = DateTime.now();
    // Round to nearest 15-minute interval
    final rounded15Min = (now.minute ~/ 15) * 15;

    try {
      return prices.firstWhere(
        (price) =>
            price.timestamp.hour == now.hour &&
            price.timestamp.minute == rounded15Min &&
            price.timestamp.day == now.day,
      );
    } catch (e) {
      return null;
    }
  }

  /// Gets the price for the current hour (first interval :00).
  ///
  /// Returns null if no price data exists for the current hour.
  /// Note: For 15-minute data, use [getCurrentPrice] for more precision.
  @Deprecated('Use getCurrentPrice() for accurate 15-minute interval prices')
  ElectricityPrice? getCurrentHourPrice() {
    if (prices.isEmpty) return null;

    final now = DateTime.now();
    final currentHour = DateTime(now.year, now.month, now.day, now.hour);

    try {
      return prices.firstWhere(
        (price) {
          final priceHour = DateTime(
            price.timestamp.year,
            price.timestamp.month,
            price.timestamp.day,
            price.timestamp.hour,
          );
          return priceHour == currentHour;
        },
      );
    } catch (e) {
      return null;
    }
  }

  /// Gets the price for a specific hour (0-23).
  ///
  /// [hour] - Hour of the day (0-23)
  /// Returns null if no price exists for that hour.
  ElectricityPrice? getPriceAtHour(int hour) {
    if (hour < 0 || hour > 23 || prices.isEmpty) return null;

    try {
      return prices.firstWhere(
        (price) => price.timestamp.hour == hour,
      );
    } catch (e) {
      return null;
    }
  }

  /// Checks if this price data is for today.
  ///
  /// Compares the date of the first price with today's date.
  bool isToday() {
    if (prices.isEmpty) return false;

    final today = _normalizeDateToMidnight(DateTime.now());
    return date == today;
  }

  /// Checks if this price data is for tomorrow.
  ///
  /// Compares the date of the first price with tomorrow's date.
  bool isTomorrow() {
    if (prices.isEmpty) return false;

    final tomorrow = _normalizeDateToMidnight(
      DateTime.now().add(const Duration(days: 1)),
    );
    return date == tomorrow;
  }

  /// Checks if this price data is for yesterday.
  bool isYesterday() {
    if (prices.isEmpty) return false;

    final yesterday = _normalizeDateToMidnight(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    return date == yesterday;
  }

  /// Gets prices within a specific hour range.
  ///
  /// [startHour] - Start hour (0-23, inclusive)
  /// [endHour] - End hour (0-23, inclusive)
  /// Returns a list of prices within the specified range.
  List<ElectricityPrice> getPricesInRange({
    required int startHour,
    required int endHour,
  }) {
    if (startHour < 0 || startHour > 23 || endHour < 0 || endHour > 23) {
      return [];
    }

    return prices.where((price) {
      final hour = price.timestamp.hour;
      if (startHour <= endHour) {
        return hour >= startHour && hour <= endHour;
      } else {
        // Handle ranges that span midnight (e.g., 22-2)
        return hour >= startHour || hour <= endHour;
      }
    }).toList();
  }

  /// Gets the cheapest consecutive hours.
  ///
  /// [duration] - Number of consecutive hours to find
  /// [includeVAT] - Whether to consider prices with VAT (default: true)
  /// Returns a list of prices for the cheapest consecutive period, or null if not found.
  List<ElectricityPrice>? getCheapestConsecutiveHours({
    required int duration,
    bool includeVAT = true,
  }) {
    if (duration <= 0 || duration > prices.length) return null;

    double minSum = double.infinity;
    int minIndex = 0;

    for (int i = 0; i <= prices.length - duration; i++) {
      final sum = prices
          .skip(i)
          .take(duration)
          .fold<double>(
            0.0,
            (sum, price) => sum + (includeVAT ? price.priceWithVAT : price.price),
          );

      if (sum < minSum) {
        minSum = sum;
        minIndex = i;
      }
    }

    return prices.skip(minIndex).take(duration).toList();
  }

  /// Gets a summary of the day's price statistics.
  ///
  /// [includeVAT] - Whether to include VAT in calculations (default: true)
  Map<String, dynamic> getSummary({bool includeVAT = true}) {
    if (prices.isEmpty) {
      return {
        'isEmpty': true,
        'hourCount': 0,
      };
    }

    final min = getMinPrice(includeVAT: includeVAT);
    final max = getMaxPrice(includeVAT: includeVAT);
    final avg = getAveragePrice(includeVAT: includeVAT);

    return {
      'isEmpty': false,
      'hourCount': hourCount,
      'date': date.toIso8601String(),
      'isToday': isToday(),
      'isTomorrow': isTomorrow(),
      'minPrice': min?.getPriceInKWh(includeVAT: includeVAT),
      'maxPrice': max?.getPriceInKWh(includeVAT: includeVAT),
      'averagePrice': avg != null ? avg / 1000 : null,
      'minPriceTime': min?.timestamp.toIso8601String(),
      'maxPriceTime': max?.timestamp.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PriceDay &&
        other.date == date &&
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
  int get hashCode => Object.hash(date, Object.hashAll(prices));

  @override
  String toString() {
    final avg = getFormattedAveragePrice();
    final min = getMinPrice();
    final max = getMaxPrice();

    return 'PriceDay('
        'date: ${date.toString().split(' ')[0]}, '
        'hours: $hourCount, '
        'avg: ${avg ?? 'N/A'} EUR/kWh, '
        'range: ${min?.formatPrice() ?? 'N/A'} - ${max?.formatPrice() ?? 'N/A'} EUR/kWh'
        ')';
  }

  /// Creates a copy of this [PriceDay] with optional field updates.
  PriceDay copyWith({
    List<ElectricityPrice>? prices,
    DateTime? date,
  }) {
    return PriceDay(
      prices: prices ?? this.prices,
      date: date ?? this.date,
    );
  }
}
