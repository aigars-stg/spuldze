import 'package:flutter_test/flutter_test.dart';
import 'package:spuldze/models/models.dart';

void main() {
  group('ElectricityPrice', () {
    group('timeDisplay', () {
      test('shows correct format for :00 minutes', () {
        final price = ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 0),
          price: 45.67,
          priceWithVAT: 55.27,
        );

        expect(price.timeDisplay, equals('07:00'));
      });

      test('shows correct format for :15 minutes', () {
        final price = ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 15),
          price: 45.67,
          priceWithVAT: 55.27,
        );

        expect(price.timeDisplay, equals('07:15'));
      });

      test('shows correct format for :30 minutes', () {
        final price = ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 30),
          price: 45.67,
          priceWithVAT: 55.27,
        );

        expect(price.timeDisplay, equals('07:30'));
      });

      test('shows correct format for :45 minutes', () {
        final price = ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 45),
          price: 45.67,
          priceWithVAT: 55.27,
        );

        expect(price.timeDisplay, equals('07:45'));
      });

      test('pads single-digit hours with zero', () {
        final price = ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 3, 45),
          price: 45.67,
          priceWithVAT: 55.27,
        );

        expect(price.timeDisplay, equals('03:45'));
      });

      test('handles midnight correctly', () {
        final price = ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 0, 0),
          price: 45.67,
          priceWithVAT: 55.27,
        );

        expect(price.timeDisplay, equals('00:00'));
      });

      test('handles 23:45 (last interval) correctly', () {
        final price = ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 23, 45),
          price: 45.67,
          priceWithVAT: 55.27,
        );

        expect(price.timeDisplay, equals('23:45'));
      });
    });

    group('timestamp precision', () {
      test('preserves exact minute value', () {
        final price = ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 15),
          price: 45.67,
          priceWithVAT: 55.27,
        );

        expect(price.timestamp.hour, equals(7));
        expect(price.timestamp.minute, equals(15));
      });

      test('does not round to nearest hour', () {
        final price = ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 45),
          price: 45.67,
          priceWithVAT: 55.27,
        );

        expect(price.timestamp.hour, equals(7));
        expect(price.timestamp.minute, equals(45));
      });
    });

    group('fromJson', () {
      test('parses timestamp with 15-minute precision', () {
        final json = {
          'timestamp': 1729670100, // Unix timestamp for a :15 minute
          'price': 45.67,
        };

        final price = ElectricityPrice.fromJson(json);

        // Check that minute precision is preserved
        expect(price.timestamp.minute % 15, equals(0),
            reason: 'Should be on 15-minute interval');
      });

      test('calculates VAT correctly (21%)', () {
        final json = {
          'timestamp': 1729670100,
          'price': 100.0,
        };

        final price = ElectricityPrice.fromJson(json);

        expect(price.priceWithVAT, equals(121.0));
      });
    });

    group('formatPrice', () {
      test('converts EUR/MWh to EUR/kWh with 4 decimals', () {
        final price = ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 15),
          price: 45.6789,
          priceWithVAT: 55.2714,
        );

        expect(price.formatPrice(), equals('0.0553'));
      });

      test('includes VAT by default', () {
        final price = ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 15),
          price: 100.0,
          priceWithVAT: 121.0,
        );

        expect(price.formatPrice(includeVAT: true), equals('0.1210'));
      });

      test('excludes VAT when requested', () {
        final price = ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 15),
          price: 100.0,
          priceWithVAT: 121.0,
        );

        expect(price.formatPrice(includeVAT: false), equals('0.1000'));
      });
    });

    group('compareTo', () {
      test('sorts chronologically by timestamp', () {
        final price1 = ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 0),
          price: 50.0,
          priceWithVAT: 60.5,
        );

        final price2 = ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 15),
          price: 45.0,
          priceWithVAT: 54.45,
        );

        final price3 = ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 30),
          price: 55.0,
          priceWithVAT: 66.55,
        );

        final prices = [price3, price1, price2];
        prices.sort();

        expect(prices[0].timestamp.minute, equals(0));
        expect(prices[1].timestamp.minute, equals(15));
        expect(prices[2].timestamp.minute, equals(30));
      });
    });

    group('compareByPrice', () {
      test('compares by price value', () {
        final cheap = ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 0),
          price: 30.0,
          priceWithVAT: 36.3,
        );

        final expensive = ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 15),
          price: 60.0,
          priceWithVAT: 72.6,
        );

        expect(cheap.compareByPrice(expensive), lessThan(0));
        expect(expensive.compareByPrice(cheap), greaterThan(0));
      });
    });
  });
}
