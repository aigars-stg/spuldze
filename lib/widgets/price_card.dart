import 'package:flutter/material.dart';

import '../models/models.dart';

/// Display mode for the price card.
enum PriceCardMode {
  /// Hourly mode: shows aggregated hour data with 4x15-min prices
  hourly,

  /// Detail mode: shows individual 15-minute interval price
  detail,
}

/// A card widget for displaying electricity prices in different modes.
///
/// Supports two display modes:
/// - [PriceCardMode.hourly]: Shows aggregated hourly data with average, min, max
/// - [PriceCardMode.detail]: Shows individual 15-minute interval price
class PriceCard extends StatelessWidget {
  /// The display mode for this card
  final PriceCardMode mode;

  /// Hourly group data (required for hourly mode)
  final HourlyGroup? hourlyGroup;

  /// Individual price data (required for detail mode)
  final ElectricityPrice? price;

  /// Daily average price for color coding (in EUR/MWh with VAT)
  final double dailyAveragePrice;

  /// Callback when card is tapped (optional, for hourly mode expansion)
  final VoidCallback? onTap;

  /// Whether this card represents the current time
  final bool isCurrent;

  const PriceCard({
    super.key,
    required this.mode,
    this.hourlyGroup,
    this.price,
    required this.dailyAveragePrice,
    this.onTap,
    this.isCurrent = false,
  }) : assert(
          mode == PriceCardMode.hourly && hourlyGroup != null ||
              mode == PriceCardMode.detail && price != null,
          'Must provide hourlyGroup for hourly mode or price for detail mode',
        );

  @override
  Widget build(BuildContext context) {
    if (mode == PriceCardMode.hourly) {
      return _buildHourlyCard(context);
    } else {
      return _buildDetailCard(context);
    }
  }

  /// Builds a card showing hourly aggregated data.
  Widget _buildHourlyCard(BuildContext context) {
    final theme = Theme.of(context);
    final group = hourlyGroup!;

    final avgPrice = group.averagePrice;
    final color = _getPriceColor(avgPrice);
    final minEntry = group.minPriceEntry;
    final maxEntry = group.maxPriceEntry;

    return Card(
      elevation: isCurrent ? 4 : 1,
      color: isCurrent
          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Time range and current indicator
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 20,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    group.displayHourRange,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: const Text('Now'),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onPrimary,
                      ),
                      backgroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Average price (large)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'Avg: ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    group.getFormattedAveragePrice(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '€/kWh',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Min/Max with exact times
              Row(
                children: [
                  Expanded(
                    child: _buildMinMaxChip(
                      context: context,
                      label: 'Min',
                      price: minEntry.formatPrice(),
                      time: minEntry.timeDisplay,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMinMaxChip(
                      context: context,
                      label: 'Max',
                      price: maxEntry.formatPrice(),
                      time: maxEntry.timeDisplay,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),

              // Expand hint
              if (onTap != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Icon(
                    Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a small chip showing min or max price with time.
  Widget _buildMinMaxChip({
    required BuildContext context,
    required String label,
    required String price,
    required String time,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$price €/kWh',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'at $time',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a card showing individual 15-minute interval price.
  Widget _buildDetailCard(BuildContext context) {
    final theme = Theme.of(context);
    final priceData = price!;

    final priceValue = priceData.priceWithVAT;
    final color = _getPriceColor(priceValue);

    return Card(
      elevation: isCurrent ? 3 : 0.5,
      color: isCurrent
          ? theme.colorScheme.primaryContainer.withOpacity(0.2)
          : null,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Time
              SizedBox(
                width: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      priceData.timeDisplay,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    if (isCurrent)
                      Text(
                        'Now',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Price
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      priceData.formatPrice(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '€/kWh',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // Color indicator
              Container(
                width: 4,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Gets the color for a price based on comparison to daily average.
  ///
  /// Returns:
  /// - Green if price < 80% of average (cheap)
  /// - Red if price > 120% of average (expensive)
  /// - Orange/amber otherwise (medium)
  Color _getPriceColor(double priceValue) {
    if (dailyAveragePrice == 0) {
      return Colors.grey;
    }

    final ratio = priceValue / dailyAveragePrice;

    if (ratio < 0.8) {
      return Colors.green;
    } else if (ratio > 1.2) {
      return Colors.red;
    } else {
      return Colors.orange;
    }
  }
}
