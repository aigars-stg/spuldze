import 'package:flutter_test/flutter_test.dart';
import 'package:spuldze/models/models.dart';

void main() {
  group('PriceDay', () {
    late List<ElectricityPrice> valid96Prices;
    late List<ElectricityPrice> valid24Prices;

    setUp(() {
      // Create a full day with 96 15-minute interval prices
      valid96Prices = [];
      for (int hour = 0; hour < 24; hour++) {
        for (int minute in [0, 15, 30, 45]) {
          valid96Prices.add(
            ElectricityPrice(
              timestamp: DateTime(2025, 10, 23, hour, minute),
              price: 40.0 + hour, // Vary by hour
              priceWithVAT: (40.0 + hour) * 1.21,
            ),
          );
        }
      }

      // Create hourly prices (24 prices at :00 minutes)
      valid24Prices = List.generate(
        24,
        (hour) => ElectricityPrice(
          timestamp: DateTime(2025, 10, 23, hour, 0),
          price: 40.0 + hour,
          priceWithVAT: (40.0 + hour) * 1.21,
        ),
      );
    });

    group('constructor and date normalization', () {
      test('creates PriceDay with 96 prices', () {
        final priceDay = PriceDay(prices: valid96Prices);

        expect(priceDay.prices.length, equals(96));
        expect(priceDay.priceCount, equals(96));
      });

      test('creates PriceDay with 24 prices (hourly)', () {
        final priceDay = PriceDay(prices: valid24Prices);

        expect(priceDay.prices.length, equals(24));
        expect(priceDay.priceCount, equals(24));
      });

      test('normalizes date to midnight from first price', () {
        final priceDay = PriceDay(prices: valid96Prices);

        expect(priceDay.date.hour, equals(0));
        expect(priceDay.date.minute, equals(0));
        expect(priceDay.date.second, equals(0));
        expect(priceDay.date.day, equals(23));
        expect(priceDay.date.month, equals(10));
        expect(priceDay.date.year, equals(2025));
      });

      test('accepts explicit date parameter', () {
        final explicitDate = DateTime(2025, 10, 22);
        final priceDay = PriceDay(prices: valid96Prices, date: explicitDate);

        expect(priceDay.date, equals(explicitDate));
      });

      test('handles empty prices list', () {
        final priceDay = PriceDay(prices: []);

        expect(priceDay.isEmpty, isTrue);
        expect(priceDay.isNotEmpty, isFalse);
        expect(priceDay.priceCount, equals(0));
      });
    });

    group('groupedByHour with 15-minute intervals', () {
      test('returns exactly 24 groups for complete 96 prices', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final groups = priceDay.groupedByHour;

        expect(groups.length, equals(24));
      });

      test('each group has correct hour number (0-23)', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final groups = priceDay.groupedByHour;

        for (int i = 0; i < 24; i++) {
          expect(groups[i].hour, equals(i));
        }
      });

      test('each group contains exactly 4 prices', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final groups = priceDay.groupedByHour;

        for (final group in groups) {
          expect(group.prices.length, equals(4));
        }
      });

      test('groups prices by hour correctly', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final groups = priceDay.groupedByHour;
        final hour7Group = groups[7];

        expect(hour7Group.hour, equals(7));
        expect(hour7Group.prices[0].timestamp.hour, equals(7));
        expect(hour7Group.prices[0].timestamp.minute, equals(0));
        expect(hour7Group.prices[1].timestamp.minute, equals(15));
        expect(hour7Group.prices[2].timestamp.minute, equals(30));
        expect(hour7Group.prices[3].timestamp.minute, equals(45));
      });

      test('omits hours with incomplete data', () {
        // Create a list missing the :45 interval for hour 7
        final incompletePrices = valid96Prices
            .where((p) => !(p.timestamp.hour == 7 && p.timestamp.minute == 45))
            .toList();

        final priceDay = PriceDay(prices: incompletePrices);

        final groups = priceDay.groupedByHour;

        // Should have 23 groups (missing hour 7)
        expect(groups.length, equals(23));
        expect(groups.any((g) => g.hour == 7), isFalse);
      });

      test('returns empty list for empty prices', () {
        final priceDay = PriceDay(prices: []);

        final groups = priceDay.groupedByHour;

        expect(groups.isEmpty, isTrue);
      });

      test('returns empty list for 24 hourly prices', () {
        final priceDay = PriceDay(prices: valid24Prices);

        final groups = priceDay.groupedByHour;

        // With only :00 minutes, no hour has 4 intervals
        expect(groups.isEmpty, isTrue);
      });
    });

    group('getHourlyGroup', () {
      test('returns correct group for valid hour', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final group = priceDay.getHourlyGroup(7);

        expect(group, isNotNull);
        expect(group!.hour, equals(7));
        expect(group.prices.length, equals(4));
      });

      test('works for all hours (0-23)', () {
        final priceDay = PriceDay(prices: valid96Prices);

        for (int hour = 0; hour < 24; hour++) {
          final group = priceDay.getHourlyGroup(hour);
          expect(group, isNotNull);
          expect(group!.hour, equals(hour));
        }
      });

      test('returns null for invalid hour (negative)', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final group = priceDay.getHourlyGroup(-1);

        expect(group, isNull);
      });

      test('returns null for invalid hour (>23)', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final group = priceDay.getHourlyGroup(24);

        expect(group, isNull);
      });

      test('returns null for hour with incomplete data', () {
        // Create a list missing hour 7 data
        final incompletePrices =
            valid96Prices.where((p) => p.timestamp.hour != 7).toList();

        final priceDay = PriceDay(prices: incompletePrices);

        final group = priceDay.getHourlyGroup(7);

        expect(group, isNull);
      });
    });

    group('getHourlyAveragePrice', () {
      test('calculates correct average with VAT', () {
        final priceDay = PriceDay(prices: valid96Prices);

        // Hour 7 has prices: 47.0 * 1.21 = 56.87
        final avg = priceDay.getHourlyAveragePrice(7);

        expect(avg, isNotNull);
        expect(avg, closeTo(56.87, 0.01));
      });

      test('calculates correct average without VAT', () {
        final priceDay = PriceDay(prices: valid96Prices);

        // Hour 7 has price: 47.0 (without VAT)
        final avg = priceDay.getHourlyAveragePrice(7, includeVAT: false);

        expect(avg, isNotNull);
        expect(avg, equals(47.0));
      });

      test('returns null for invalid hour', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final avg = priceDay.getHourlyAveragePrice(24);

        expect(avg, isNull);
      });

      test('returns null for hour with incomplete data', () {
        final incompletePrices =
            valid96Prices.where((p) => p.timestamp.hour != 7).toList();

        final priceDay = PriceDay(prices: incompletePrices);

        final avg = priceDay.getHourlyAveragePrice(7);

        expect(avg, isNull);
      });
    });

    group('min/max/average price', () {
      test('getMinPrice returns lowest price with VAT', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final min = priceDay.getMinPrice();

        expect(min, isNotNull);
        // Hour 0 has lowest price: 40.0 * 1.21 = 48.4
        expect(min!.priceWithVAT, equals(40.0 * 1.21));
        expect(min.timestamp.hour, equals(0));
      });

      test('getMinPrice returns lowest price without VAT', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final min = priceDay.getMinPrice(includeVAT: false);

        expect(min, isNotNull);
        expect(min!.price, equals(40.0));
        expect(min.timestamp.hour, equals(0));
      });

      test('getMaxPrice returns highest price with VAT', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final max = priceDay.getMaxPrice();

        expect(max, isNotNull);
        // Hour 23 has highest price: 63.0 * 1.21 = 76.23
        expect(max!.priceWithVAT, equals(63.0 * 1.21));
        expect(max.timestamp.hour, equals(23));
      });

      test('getMaxPrice returns highest price without VAT', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final max = priceDay.getMaxPrice(includeVAT: false);

        expect(max, isNotNull);
        expect(max!.price, equals(63.0));
        expect(max.timestamp.hour, equals(23));
      });

      test('getAveragePrice calculates correctly across 96 prices', () {
        final priceDay = PriceDay(prices: valid96Prices);

        // Average of 40-63 = 51.5 EUR/MWh
        // With VAT: 51.5 * 1.21 = 62.315
        final avg = priceDay.getAveragePrice();

        expect(avg, isNotNull);
        expect(avg, closeTo(62.315, 0.01));
      });

      test('getAveragePrice returns null for empty prices', () {
        final priceDay = PriceDay(prices: []);

        final avg = priceDay.getAveragePrice();

        expect(avg, isNull);
      });

      test('getFormattedAveragePrice formats with 4 decimals by default', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final formatted = priceDay.getFormattedAveragePrice();

        expect(formatted, isNotNull);
        expect(formatted, equals('0.0623')); // 62.315 / 1000 = 0.062315 rounded
      });

      test('getFormattedAveragePrice formats with custom decimals', () {
        final priceDay = PriceDay(prices: valid96Prices);

        expect(priceDay.getFormattedAveragePrice(decimals: 2), equals('0.06'));
        expect(priceDay.getFormattedAveragePrice(decimals: 6),
            equals('0.062315'));
      });
    });

    group('getCurrentPrice with 15-minute rounding', () {
      test('returns price for current 15-minute interval', () {
        // This test may be flaky due to time dependency
        // In production, you might want to inject time for testability
        final now = DateTime.now();
        final rounded15Min = (now.minute ~/ 15) * 15;

        final todayPrices = <ElectricityPrice>[];
        for (int hour = 0; hour < 24; hour++) {
          for (int minute in [0, 15, 30, 45]) {
            todayPrices.add(
              ElectricityPrice(
                timestamp: DateTime(now.year, now.month, now.day, hour, minute),
                price: 40.0 + hour,
                priceWithVAT: (40.0 + hour) * 1.21,
              ),
            );
          }
        }

        final priceDay = PriceDay(prices: todayPrices);
        final currentPrice = priceDay.getCurrentPrice();

        expect(currentPrice, isNotNull);
        expect(currentPrice!.timestamp.hour, equals(now.hour));
        expect(currentPrice.timestamp.minute, equals(rounded15Min));
        expect(currentPrice.timestamp.day, equals(now.day));
      });

      test('returns null for empty prices', () {
        final priceDay = PriceDay(prices: []);

        final currentPrice = priceDay.getCurrentPrice();

        expect(currentPrice, isNull);
      });

      test('returns null when current interval not in data', () {
        // Create prices for a different day
        final priceDay = PriceDay(prices: valid96Prices);

        final currentPrice = priceDay.getCurrentPrice();

        // Should be null since data is for 2025-10-23
        expect(currentPrice, isNull);
      });
    });

    group('date checking methods', () {
      test('isToday returns true for today\'s data', () {
        final now = DateTime.now();
        final todayPrices = <ElectricityPrice>[];
        for (int hour = 0; hour < 24; hour++) {
          for (int minute in [0, 15, 30, 45]) {
            todayPrices.add(
              ElectricityPrice(
                timestamp: DateTime(now.year, now.month, now.day, hour, minute),
                price: 40.0,
                priceWithVAT: 48.4,
              ),
            );
          }
        }

        final priceDay = PriceDay(prices: todayPrices);

        expect(priceDay.isToday(), isTrue);
      });

      test('isToday returns false for yesterday\'s data', () {
        final priceDay = PriceDay(prices: valid96Prices);

        expect(priceDay.isToday(), isFalse);
      });

      test('isTomorrow returns true for tomorrow\'s data', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final tomorrowPrices = <ElectricityPrice>[];
        for (int hour = 0; hour < 24; hour++) {
          for (int minute in [0, 15, 30, 45]) {
            tomorrowPrices.add(
              ElectricityPrice(
                timestamp:
                    DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute),
                price: 40.0,
                priceWithVAT: 48.4,
              ),
            );
          }
        }

        final priceDay = PriceDay(prices: tomorrowPrices);

        expect(priceDay.isTomorrow(), isTrue);
      });

      test('isTomorrow returns false for today\'s data', () {
        final priceDay = PriceDay(prices: valid96Prices);

        expect(priceDay.isTomorrow(), isFalse);
      });

      test('isYesterday returns true for yesterday\'s data', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final yesterdayPrices = <ElectricityPrice>[];
        for (int hour = 0; hour < 24; hour++) {
          for (int minute in [0, 15, 30, 45]) {
            yesterdayPrices.add(
              ElectricityPrice(
                timestamp: DateTime(
                    yesterday.year, yesterday.month, yesterday.day, hour, minute),
                price: 40.0,
                priceWithVAT: 48.4,
              ),
            );
          }
        }

        final priceDay = PriceDay(prices: yesterdayPrices);

        expect(priceDay.isYesterday(), isTrue);
      });

      test('date methods return false for empty prices', () {
        final priceDay = PriceDay(prices: []);

        expect(priceDay.isToday(), isFalse);
        expect(priceDay.isTomorrow(), isFalse);
        expect(priceDay.isYesterday(), isFalse);
      });
    });

    group('getPricesInRange', () {
      test('returns prices within valid range', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final rangesPrices = priceDay.getPricesInRange(startHour: 7, endHour: 9);

        // Hours 7, 8, 9 = 3 hours * 4 intervals = 12 prices
        expect(rangesPrices.length, equals(12));
        expect(rangesPrices.first.timestamp.hour, equals(7));
        expect(rangesPrices.last.timestamp.hour, equals(9));
      });

      test('handles range spanning midnight', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final rangePrices = priceDay.getPricesInRange(startHour: 22, endHour: 2);

        // Hours 22, 23, 0, 1, 2 = 5 hours * 4 intervals = 20 prices
        expect(rangePrices.length, equals(20));
      });

      test('returns empty list for invalid hour range', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final rangePrices = priceDay.getPricesInRange(startHour: -1, endHour: 5);

        expect(rangePrices.isEmpty, isTrue);
      });

      test('returns single hour when start equals end', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final rangePrices = priceDay.getPricesInRange(startHour: 7, endHour: 7);

        // 1 hour * 4 intervals = 4 prices
        expect(rangePrices.length, equals(4));
      });
    });

    group('getCheapestConsecutiveHours', () {
      test('finds cheapest consecutive hours', () {
        final priceDay = PriceDay(prices: valid96Prices);

        // With prices increasing by hour, cheapest 2 hours should be 0-1
        final cheapest = priceDay.getCheapestConsecutiveHours(duration: 8);

        expect(cheapest, isNotNull);
        expect(cheapest!.length, equals(8));
        // Should start at hour 0 (first 2 hours)
        expect(cheapest.first.timestamp.hour, equals(0));
      });

      test('returns null for invalid duration', () {
        final priceDay = PriceDay(prices: valid96Prices);

        expect(priceDay.getCheapestConsecutiveHours(duration: 0), isNull);
        expect(priceDay.getCheapestConsecutiveHours(duration: -1), isNull);
        expect(priceDay.getCheapestConsecutiveHours(duration: 97), isNull);
      });

      test('works with different VAT settings', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final cheapestWithVAT =
            priceDay.getCheapestConsecutiveHours(duration: 4, includeVAT: true);
        final cheapestNoVAT =
            priceDay.getCheapestConsecutiveHours(duration: 4, includeVAT: false);

        // Results should be same hour range regardless of VAT
        expect(cheapestWithVAT!.first.timestamp.hour,
            equals(cheapestNoVAT!.first.timestamp.hour));
      });
    });

    group('fromJson and toJson', () {
      test('fromJson creates PriceDay correctly', () {
        final json = {
          'prices': [
            {
              'timestamp': DateTime(2025, 10, 23, 7, 0).millisecondsSinceEpoch,
              'price': 45.0,
              'priceWithVAT': 54.45,
            },
            {
              'timestamp': DateTime(2025, 10, 23, 7, 15).millisecondsSinceEpoch,
              'price': 50.0,
              'priceWithVAT': 60.5,
            },
          ],
        };

        final priceDay = PriceDay.fromJson(json);

        expect(priceDay.prices.length, equals(2));
        expect(priceDay.prices[0].price, equals(45.0));
        expect(priceDay.prices[1].price, equals(50.0));
      });

      test('toJson serializes correctly', () {
        final priceDay = PriceDay(prices: valid96Prices.take(4).toList());

        final json = priceDay.toJson();

        expect(json['date'], isNotNull);
        expect(json['prices'], isA<List>());
        expect(json['prices'].length, equals(4));
      });

      test('round-trip fromJson -> toJson preserves data', () {
        final original = PriceDay(prices: valid96Prices.take(4).toList());

        final json = original.toJson();
        final restored = PriceDay.fromJson(json);

        expect(restored.prices.length, equals(original.prices.length));
        expect(restored.prices[0].price, equals(original.prices[0].price));
      });
    });

    group('getSummary', () {
      test('returns summary with all statistics', () {
        final priceDay = PriceDay(prices: valid96Prices);

        final summary = priceDay.getSummary();

        expect(summary['isEmpty'], isFalse);
        expect(summary['hourCount'], equals(96));
        expect(summary['date'], isNotNull);
        expect(summary['minPrice'], isNotNull);
        expect(summary['maxPrice'], isNotNull);
        expect(summary['averagePrice'], isNotNull);
        expect(summary['minPriceTime'], isNotNull);
        expect(summary['maxPriceTime'], isNotNull);
      });

      test('returns isEmpty summary for empty prices', () {
        final priceDay = PriceDay(prices: []);

        final summary = priceDay.getSummary();

        expect(summary['isEmpty'], isTrue);
        expect(summary['hourCount'], equals(0));
      });
    });

    group('equality and copyWith', () {
      test('equality operator works correctly', () {
        final priceDay1 = PriceDay(prices: valid96Prices);
        final priceDay2 = PriceDay(prices: valid96Prices);
        final priceDay3 = PriceDay(prices: valid24Prices);

        expect(priceDay1 == priceDay2, isTrue);
        expect(priceDay1 == priceDay3, isFalse);
      });

      test('copyWith creates modified copy', () {
        final original = PriceDay(prices: valid96Prices);
        final modified = original.copyWith(prices: valid24Prices);

        expect(modified.prices.length, equals(24));
        expect(original.prices.length, equals(96));
      });
    });
  });
}
