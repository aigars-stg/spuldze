import 'package:flutter_test/flutter_test.dart';
import 'package:spuldze/models/models.dart';

void main() {
  group('HourlyGroup', () {
    late List<ElectricityPrice> validFourPrices;

    setUp(() {
      // Create a valid group with 4 prices for hour 7
      validFourPrices = [
        ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 0),
          price: 40.0,
          priceWithVAT: 48.4,
        ),
        ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 15),
          price: 50.0,
          priceWithVAT: 60.5,
        ),
        ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 30),
          price: 45.0,
          priceWithVAT: 54.45,
        ),
        ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, 7, 45),
          price: 55.0,
          priceWithVAT: 66.55,
        ),
      ];
    });

    group('constructor validation', () {
      test('accepts exactly 4 prices', () {
        expect(
          () => HourlyGroup(hour: 7, prices: validFourPrices),
          returnsNormally,
        );
      });

      test('throws assertion error with 3 prices', () {
        expect(
          () => HourlyGroup(hour: 7, prices: validFourPrices.take(3).toList()),
          throwsAssertionError,
        );
      });

      test('throws assertion error with 5 prices', () {
        expect(
          () => HourlyGroup(
            hour: 7,
            prices: [
              ...validFourPrices,
              ElectricityPrice(
                timestamp: DateTime(2025, 10, 23, 8, 0),
                price: 50.0,
                priceWithVAT: 60.5,
              ),
            ],
          ),
          throwsAssertionError,
        );
      });

      test('throws assertion error with invalid hour (negative)', () {
        expect(
          () => HourlyGroup(hour: -1, prices: validFourPrices),
          throwsAssertionError,
        );
      });

      test('throws assertion error with invalid hour (>23)', () {
        expect(
          () => HourlyGroup(hour: 24, prices: validFourPrices),
          throwsAssertionError,
        );
      });
    });

    group('averagePrice calculation', () {
      test('calculates correct average with VAT', () {
        final group = HourlyGroup(hour: 7, prices: validFourPrices);

        // (48.4 + 60.5 + 54.45 + 66.55) / 4 = 229.9 / 4 = 57.475
        expect(group.averagePrice, equals(57.475));
      });

      test('calculates correct average without VAT', () {
        final group = HourlyGroup(hour: 7, prices: validFourPrices);

        // (40.0 + 50.0 + 45.0 + 55.0) / 4 = 190.0 / 4 = 47.5
        expect(group.averagePriceNoVAT, equals(47.5));
      });

      test('handles identical prices', () {
        final samePrices = List.generate(
          4,
          (i) => ElectricityPrice(
            timestamp: DateTime(2025, 10, 23, 7, i * 15),
            price: 50.0,
            priceWithVAT: 60.5,
          ),
        );

        final group = HourlyGroup(hour: 7, prices: samePrices);

        expect(group.averagePrice, equals(60.5));
      });
    });

    group('min/max price identification', () {
      test('identifies minimum price correctly', () {
        final group = HourlyGroup(hour: 7, prices: validFourPrices);

        // Min should be 48.4 (first price at 7:00)
        expect(group.minPrice, equals(48.4));
      });

      test('identifies maximum price correctly', () {
        final group = HourlyGroup(hour: 7, prices: validFourPrices);

        // Max should be 66.55 (last price at 7:45)
        expect(group.maxPrice, equals(66.55));
      });

      test('identifies minPriceEntry with correct timestamp', () {
        final group = HourlyGroup(hour: 7, prices: validFourPrices);

        expect(group.minPriceEntry.timestamp.minute, equals(0));
        expect(group.minPriceEntry.priceWithVAT, equals(48.4));
      });

      test('identifies maxPriceEntry with correct timestamp', () {
        final group = HourlyGroup(hour: 7, prices: validFourPrices);

        expect(group.maxPriceEntry.timestamp.minute, equals(45));
        expect(group.maxPriceEntry.priceWithVAT, equals(66.55));
      });

      test('handles min and max being same price', () {
        final samePrices = List.generate(
          4,
          (i) => ElectricityPrice(
            timestamp: DateTime(2025, 10, 23, 7, i * 15),
            price: 50.0,
            priceWithVAT: 60.5,
          ),
        );

        final group = HourlyGroup(hour: 7, prices: samePrices);

        expect(group.minPrice, equals(group.maxPrice));
      });
    });

    group('time display format', () {
      test('displayHour formats single-digit hour correctly', () {
        final group = HourlyGroup(hour: 7, prices: validFourPrices);

        expect(group.displayHour, equals('07:00'));
      });

      test('displayHour formats double-digit hour correctly', () {
        final prices = List.generate(
          4,
          (i) => ElectricityPrice(
            timestamp: DateTime(2025, 10, 23, 14, i * 15),
            price: 50.0,
            priceWithVAT: 60.5,
          ),
        );

        final group = HourlyGroup(hour: 14, prices: prices);

        expect(group.displayHour, equals('14:00'));
      });

      test('displayHourRange shows correct range', () {
        final group = HourlyGroup(hour: 7, prices: validFourPrices);

        expect(group.displayHourRange, equals('07:00 - 08:00'));
      });

      test('displayHourRange handles midnight wrap', () {
        final prices = List.generate(
          4,
          (i) => ElectricityPrice(
            timestamp: DateTime(2025, 10, 23, 23, i * 15),
            price: 50.0,
            priceWithVAT: 60.5,
          ),
        );

        final group = HourlyGroup(hour: 23, prices: prices);

        expect(group.displayHourRange, equals('23:00 - 00:00'));
      });
    });

    group('isNowHour', () {
      test('returns true when hour matches current time', () {
        final now = DateTime.now();
        final prices = List.generate(
          4,
          (i) => ElectricityPrice(
            timestamp: DateTime(now.year, now.month, now.day, now.hour, i * 15),
            price: 50.0,
            priceWithVAT: 60.5,
          ),
        );

        final group = HourlyGroup(hour: now.hour, prices: prices);

        expect(group.isNowHour, isTrue);
      });

      test('returns false when hour does not match current time', () {
        final now = DateTime.now();
        final differentHour = (now.hour + 5) % 24;

        final prices = List.generate(
          4,
          (i) => ElectricityPrice(
            timestamp: DateTime(
                now.year, now.month, now.day, differentHour, i * 15),
            price: 50.0,
            priceWithVAT: 60.5,
          ),
        );

        final group = HourlyGroup(hour: differentHour, prices: prices);

        // Should be false unless we're in that hour (unlikely during test)
        expect(group.isNowHour, differentHour == now.hour);
      });
    });

    group('getPriceAtMinute', () {
      test('returns correct price for :00', () {
        final group = HourlyGroup(hour: 7, prices: validFourPrices);

        final price = group.getPriceAtMinute(0);

        expect(price, isNotNull);
        expect(price!.timestamp.minute, equals(0));
      });

      test('returns correct price for :15', () {
        final group = HourlyGroup(hour: 7, prices: validFourPrices);

        final price = group.getPriceAtMinute(15);

        expect(price, isNotNull);
        expect(price!.timestamp.minute, equals(15));
      });

      test('returns correct price for :30', () {
        final group = HourlyGroup(hour: 7, prices: validFourPrices);

        final price = group.getPriceAtMinute(30);

        expect(price, isNotNull);
        expect(price!.timestamp.minute, equals(30));
      });

      test('returns correct price for :45', () {
        final group = HourlyGroup(hour: 7, prices: validFourPrices);

        final price = group.getPriceAtMinute(45);

        expect(price, isNotNull);
        expect(price!.timestamp.minute, equals(45));
      });

      test('returns null for invalid minute (10)', () {
        final group = HourlyGroup(hour: 7, prices: validFourPrices);

        final price = group.getPriceAtMinute(10);

        expect(price, isNull);
      });

      test('returns null for invalid minute (60)', () {
        final group = HourlyGroup(hour: 7, prices: validFourPrices);

        final price = group.getPriceAtMinute(60);

        expect(price, isNull);
      });
    });

    group('averagePriceInKWh', () {
      test('converts EUR/MWh to EUR/kWh', () {
        final group = HourlyGroup(hour: 7, prices: validFourPrices);

        // Average is 57.475 EUR/MWh, should be 0.057475 EUR/kWh
        expect(group.averagePriceInKWh, closeTo(0.057475, 0.000001));
      });
    });

    group('getFormattedAveragePrice', () {
      test('formats with 4 decimals by default', () {
        final group = HourlyGroup(hour: 7, prices: validFourPrices);

        expect(group.getFormattedAveragePrice(), equals('0.0575'));
      });

      test('formats with custom decimals', () {
        final group = HourlyGroup(hour: 7, prices: validFourPrices);

        expect(group.getFormattedAveragePrice(decimals: 2), equals('0.06'));
        expect(group.getFormattedAveragePrice(decimals: 6), equals('0.057475'));
      });
    });
  });
}
