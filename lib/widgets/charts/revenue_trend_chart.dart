import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class RevenueTrendChart extends StatelessWidget {
  final Map<String, double> monthlyRevenue;

  const RevenueTrendChart({super.key, required this.monthlyRevenue});

  @override
  Widget build(BuildContext context) {
    if (monthlyRevenue.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('No revenue data', style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
      );
    }

    final entries = monthlyRevenue.entries.toList();
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
            getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(entries[idx].key, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  );
                },
                reservedSize: 28,
                interval: 1,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  String label;
                  if (value >= 100000) {
                    label = '${(value / 100000).toStringAsFixed(1)}L';
                  } else if (value >= 1000) {
                    label = '${(value / 1000).toStringAsFixed(0)}K';
                  } else {
                    label = value.toInt().toString();
                  }
                  return Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted));
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (entries.length - 1).toDouble(),
          minY: 0,
          maxY: maxVal * 1.15,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((spot) {
                final idx = spot.x.toInt();
                return LineTooltipItem(
                  '${entries[idx].key}\n₹${spot.y.toStringAsFixed(0)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppColors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(radius: 4, color: AppColors.primary, strokeWidth: 2, strokeColor: Colors.white),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.primary.withValues(alpha: 0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
