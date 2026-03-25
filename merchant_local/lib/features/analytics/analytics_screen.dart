import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

final _wonFormat = NumberFormat('#,###');

// ── Providers ──

final _yearFilterProvider = StateProvider<String?>((ref) => null);

final _summaryProvider = FutureProvider<Map<String, num>>((ref) {
  return ref.watch(saleDaoProvider).getSalesSummary();
});

final _monthlyTrendProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  final year = ref.watch(_yearFilterProvider);
  return ref.watch(saleDaoProvider).getMonthlyTrend(year: year);
});

final _platformDistProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(saleDaoProvider).getPlatformDistribution();
});

final _topProfitProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref
      .watch(saleDaoProvider)
      .getTopModels(limit: 10, ascending: false);
});

final _topLossProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref
      .watch(saleDaoProvider)
      .getTopModels(limit: 10, ascending: true);
});

// ── Screen ──

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(_summaryProvider);
    final year = ref.watch(_yearFilterProvider);
    final now = DateTime.now().year.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('분석'),
        actions: [
          // 연도 필터
          PopupMenuButton<String?>(
            icon: const Icon(Icons.calendar_today, size: 20),
            tooltip: '기간 필터',
            onSelected: (v) =>
                ref.read(_yearFilterProvider.notifier).state = v,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: null,
                child: Text('전체 기간',
                    style: TextStyle(
                        fontWeight:
                            year == null ? FontWeight.bold : FontWeight.normal)),
              ),
              PopupMenuItem(
                value: now,
                child: Text('$now년',
                    style: TextStyle(
                        fontWeight:
                            year == now ? FontWeight.bold : FontWeight.normal)),
              ),
              PopupMenuItem(
                value: (int.parse(now) - 1).toString(),
                child: Text('${int.parse(now) - 1}년'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // ── 요약 카드 ──
          summaryAsync.when(
            data: (s) => Row(
              children: [
                _StatCard('판매', '${_wonFormat.format(s['totalSell'])}원',
                    AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                _StatCard('정산', '${_wonFormat.format(s['totalSettlement'])}원',
                    AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                _StatCard(
                    '이익',
                    '${_wonFormat.format(s['totalProfit'])}원',
                    (s['totalProfit'] as num) >= 0
                        ? AppColors.success
                        : AppColors.error),
                const SizedBox(width: AppSpacing.sm),
                _StatCard(
                    '마진',
                    '${(s['marginRate'] as num).toStringAsFixed(1)}%',
                    AppColors.accent),
              ],
            ),
            loading: () => const SizedBox(height: 60),
            error: (e, _) => Text('$e'),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── 월별 트렌드 ──
          _SectionTitle('월별 트렌드'),
          const SizedBox(height: AppSpacing.sm),
          _MonthlyTrendChart(),
          const SizedBox(height: AppSpacing.lg),

          // ── 플랫폼 분포 ──
          _SectionTitle('플랫폼 분포'),
          const SizedBox(height: AppSpacing.sm),
          _PlatformPieChart(),
          const SizedBox(height: AppSpacing.lg),

          // ── Top 10 수익 모델 ──
          _SectionTitle('Top 10 수익 모델'),
          const SizedBox(height: AppSpacing.sm),
          _TopModelsList(provider: _topProfitProvider, isProfit: true),
          const SizedBox(height: AppSpacing.lg),

          // ── Top 10 손실 모델 ──
          _SectionTitle('Top 10 손실 모델'),
          const SizedBox(height: AppSpacing.sm),
          _TopModelsList(provider: _topLossProvider, isProfit: false),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ── 위젯들 ──

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withAlpha(30),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTheme.dataStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 월별 트렌드 차트 ──
class _MonthlyTrendChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_monthlyTrendProvider);
    return async.when(
      data: (data) {
        if (data.isEmpty) {
          return _emptyChart(context, '판매 데이터가 없습니다');
        }
        final maxVal = data.fold<double>(0, (m, d) {
          final v = (d['sell'] as int).toDouble();
          return v > m ? v : m;
        });

        return Container(
          height: 220,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: _chartDecoration(context),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.border,
                  strokeWidth: 0.5,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (val, _) {
                      final i = val.toInt();
                      if (i < 0 || i >= data.length) return const SizedBox();
                      final m = (data[i]['month'] as String);
                      return Text(
                        m.length >= 7 ? m.substring(5) : m,
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    getTitlesWidget: (val, _) => Text(
                      _compactNumber(val),
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                _line(data, 'sell', AppColors.primary),
                _line(data, 'settlement', AppColors.success),
                _line(data, 'profit', AppColors.accent),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem(
                            _wonFormat.format(s.y.toInt()),
                            TextStyle(
                                color: s.bar.color, fontSize: 11),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => _loadingChart(),
      error: (e, _) => Text('$e'),
    );
  }

  LineChartBarData _line(
      List<Map<String, dynamic>> data, String key, Color color) {
    return LineChartBarData(
      spots: List.generate(data.length,
          (i) => FlSpot(i.toDouble(), (data[i][key] as int).toDouble())),
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withAlpha(20),
      ),
    );
  }
}

// ── 플랫폼 파이 차트 ──
class _PlatformPieChart extends ConsumerWidget {
  static const _colors = [
    AppColors.primary,
    AppColors.success,
    AppColors.accent,
    AppColors.statusInspection,
    AppColors.textTertiary,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_platformDistProvider);
    return async.when(
      data: (data) {
        if (data.isEmpty) return _emptyChart(context, '데이터 없음');
        final total =
            data.fold<int>(0, (s, d) => s + (d['totalSell'] as int));

        return Container(
          height: 200,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: _chartDecoration(context),
          child: Row(
            children: [
              // 파이
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: List.generate(data.length, (i) {
                      final d = data[i];
                      final val = (d['totalSell'] as int).toDouble();
                      return PieChartSectionData(
                        value: val,
                        color: _colors[i % _colors.length],
                        radius: 40,
                        title:
                            '${(val / total * 100).toStringAsFixed(0)}%',
                        titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      );
                    }),
                  ),
                ),
              ),
              // 범례
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(data.length, (i) {
                  final d = data[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _colors[i % _colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${d['platform']}  ${d['count']}건',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
      loading: () => _loadingChart(),
      error: (e, _) => Text('$e'),
    );
  }
}

// ── Top 모델 목록 ──
class _TopModelsList extends ConsumerWidget {
  final FutureProvider<List<Map<String, dynamic>>> provider;
  final bool isProfit;

  const _TopModelsList({required this.provider, required this.isProfit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      data: (data) {
        if (data.isEmpty) return _emptyChart(context, '데이터 없음');
        return Container(
          decoration: _chartDecoration(context),
          child: Column(
            children: List.generate(data.length, (i) {
              final d = data[i];
              final profit = d['profit'] as int;
              final color = profit >= 0 ? AppColors.success : AppColors.error;
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${i + 1}',
                        style: AppTheme.dataStyle(
                            fontSize: 12, color: AppColors.textTertiary),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['modelName'] as String,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${d['modelCode']}  (${d['count']}건)',
                            style: AppTheme.dataStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${profit >= 0 ? '+' : ''}${_wonFormat.format(profit)}원',
                      style: AppTheme.dataStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
      loading: () => _loadingChart(),
      error: (e, _) => Text('$e'),
    );
  }
}

// ── 유틸 ──

BoxDecoration _chartDecoration(BuildContext context) => BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withAlpha(30),
      ),
    );

Widget _emptyChart(BuildContext context, String msg) => Container(
      height: 120,
      decoration: _chartDecoration(context),
      child: Center(
        child: Text(msg,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textTertiary)),
      ),
    );

Widget _loadingChart() => const SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );

String _compactNumber(double val) {
  if (val.abs() >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
  if (val.abs() >= 1000) return '${(val / 1000).toStringAsFixed(0)}K';
  return val.toStringAsFixed(0);
}
