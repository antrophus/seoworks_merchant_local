import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

final _wonFmt = NumberFormat('#,###');
final _dateFmt = DateFormat('yyyy-MM-dd');

// ══════════════════════════════════════════════════════════════
// 기간 필터 상태
// ══════════════════════════════════════════════════════════════

enum _Period { thisMonth, thisYear, all, custom }

final _periodProvider = StateProvider<_Period>((_) => _Period.thisYear);
final _customRangeProvider = StateProvider<(String, String)?>((_) => null);

/// 현재 기간 (from, to)
final _dateRangeProvider = Provider<(String?, String?)>((ref) {
  final p = ref.watch(_periodProvider);
  final custom = ref.watch(_customRangeProvider);
  final now = DateTime.now();
  return switch (p) {
    _Period.thisMonth => (
        '${now.year}-${now.month.toString().padLeft(2, '0')}-01',
        _dateFmt.format(now),
      ),
    _Period.thisYear => ('${now.year}-01-01', _dateFmt.format(now)),
    _Period.all => (null, null),
    _Period.custom => custom ?? (null, null),
  };
});

/// 비교 기간 — thisMonth=지난달, thisYear=전년, 나머지=null
final _prevRangeProvider = Provider<(String?, String?)>((ref) {
  final p = ref.watch(_periodProvider);
  final now = DateTime.now();
  return switch (p) {
    _Period.thisMonth => () {
        final first = DateTime(now.year, now.month - 1, 1);
        final last = DateTime(now.year, now.month, 0);
        return (_dateFmt.format(first), _dateFmt.format(last));
      }(),
    _Period.thisYear => ('${now.year - 1}-01-01', '${now.year - 1}-12-31'),
    _ => (null, null),
  };
});

// ── Data Providers ──

final _summaryProvider = FutureProvider<Map<String, num>>((ref) {
  final (f, t) = ref.watch(_dateRangeProvider);
  return ref.watch(saleDaoProvider).getSalesSummary(dateFrom: f, dateTo: t);
});

final _prevSummaryProvider = FutureProvider<Map<String, num>?>((ref) {
  final (f, t) = ref.watch(_prevRangeProvider);
  if (f == null) return Future.value(null);
  return ref.watch(saleDaoProvider).getSalesSummary(dateFrom: f, dateTo: t);
});

final _monthlyTrendProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  final (f, t) = ref.watch(_dateRangeProvider);
  return ref.watch(saleDaoProvider).getMonthlyTrend(dateFrom: f, dateTo: t);
});

final _brandProfitProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  final (f, t) = ref.watch(_dateRangeProvider);
  return ref.watch(saleDaoProvider).getBrandProfit(dateFrom: f, dateTo: t);
});

final _topProfitProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  final (f, t) = ref.watch(_dateRangeProvider);
  return ref
      .watch(saleDaoProvider)
      .getTopModels(limit: 10, ascending: false, dateFrom: f, dateTo: t);
});

final _topLossProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  final (f, t) = ref.watch(_dateRangeProvider);
  return ref
      .watch(saleDaoProvider)
      .getTopModels(limit: 10, ascending: true, dateFrom: f, dateTo: t);
});

final _topTabProvider = StateProvider<bool>((_) => true); // true=profit

final _modelSalesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, (String, String?, String?)>(
  (ref, args) => ref.watch(saleDaoProvider).getSalesByModelCode(
        args.$1,
        dateFrom: args.$2,
        dateTo: args.$3,
      ),
);

