import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';

/// A line chart widget displaying electricity prices throughout the day.
///
/// Supports both 24-point hourly data and 96-point 15-minute interval data.
/// Displays prices as a smooth line chart with interactive touch tooltips
/// showing exact times and price levels.
class PriceChart extends StatelessWidget {
  /// List of electricity prices to display (24 or 96 items)
  final List<ElectricityPrice> prices;

  /// Whether to show the daily average line
  final bool showAverageLine;

  /// Whether to show the current time marker
  final bool showCurrentTimeMarker;

  /// Height of the chart widget
  final double height;

  const PriceChart({
    super.key,
    required this.prices,
    this.showAverageLine = true,
    this.showCurrentTimeMarker = true,
    this.height = 250,
  });

  @override
  Widget build(BuildContext context) {
    if (prices.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No price data available'),
        ),
      );
    }

    final theme = Theme.of(context);
    final spots = _createSpots();
    final averagePrice = _calculateAverage();
    final minPrice = _findMinPrice();
    final maxPrice = _findMaxPrice();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Price Chart (${prices.length} intervals)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: LineChart(
                _createChartData(
                  context: context,
                  spots: spots,
                  averagePrice: averagePrice,
                  minPrice: minPrice,
                  maxPrice: maxPrice,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates FlSpot objects from price data.
  ///
  /// X-value: hour + (minute / 60) for smooth distribution
  /// - Example: 7:00 = 7.0, 7:15 = 7.25, 7:30 = 7.5, 7:45 = 7.75
  /// Y-value: price in EUR/kWh (converted from EUR/MWh)
  List<FlSpot> _createSpots() {
    return prices.map((price) {
      final hour = price.timestamp.hour;
      final minute = price.timestamp.minute;
      final xValue = hour + (minute / 60.0);
      final yValue = price.priceWithVAT / 1000; // Convert to EUR/kWh

      return FlSpot(xValue, yValue);
    }).toList();
  }

  /// Calculates the average price in EUR/kWh.
  double _calculateAverage() {
    if (prices.isEmpty) return 0.0;

    final sum = prices.fold<double>(
      0.0,
      (sum, price) => sum + price.priceWithVAT,
    );
    return (sum / prices.length) / 1000; // Convert to EUR/kWh
  }

  /// Finds the minimum price in EUR/kWh.
  double _findMinPrice() {
    if (prices.isEmpty) return 0.0;

    final min = prices.reduce(
      (curr, next) => curr.priceWithVAT < next.priceWithVAT ? curr : next,
    );
    return min.priceWithVAT / 1000;
  }

  /// Finds the maximum price in EUR/kWh.
  double _findMaxPrice() {
    if (prices.isEmpty) return 0.0;

    final max = prices.reduce(
      (curr, next) => curr.priceWithVAT > next.priceWithVAT ? curr : next,
    );
    return max.priceWithVAT / 1000;
  }

  /// Creates the chart data configuration.
  LineChartData _createChartData({
    required BuildContext context,
    required List<FlSpot> spots,
    required double averagePrice,
    required double minPrice,
    required double maxPrice,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Calculate price range for Y-axis
    final priceRange = maxPrice - minPrice;
    final yAxisPadding = priceRange * 0.1; // 10% padding
    final minY = (minPrice - yAxisPadding).clamp(0.0, double.infinity);
    final maxY = maxPrice + yAxisPadding;

    return LineChartData(
      // Grid configuration
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        horizontalInterval: priceRange / 5, // ~5 horizontal lines
        verticalInterval: 3, // Lines every 3 hours (0, 3, 6, 9, 12, 15, 18, 21, 24)
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: colorScheme.onSurface.withOpacity(0.1),
            strokeWidth: 1,
            dashArray: [5, 5],
          );
        },
        getDrawingVerticalLine: (value) {
          return FlLine(
            color: colorScheme.onSurface.withOpacity(0.1),
            strokeWidth: 1,
            dashArray: [5, 5],
          );
        },
      ),

      // Titles (axes labels)
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 6, // Show labels every 6 hours (0, 6, 12, 18, 24)
            getTitlesWidget: (value, meta) {
              final hour = value.toInt();
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            interval: priceRange / 5,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toStringAsFixed(3),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              );
            },
          ),
        ),
      ),

      // Border
      borderData: FlBorderData(
        show: true,
        border: Border.all(
          color: colorScheme.onSurface.withOpacity(0.2),
          width: 1,
        ),
      ),

      // Y-axis range
      minY: minY,
      maxY: maxY,

      // X-axis range (0-24 hours)
      minX: 0,
      maxX: 24,

      // Touch interaction
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: colorScheme.primaryContainer,
          tooltipRoundedRadius: 8,
          tooltipPadding: const EdgeInsets.all(8),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final price = _findPriceAtX(spot.x);
              if (price == null) return null;

              final priceLevel = _getPriceLevel(
                price.priceWithVAT / 1000,
                averagePrice,
              );

              return LineTooltipItem(
                '${price.timeDisplay}\n${price.formatPrice()}\n($priceLevel)',
                TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
        ),
        handleBuiltInTouches: true,
        getTouchedSpotIndicator: (barData, spotIndexes) {
          return spotIndexes.map((index) {
            return TouchedSpotIndicatorData(
              FlLine(
                color: colorScheme.primary,
                strokeWidth: 2,
              ),
              FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 6,
                    color: colorScheme.primary,
                    strokeWidth: 2,
                    strokeColor: colorScheme.surface,
                  );
                },
              ),
            );
          }).toList();
        },
      ),

      // Main line
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true, // Smooth line interpolation
          curveSmoothness: 0.35,
          color: _createGradientColor(colorScheme),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false), // Hide dots for smooth line
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                _createGradientColor(colorScheme).withOpacity(0.3),
                _createGradientColor(colorScheme).withOpacity(0.05),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],

      // Extra lines (average, current time)
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          // Average price line
          if (showAverageLine)
            HorizontalLine(
              y: averagePrice,
              color: Colors.blue.withOpacity(0.5),
              strokeWidth: 2,
              dashArray: [8, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                labelResolver: (line) => 'Avg: ${averagePrice.toStringAsFixed(4)}',
              ),
            ),
        ],
        verticalLines: [
          // Current time marker
          if (showCurrentTimeMarker) _createCurrentTimeMarker(colorScheme),
        ],
      ),
    );
  }

  /// Creates a vertical line at the current time.
  VerticalLine _createCurrentTimeMarker(ColorScheme colorScheme) {
    final now = DateTime.now();
    final currentX = now.hour + (now.minute / 60.0);

    return VerticalLine(
      x: currentX,
      color: colorScheme.primary.withOpacity(0.7),
      strokeWidth: 2,
      dashArray: [6, 3],
      label: VerticalLineLabel(
        show: true,
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 4),
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        labelResolver: (line) => 'Now',
      ),
    );
  }

  /// Finds the price entry closest to the given X coordinate.
  ElectricityPrice? _findPriceAtX(double x) {
    if (prices.isEmpty) return null;

    // Find the closest price to the X value
    ElectricityPrice? closest;
    double minDiff = double.infinity;

    for (final price in prices) {
      final priceX = price.timestamp.hour + (price.timestamp.minute / 60.0);
      final diff = (priceX - x).abs();

      if (diff < minDiff) {
        minDiff = diff;
        closest = price;
      }
    }

    return closest;
  }

  /// Determines the price level relative to average.
  String _getPriceLevel(double price, double average) {
    if (average == 0) return 'Medium';

    final ratio = price / average;

    if (ratio < 0.8) {
      return 'Low';
    } else if (ratio > 1.2) {
      return 'High';
    } else {
      return 'Medium';
    }
  }

  /// Creates a gradient color for the line based on theme.
  Color _createGradientColor(ColorScheme colorScheme) {
    // Use primary color with slight adjustment
    return colorScheme.primary;
  }
}
