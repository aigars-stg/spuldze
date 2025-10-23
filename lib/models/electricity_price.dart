/// Represents the electricity price for a specific time interval.
///
/// Contains the timestamp and price information from the Elering API.
/// Supports both hourly and 15-minute interval data (00, 15, 30, 45 minutes).
/// Prices are stored in EUR/MWh and can be converted to EUR/kWh for display.
class ElectricityPrice implements Comparable<ElectricityPrice> {
  /// The timestamp for this price point (exact time with 15-minute precision)
  final DateTime timestamp;

  /// The base electricity price in EUR/MWh (without VAT)
  final double price;

  /// The electricity price including VAT in EUR/MWh
  final double priceWithVAT;

  /// Creates an [ElectricityPrice] instance.
  ///
  /// All parameters are required and cannot be null.
  const ElectricityPrice({
    required this.timestamp,
    required this.price,
    required this.priceWithVAT,
  });

  /// Creates an [ElectricityPrice] from a JSON map.
  ///
  /// Expected JSON format from Elering API:
  /// ```json
  /// {
  ///   "timestamp": 1234567890,  // Unix timestamp in seconds
  ///   "price": 45.67            // Price in EUR/MWh
  /// }
  /// ```
  ///
  /// The VAT rate is calculated at 21% (Latvia's standard VAT rate).
  factory ElectricityPrice.fromJson(Map<String, dynamic> json) {
    final timestamp = json['timestamp'] as int;
    final price = (json['price'] as num).toDouble();

    // Latvia VAT rate: 21%
    const vatRate = 1.21;
    final priceWithVAT = price * vatRate;

    return ElectricityPrice(
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
      price: price,
      priceWithVAT: priceWithVAT,
    );
  }

  /// Converts this [ElectricityPrice] to a JSON map.
  ///
  /// Returns a map that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
      'price': price,
      'priceWithVAT': priceWithVAT,
    };
  }

  /// Formats the price in EUR/kWh with 4 decimal places.
  ///
  /// Converts from EUR/MWh to EUR/kWh (divides by 1000) and formats
  /// with exactly 4 decimal places.
  ///
  /// Example:
  /// ```dart
  /// final price = ElectricityPrice(
  ///   timestamp: DateTime.now(),
  ///   price: 45.6789,
  ///   priceWithVAT: 55.2714,
  /// );
  /// print(price.formatPrice());  // "0.0457"
  /// ```
  String formatPrice({bool includeVAT = true}) {
    final priceValue = includeVAT ? priceWithVAT : price;
    final priceInKWh = priceValue / 1000; // Convert EUR/MWh to EUR/kWh
    return priceInKWh.toStringAsFixed(4);
  }

  /// Formats the price in EUR/kWh with a specified number of decimal places.
  ///
  /// [decimals] - Number of decimal places (default: 4)
  /// [includeVAT] - Whether to include VAT in the price (default: true)
  String formatPriceWithDecimals({int decimals = 4, bool includeVAT = true}) {
    final priceValue = includeVAT ? priceWithVAT : price;
    final priceInKWh = priceValue / 1000;
    return priceInKWh.toStringAsFixed(decimals);
  }

  /// Gets the price in EUR/kWh (converted from EUR/MWh).
  ///
  /// [includeVAT] - Whether to include VAT in the price (default: true)
  double getPriceInKWh({bool includeVAT = true}) {
    final priceValue = includeVAT ? priceWithVAT : price;
    return priceValue / 1000;
  }

  /// Returns the time in HH:mm format (e.g., "07:15", "14:45", "23:30").
  ///
  /// Useful for displaying exact 15-minute intervals in the UI.
  /// Format preserves leading zeros for hours 00-09.
  ///
  /// Example:
  /// ```dart
  /// final price = ElectricityPrice(
  ///   timestamp: DateTime(2025, 10, 23, 7, 15),
  ///   price: 45.67,
  ///   priceWithVAT: 55.27,
  /// );
  /// print(price.timeDisplay);  // "07:15"
  /// ```
  String get timeDisplay {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Compares this price with another for sorting.
  ///
  /// Prices are compared by their timestamp (chronological order).
  /// Returns:
  /// - negative value if this comes before other
  /// - zero if timestamps are equal
  /// - positive value if this comes after other
  @override
  int compareTo(ElectricityPrice other) {
    return timestamp.compareTo(other.timestamp);
  }

  /// Compares this price with another based on price value.
  ///
  /// Useful for finding min/max prices.
  /// [includeVAT] - Whether to compare prices with VAT (default: true)
  int compareByPrice(ElectricityPrice other, {bool includeVAT = true}) {
    final thisPrice = includeVAT ? priceWithVAT : price;
    final otherPrice = includeVAT ? other.priceWithVAT : other.price;
    return thisPrice.compareTo(otherPrice);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ElectricityPrice &&
        other.timestamp == timestamp &&
        other.price == price &&
        other.priceWithVAT == priceWithVAT;
  }

  @override
  int get hashCode => Object.hash(timestamp, price, priceWithVAT);

  @override
  String toString() {
    return 'ElectricityPrice('
        'timestamp: $timestamp, '
        'price: ${formatPrice(includeVAT: false)} EUR/kWh, '
        'priceWithVAT: ${formatPrice(includeVAT: true)} EUR/kWh'
        ')';
  }

  /// Creates a copy of this [ElectricityPrice] with optional field updates.
  ElectricityPrice copyWith({
    DateTime? timestamp,
    double? price,
    double? priceWithVAT,
  }) {
    return ElectricityPrice(
      timestamp: timestamp ?? this.timestamp,
      price: price ?? this.price,
      priceWithVAT: priceWithVAT ?? this.priceWithVAT,
    );
  }
}