// ══════════════════════════════════════════════════════════════
// 메인 화면
// ══════════════════════════════════════════════════════════════

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('분석'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            onPressed: () {}, // 추후 내보내기
            tooltip: '내보내기',
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterChipBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _KpiGrid(),
                const SizedBox(height: 16),
                _ComboChart(),
                const SizedBox(height: 16),
                _BrandBarSection(),
                const SizedBox(height: 16),
                _TopModelsSection(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 기간 필터 칩 바
// ══════════════════════════════════════════════════════════════

class _FilterChipBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(_periodProvider);
    final customRange = ref.watch(_customRangeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String customLabel = '직접선택';
    if (period == _Period.custom && customRange != null) {
      final (f, t) = customRange;
      customLabel = '${f.substring(5)} ~ ${t.substring(5)}';
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _Chip(
              label: '이번달',
              active: period == _Period.thisMonth,
              onTap: () =>
                  ref.read(_periodProvider.notifier).state = _Period.thisMonth,
            ),
            const SizedBox(width: 8),
            _Chip(
              label: '올해',
              active: period == _Period.thisYear,
              onTap: () =>
                  ref.read(_periodProvider.notifier).state = _Period.thisYear,
            ),
            const SizedBox(width: 8),
            _Chip(
              label: '전체',
              active: period == _Period.all,
              onTap: () =>
                  ref.read(_periodProvider.notifier).state = _Period.all,
            ),
            const SizedBox(width: 8),
            _Chip(
              label: customLabel,
              active: period == _Period.custom,
              onTap: () async {
                final now = DateTime.now();
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  initialDateRange: DateTimeRange(
                    start: DateTime(now.year, 1, 1),
                    end: now,
                  ),
                );
                if (range != null) {
                  ref.read(_customRangeProvider.notifier).state = (
                    _dateFmt.format(range.start),
                    _dateFmt.format(range.end),
                  );
                  ref.read(_periodProvider.notifier).state = _Period.custom;
                }
              },
              icon: Icons.calendar_today,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 34,
        padding: EdgeInsets.symmetric(
            horizontal: icon != null ? 10 : 14, vertical: 0),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.textTertiary,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: active ? Colors.white : AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// KPI 2×3 그리드
// ══════════════════════════════════════════════════════════════

class _KpiGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currAsync = ref.watch(_summaryProvider);
    final prevAsync = ref.watch(_prevSummaryProvider);
    final period = ref.watch(_periodProvider);

    final compareLabel = switch (period) {
      _Period.thisMonth => '지난달 대비',
      _Period.thisYear => '전년 대비',
      _ => null,
    };

    return currAsync.when(
      data: (curr) {
        final prev = prevAsync.value;
        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.55,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _KpiCard(
              label: '총 판매액',
              value: '${_wonFmt.format(curr['totalSell'])}원',
              valueColor: AppColors.primary,
              delta: _delta(curr['totalSell'], prev?['totalSell'],
                  label: compareLabel),
            ),
            _KpiCard(
              label: '정산 금액',
              value: '${_wonFmt.format(curr['totalSettlement'])}원',
              valueColor: AppColors.success,
              delta: _delta(curr['totalSettlement'], prev?['totalSettlement'],
                  label: compareLabel),
            ),
            _KpiCard(
              label: '순이익',
              value: '${_wonFmt.format(curr['totalProfit'])}원',
              valueColor: (curr['totalProfit'] as num) >= 0
                  ? AppColors.success
                  : AppColors.error,
              delta: _delta(curr['totalProfit'], prev?['totalProfit'],
                  label: compareLabel),
            ),
            _KpiCard(
              label: '마진율',
              value:
                  '${(curr['marginRate'] as num).toStringAsFixed(1)}%',
              valueColor: AppColors.warning,
              delta: _deltaMargin(curr['marginRate'], prev?['marginRate'],
                  label: compareLabel),
            ),
            _KpiCard(
              label: '판매 건수',
              value: '${_wonFmt.format(curr['count'])}건',
              delta: _deltaCount(curr['count'], prev?['count'],
                  label: compareLabel),
            ),
            _KpiCard(
              label: '평균 단가',
              value: () {
                final cnt = (curr['count'] as num).toInt();
                final avg =
                    cnt > 0 ? (curr['totalSell'] as num) / cnt : 0;
                return '${_wonFmt.format(avg.round())}원';
              }(),
            ),
          ],
        );
      },
      loading: () => _shimmerGrid(),
      error: (e, _) => Text('$e',
          style: const TextStyle(color: AppColors.error, fontSize: 12)),
    );
  }

  _DeltaInfo? _delta(num? curr, num? prev, {String? label}) {
    if (prev == null || prev == 0 || label == null) return null;
    final d = curr! - prev;
    final pct = d / prev * 100;
    return _DeltaInfo(
      text: '${pct >= 0 ? '▲' : '▼'} ${pct.abs().toStringAsFixed(1)}%  $label',
      positive: d >= 0,
    );
  }

  _DeltaInfo? _deltaMargin(num? curr, num? prev, {String? label}) {
    if (prev == null || label == null) return null;
    final d = curr! - prev;
    return _DeltaInfo(
      text: '${d >= 0 ? '▲' : '▼'} ${d.abs().toStringAsFixed(1)}%p  $label',
      positive: d >= 0,
    );
  }

  _DeltaInfo? _deltaCount(num? curr, num? prev, {String? label}) {
    if (prev == null || label == null) return null;
    final d = (curr! - prev).toInt();
    return _DeltaInfo(
      text: '${d >= 0 ? '▲' : '▼'} ${d.abs()}건  $label',
      positive: d >= 0,
    );
  }

  Widget _shimmerGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.55,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(
          6,
          (_) => Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
              )),
    );
  }
}

