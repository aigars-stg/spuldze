import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/providers.dart';

/// Home screen displaying electricity prices for today and tomorrow.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load prices on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        context.read<PriceProvider>().loadPrices();
        _isInitialized = true;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await context.read<PriceProvider>().refreshPrices();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.electricityPrices),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _handleRefresh,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Navigate to settings
            },
            tooltip: 'Settings',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: Column(
            children: [
              Consumer<PriceProvider>(
                builder: (context, provider, _) {
                  if (provider.lastUpdate != null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Last update: ${_formatDateTime(provider.lastUpdate!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Today'),
                  Tab(text: 'Tomorrow'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Consumer<PriceProvider>(
        builder: (context, provider, _) {
          // Loading state
          if (provider.isLoading && !provider.hasTodayPrices) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Error state with no data
          if (provider.errorMessage != null && !provider.hasTodayPrices) {
            return _ErrorView(
              message: provider.errorMessage!,
              onRetry: () => provider.loadPrices(),
            );
          }

          // Empty state
          if (!provider.hasTodayPrices) {
            return _EmptyView(
              onRefresh: () => provider.loadPrices(),
            );
          }

          // Success state - show tabs
          return TabBarView(
            controller: _tabController,
            children: [
              // Today tab
              _PriceTabView(
                prices: provider.todayPrices,
                isToday: true,
                onRefresh: _handleRefresh,
              ),
              // Tomorrow tab
              provider.hasTomorrowPrices
                  ? _PriceTabView(
                      prices: provider.tomorrowPrices!,
                      isToday: false,
                      onRefresh: _handleRefresh,
                    )
                  : _TomorrowNotAvailableView(
                      onRefresh: _handleRefresh,
                    ),
            ],
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, HH:mm').format(dateTime);
  }
}

/// Tab view displaying price information for a day.
class _PriceTabView extends StatelessWidget {
  final List<ElectricityPrice> prices;
  final bool isToday;
  final VoidCallback onRefresh;

  const _PriceTabView({
    required this.prices,
    required this.isToday,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current price (only for today)
          if (isToday) _CurrentPriceCard(prices: prices),
          if (isToday) const SizedBox(height: 16),

          // Statistics cards
          _StatisticsRow(prices: prices),
          const SizedBox(height: 24),

          // Hourly prices header
          Text(
            'Hourly Prices',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),

          // Hourly price list
          _HourlyPriceList(prices: prices),
        ],
      ),
    );
  }
}

/// Card displaying the current hour's price prominently.
class _CurrentPriceCard extends StatelessWidget {
  final List<ElectricityPrice> prices;

  const _CurrentPriceCard({required this.prices});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PriceProvider>();
    final currentPrice = provider.getCurrentPrice();
    final theme = Theme.of(context);

    if (currentPrice == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Current Price',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  currentPrice.formatPrice(),
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '€/kWh',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('HH:mm').format(currentPrice.timestamp),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row displaying average, min, and max prices.
class _StatisticsRow extends StatelessWidget {
  final List<ElectricityPrice> prices;

  const _StatisticsRow({required this.prices});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PriceProvider>();
    final minPrice = provider.getMinPrice(prices);
    final maxPrice = provider.getMaxPrice(prices);
    final avgPrice = provider.getAveragePrice(prices);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Average',
            value: (avgPrice / 1000).toStringAsFixed(4),
            unit: '€/kWh',
            icon: Icons.show_chart,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Min',
            value: minPrice?.formatPrice() ?? 'N/A',
            unit: minPrice != null ? '€/kWh' : '',
            subtitle: minPrice != null
                ? DateFormat('HH:mm').format(minPrice.timestamp)
                : null,
            icon: Icons.arrow_downward,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Max',
            value: maxPrice?.formatPrice() ?? 'N/A',
            unit: maxPrice != null ? '€/kWh' : '',
            subtitle: maxPrice != null
                ? DateFormat('HH:mm').format(maxPrice.timestamp)
                : null,
            icon: Icons.arrow_upward,
            color: Colors.red,
          ),
        ),
      ],
    );
  }
}

/// Card displaying a single statistic.
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (unit.isNotEmpty)
              Text(
                unit,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// List of hourly prices.
class _HourlyPriceList extends StatelessWidget {
  final List<ElectricityPrice> prices;

  const _HourlyPriceList({required this.prices});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PriceProvider>();
    final minPrice = provider.getMinPrice(prices);
    final maxPrice = provider.getMaxPrice(prices);
    final now = DateTime.now();

    return Column(
      children: prices.map((price) {
        final isMin = price == minPrice;
        final isMax = price == maxPrice;
        final isCurrent = price.timestamp.hour == now.hour &&
            price.timestamp.day == now.day;

        return _HourlyPriceItem(
          price: price,
          isMin: isMin,
          isMax: isMax,
          isCurrent: isCurrent,
        );
      }).toList(),
    );
  }
}

/// Single hourly price item.
class _HourlyPriceItem extends StatelessWidget {
  final ElectricityPrice price;
  final bool isMin;
  final bool isMax;
  final bool isCurrent;

  const _HourlyPriceItem({
    required this.price,
    required this.isMin,
    required this.isMax,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm');

    Color? backgroundColor;
    if (isCurrent) {
      backgroundColor = theme.colorScheme.primaryContainer.withOpacity(0.3);
    } else if (isMin) {
      backgroundColor = Colors.green.withOpacity(0.1);
    } else if (isMax) {
      backgroundColor = Colors.red.withOpacity(0.1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: isCurrent
            ? Border.all(
                color: theme.colorScheme.primary,
                width: 2,
              )
            : null,
      ),
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              timeFormat.format(price.timestamp),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
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
        title: Row(
          children: [
            Text(
              price.formatPrice(),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                color: isMin
                    ? Colors.green
                    : isMax
                        ? Colors.red
                        : null,
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMin)
              const Chip(
                label: Text('Cheapest'),
                backgroundColor: Colors.green,
                labelStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
            if (isMax)
              const Chip(
                label: Text('Highest'),
                backgroundColor: Colors.red,
                labelStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
          ],
        ),
      ),
    );
  }
}

/// View shown when tomorrow's prices are not available yet.
class _TomorrowNotAvailableView extends StatelessWidget {
  final VoidCallback onRefresh;

  const _TomorrowNotAvailableView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.schedule,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Tomorrow\'s Prices Not Available Yet',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Tomorrow\'s electricity prices are usually published around 2 PM. Pull down to refresh.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Center(
            child: FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Error view with retry button.
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Error',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty view shown when no data is available.
class _EmptyView extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.data_usage,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Data Available',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Pull down or tap the button to load electricity prices.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Load Prices'),
            ),
          ],
        ),
      ),
    );
  }
}
