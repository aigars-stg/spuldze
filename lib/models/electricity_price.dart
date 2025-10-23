/// Represents the electricity price for a specific hour.
///
/// Contains the timestamp and price information from the Elering API.
/// Prices are stored in EUR/MWh and can be converted to EUR/kWh for display.
class ElectricityPrice implements Comparable<ElectricityPrice> {
  /// The timestamp for this price point (hour start time)
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