class _DeltaInfo {
  final String text;
  final bool positive;
  const _DeltaInfo({required this.text, required this.positive});
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final _DeltaInfo? delta;

  const _KpiCard({
    required this.label,
    required this.value,
    this.valueColor,
    this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.textTertiary)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTheme.dataStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
          if (delta != null)
            Text(
              delta!.text,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: delta!.positive ? AppColors.success : AppColors.error,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Bar + Line 콤보 차트 (3단 스택 막대 + 총이익 선)
// ══════════════════════════════════════════════════════════════

class _ComboChart extends ConsumerWidget {
  static const _leftPad = 48.0;
  static const _bottomPad = 28.0;
  static const _rightPad = 32.0;

  static const _colorCost = Color(0xFF8B5CF6);    // 판매가 배경 (violet-500)
  static const _colorProfit = Color(0xFF22C55E);  // 순이익 (green-500)
  static const _colorVat = Color(0xFFF59E0B);     // 부가세환급 (amber-500)
  static const _colorLine = Color(0xFF1E293B);    // 총이익 선 (slate-800)

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_monthlyTrendProvider);
    return _chartCard(
      context,
      title: '월별 매출 · 이익',
      subtitle: '막대=정산구성  선=마진율',
      child: async.when(
        data: (data) {
          if (data.isEmpty) return _emptyState(context, '판매 데이터가 없습니다');

          final maxSettlement = data.fold<double>(
              0, (m, d) => max(m, (d['settlement'] as int).toDouble()));
          final chartMaxY = maxSettlement * 1.2;
          const chartMinY = 0.0;

          // 마진율 계산 (profit / settlement × 100)
          final marginRates = data.map((d) {
            final s = (d['settlement'] as int).toDouble();
            final p = (d['profit'] as int).toDouble();
            return s > 0 ? p / s * 100 : 0.0;
          }).toList();
          final maxMarginRate =
              max(marginRates.fold<double>(1.0, max), 1.0);
          // 마진율 0~max% → chartMaxY 5%~55% 구간에 매핑
          double marginToY(double rate) =>
              chartMaxY * 0.05 + (rate / maxMarginRate) * chartMaxY * 0.50;

          return SizedBox(
            height: 190,
            child: LayoutBuilder(builder: (context, constraints) {
              final plotWidth = constraints.maxWidth - _leftPad - _rightPad;
              const plotHeight = 190.0 - _bottomPad;
              final n = data.length;

              // fl_chart spaceEvenly 실제 공식:
              // gap = (plotWidth - n×barWidth) / (n+1)
              // bar center[i] = leftPad + (i+1)×gap + (i+0.5)×barWidth
              const barW = 14.0;
              final gap = n > 0 ? (plotWidth - n * barW) / (n + 1) : 0.0;

              // 각 막대 중심 픽셀 좌표 → 마진율 선
              final linePoints = List.generate(n, (i) {
                final px = _leftPad + (i + 1) * gap + (i + 0.5) * barW;
                final py =
                    plotHeight * (1 - marginToY(marginRates[i]) / chartMaxY);
                return Offset(px, py);
              });

              return Stack(
                children: [
                  // ── 3단 스택 막대 ──
                  BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceEvenly,
                      minY: chartMinY,
                      maxY: chartMaxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: chartMaxY > 0 ? chartMaxY / 4 : 1,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.border.withAlpha(80),
                          strokeWidth: 0.5,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: _rightPad,
                            interval: double.maxFinite,
                            getTitlesWidget: (_, __) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: _leftPad,
                            getTitlesWidget: (val, _) => Text(
                              _compact(val),
                              style: const TextStyle(
                                  fontSize: 9, color: AppColors.textTertiary),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: _bottomPad,
                            interval: 1,
                            getTitlesWidget: (val, _) {
                              final i = val.toInt();
                              if (i < 0 || i >= data.length) {
                                return const SizedBox();
                              }
                              final m = data[i]['month'] as String;
                              return Text(
                                m.length >= 7 ? m.substring(5) : m,
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textTertiary),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(data.length, (i) {
                        final settlement =
                            (data[i]['settlement'] as int).toDouble();
                        final profit = (data[i]['profit'] as int).toDouble();
                        final vat = (data[i]['vatRefund'] as int).toDouble();
                        // 스택 구간: VAT(아래) | 순이익(중간) | 원가 배경(위, rod 색상)
                        final safeVat = vat.clamp(0.0, settlement);
                        final safeProfit =
                            profit.clamp(0.0, settlement - safeVat);
                        final vatEnd = safeVat;
                        final profitEnd = safeVat + safeProfit;

                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: settlement,
                              width: 14,
                              // rod 전체를 보라로 채움 → 원가+수수료 배경 역할
                              color: _colorCost,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3)),
                              rodStackItems: [
                                // VAT·순이익 구간을 아래부터 덮어씌움
                                BarChartRodStackItem(0, vatEnd, _colorVat),
                                BarChartRodStackItem(
                                    vatEnd, profitEnd, _colorProfit),
                              ],
                            ),
                          ],
                        );
                      }),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, _, rod, __) {
                            final d = data[group.x];
                            final profit = d['profit'] as int;
                            final vat = d['vatRefund'] as int;
                            final settlement = rod.toY.toInt();
                            final marginRate = settlement > 0
                                ? profit / settlement * 100
                                : 0.0;
                            return BarTooltipItem(
                              '정산 ${_wonFmt.format(settlement)}원\n'
                              '순이익 ${_wonFmt.format(profit)}원\n'
                              'VAT환급 ${_wonFmt.format(vat)}원\n'
                              '마진율 ${marginRate.toStringAsFixed(1)}%',
                              const TextStyle(
                                  color: Colors.white, fontSize: 10),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  // ── 마진율 선 ──
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _ComboLinePainter(
                          points: linePoints, color: _colorLine),
                      size: Size(constraints.maxWidth, 190),
                    ),
                  ),
                  // ── 우측 마진율 % 레이블 (0% / 중간% / 최대%) ──
                  for (final rate in [0.0, maxMarginRate / 2, maxMarginRate])
                    Positioned(
                      right: 2,
                      top: plotHeight * (1 - marginToY(rate) / chartMaxY) - 6,
                      child: Text(
                        '${rate.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 9,
                          color: _colorLine.withAlpha(160),
                        ),
                      ),
                    ),
                ],
              );
            }),
          );
        },
        loading: () => _loadingState(),
        error: (e, _) => Text('$e',
            style: const TextStyle(color: AppColors.error, fontSize: 12)),
      ),
      legend: const Row(
        children: [
          _LegendDot(color: _colorCost, label: '판매가'),
          SizedBox(width: 8),
          _LegendDot(color: _colorProfit, label: '순이익'),
          SizedBox(width: 8),
          _LegendDot(color: _colorVat, label: 'VAT환급'),
          SizedBox(width: 8),
          _LegendLine(color: _colorLine, label: '마진율'),
        ],
      ),
    );
  }
}

// ── 총이익 선 CustomPainter ──
class _ComboLinePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  const _ComboLinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    final fillPaint = Paint()..color = color..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final p in points) {
      canvas.drawCircle(p, 4, fillPaint);
      canvas.drawCircle(p, 4, strokePaint);
    }
  }

  @override
  bool shouldRepaint(_ComboLinePainter old) => old.points != points;
}

// ══════════════════════════════════════════════════════════════
// 브랜드별 수익 수평 바 차트
// ══════════════════════════════════════════════════════════════

const _brandColors = [
  AppColors.primary,
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFF16A34A),
  AppColors.accent,
  AppColors.textTertiary,
];

class _BrandBarSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_brandProfitProvider);
    return _chartCard(
      context,
      title: '브랜드별 수익',
      child: async.when(
        data: (data) {
          if (data.isEmpty) return _emptyState(context, '데이터가 없습니다');
          final maxProfit = data.fold<int>(
              0, (m, d) => max(m, (d['profit'] as int)));
          if (maxProfit <= 0) return _emptyState(context, '수익 데이터가 없습니다');

          return Column(
            children: List.generate(data.length, (i) {
              final d = data[i];
              final profit = d['profit'] as int;
              final ratio = maxProfit > 0 ? profit / maxProfit : 0.0;
              final color = _brandColors[i % _brandColors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          d['brandName'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color,
                          ),
                        ),
                        Text(
                          '${_wonFmt.format(profit)}원  ${d['count']}건',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio.clamp(0.0, 1.0),
                        minHeight: 7,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
          );
        },
        loading: () => _loadingState(),
        error: (e, _) => Text('$e',
            style: const TextStyle(color: AppColors.error, fontSize: 12)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Top 모델 탭 + 펼침 카드
// ══════════════════════════════════════════════════════════════

class _TopModelsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isProfit = ref.watch(_topTabProvider);
    final provider = isProfit ? _topProfitProvider : _topLossProvider;
    final async = ref.watch(provider);
    final (dateFrom, dateTo) = ref.watch(_dateRangeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 탭 전환
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _TabBtn(
                label: '🏆 수익 Top 10',
                active: isProfit,
                onTap: () =>
                    ref.read(_topTabProvider.notifier).state = true,
              ),
              _TabBtn(
                label: '📉 손실 Top 10',
                active: !isProfit,
                onTap: () =>
                    ref.read(_topTabProvider.notifier).state = false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // 랭킹 카드 목록
        async.when(
          data: (data) {
            if (data.isEmpty) {
              return _emptyState(context, '데이터가 없습니다');
            }
            return Column(
              children: List.generate(data.length, (i) {
                final d = data[i];
                return _RankCard(
                  rank: i + 1,
                  modelCode: d['modelCode'] as String,
                  modelName: d['modelName'] as String,
                  count: d['count'] as int,
                  profit: d['profit'] as int,
                  dateFrom: dateFrom,
                  dateTo: dateTo,
                );
              }),
            );
          },
          loading: () => _loadingState(),
          error: (e, _) => Text('$e',
              style:
                  const TextStyle(color: AppColors.error, fontSize: 12)),
        ),
      ],
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 34,
          decoration: BoxDecoration(
            color: active ? Theme.of(context).cardTheme.color : null,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active
                  ? Theme.of(context).textTheme.bodyMedium?.color
                  : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── 랭킹 카드 (펼침 가능) ──

class _RankCard extends ConsumerStatefulWidget {
  final int rank;
  final String modelCode;
  final String modelName;
  final int count;
  final int profit;
  final String? dateFrom;
  final String? dateTo;

  const _RankCard({
    required this.rank,
    required this.modelCode,
    required this.modelName,
    required this.count,
    required this.profit,
    this.dateFrom,
    this.dateTo,
  });

  @override
  ConsumerState<_RankCard> createState() => _RankCardState();
}

class _RankCardState extends ConsumerState<_RankCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isProfit = widget.profit >= 0;
    final profitColor = isProfit ? AppColors.success : AppColors.error;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor = _expanded
        ? (isProfit
            ? AppColors.primary.withAlpha(100)
            : AppColors.error.withAlpha(100))
        : (isDark ? AppColors.darkBorder : AppColors.border);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: _expanded
            ? [
                BoxShadow(
                  color: (isProfit ? AppColors.primary : AppColors.error)
                      .withAlpha(20),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      child: Column(
        children: [
          // ── 헤더 (항상 표시) ──
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  _RankBadge(widget.rank),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.modelName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.modelCode}  ·  ${widget.count}건 판매',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isProfit ? '+' : ''}${_wonFmt.format(widget.profit)}원',
                        style: AppTheme.dataStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: profitColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _marginText(widget.profit, widget.count),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── 펼침 영역 ──
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _expanded
                ? _ExpandedContent(
                    modelCode: widget.modelCode,
                    dateFrom: widget.dateFrom,
                    dateTo: widget.dateTo,
                    isProfit: isProfit,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _marginText(int profit, int count) {
    if (count == 0) return '';
    return '건당 ${_wonFmt.format((profit / count).round())}원';
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge(this.rank);

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (rank) {
      1 => (const Color(0xFFF59E0B), Colors.white),
      2 => (const Color(0xFF94A3B8), Colors.white),
      3 => (const Color(0xFFCD7C3A), Colors.white),
      _ => (AppColors.surfaceVariant, AppColors.textSecondary),
    };
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: rank <= 3 ? 11 : 10,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

// ── 펼침 콘텐츠 (판매 기록 + 요약) ──

class _ExpandedContent extends ConsumerWidget {
  final String modelCode;
  final String? dateFrom;
  final String? dateTo;
  final bool isProfit;

  const _ExpandedContent({
    required this.modelCode,
    required this.dateFrom,
    required this.dateTo,
    required this.isProfit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async =
        ref.watch(_modelSalesProvider((modelCode, dateFrom, dateTo)));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final divColor = isDark ? AppColors.darkBorder : AppColors.borderLight;
    final bgColor = isDark
        ? AppColors.darkBackground.withAlpha(120)
        : AppColors.background;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: divColor),
        async.when(
          data: (records) {
            if (records.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '판매 기록이 없습니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }

            // 요약 계산
            final totalSell = records.fold<int>(
                0, (s, r) => s + (r['sellPrice'] as int));
            final totalProfit = records.fold<int>(
                0, (s, r) => s + (r['profit'] as int));
            final totalCost = records.fold<int>(
                0, (s, r) => s + (r['purchasePrice'] as int));
            final margin = totalCost > 0
                ? (totalProfit / totalCost * 100)
                : 0.0;

            return Column(
              children: [
                // 요약 통계 3칸
                IntrinsicHeight(
                  child: Row(
                    children: [
                      _SummaryCell(
                        label: '총 매출',
                        value: '${_wonFmt.format(totalSell)}원',
                        color: AppColors.primary,
                        bg: bgColor,
                      ),
                      VerticalDivider(width: 1, color: divColor),
                      _SummaryCell(
                        label: '총 구매원가',
                        value: '${_wonFmt.format(totalCost)}원',
                        bg: bgColor,
                      ),
                      VerticalDivider(width: 1, color: divColor),
                      _SummaryCell(
                        label: isProfit ? '평균 마진율' : '평균 손실률',
                        value:
                            '${margin >= 0 ? '+' : ''}${margin.toStringAsFixed(1)}%',
                        color: isProfit ? AppColors.success : AppColors.error,
                        bg: bgColor,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: divColor),
                // 컬럼 헤더
                Container(
                  color: isDark
                      ? AppColors.darkSurfaceVariant.withAlpha(80)
                      : AppColors.surfaceVariant,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  child: const Row(
                    children: [
                      SizedBox(
                          width: 52,
                          child: Text('날짜',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTertiary))),
                      SizedBox(
                          width: 36,
                          child: Text('사이즈',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTertiary))),
                      Expanded(
                          child: Text('수익률',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTertiary))),
                      SizedBox(
                          width: 64,
                          child: Text('판매가',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTertiary))),
                      SizedBox(
                          width: 56,
                          child: Text('이익',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTertiary))),
                    ],
                  ),
                ),
                Divider(height: 1, color: divColor),
                // 판매 기록 행들
                ...records.map((r) => _SaleRow(record: r, divColor: divColor)),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2))),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(12),
            child: Text('$e',
                style: const TextStyle(
                    color: AppColors.error, fontSize: 11)),
          ),
        ),
      ],
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final Color bg;

  const _SummaryCell({
    required this.label,
    required this.value,
    this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: bg,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: AppColors.textTertiary)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color ??
                      Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  final Map<String, dynamic> record;
  final Color divColor;

  const _SaleRow({required this.record, required this.divColor});

  @override
  Widget build(BuildContext context) {
    final profit = record['profit'] as int;
    final profitColor =
        profit >= 0 ? AppColors.success : AppColors.error;
    final date = (record['date'] as String).length >= 10
        ? (record['date'] as String).substring(5)
        : record['date'] as String;

    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(date,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textTertiary)),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  record['sizeKr'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: _MarginBar(
                  platform: record['platform'] as String,
                  margin: (record['purchasePrice'] as int) > 0
                      ? (record['profit'] as int) /
                          (record['purchasePrice'] as int) *
                          100
                      : 0.0,
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  _wonFmt.format(record['sellPrice']),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '${profit >= 0 ? '+' : ''}${_wonFmt.format(profit)}',
                  textAlign: TextAlign.right,
                  style: AppTheme.dataStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: profitColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: divColor),
      ],
    );
  }
}

// ── 수익률 3구간 인바디 바 ──

class _MarginBar extends StatelessWidget {
  final String platform;
  final double margin; // percent, 음수 가능

  const _MarginBar({required this.platform, required this.margin});

  @override
  Widget build(BuildContext context) {
    final isLow = margin < 0;
    final isMid = margin >= 0 && margin < 20;
    final isHigh = margin >= 20;

    const red = Color(0xFFEF4444);
    const amber = Color(0xFFF59E0B);
    const green = Color(0xFF86EFAC);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          platform,
          style: const TextStyle(fontSize: 8, color: AppColors.textTertiary),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: isLow ? red : red.withAlpha(40),
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(2)),
                ),
              ),
            ),
            const SizedBox(width: 1),
            Expanded(
              child: Container(
                height: 6,
                color: isMid ? amber : amber.withAlpha(40),
              ),
            ),
            const SizedBox(width: 1),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: isHigh ? green : green.withAlpha(40),
                  borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(2)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 공통 헬퍼
// ══════════════════════════════════════════════════════════════

Widget _chartCard(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget child,
  Widget? legend,
}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withAlpha(30),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const Spacer(),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textTertiary)),
            ],
          ],
        ),
        const SizedBox(height: 12),
        child,
        if (legend != null) ...[const SizedBox(height: 8), legend],
      ],
    ),
  );
}

Widget _emptyState(BuildContext context, String msg) => SizedBox(
      height: 80,
      child: Center(
        child: Text(msg,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textTertiary)),
      ),
    );

Widget _loadingState() => const SizedBox(
      height: 80,
      child: Center(
          child: CircularProgressIndicator(strokeWidth: 2)),
    );

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _LegendLine extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendLine({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 16,
            height: 2,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(1))),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

String _compact(double val) {
  if (val.abs() >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
  if (val.abs() >= 1000) return '${(val / 1000).toStringAsFixed(0)}K';
  return val.toStringAsFixed(0);
}
