import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SalesPipelineChart extends StatelessWidget {
  final Map<String, int> stageData;

  const SalesPipelineChart({super.key, required this.stageData});

  @override
  Widget build(BuildContext context) {
    if (stageData.isEmpty || stageData.values.every((v) => v == 0)) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('No pipeline data', style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
      );
    }

    final entries = stageData.entries.toList();
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${entries[groupIndex].key}\n${rod.toY.toInt()}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(entries[idx].key, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: entries.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value.toDouble(),
                  color: _stageColor(entry.value.key),
                  width: 28,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _stageColor(String stage) {
    switch (stage.toLowerCase()) {
      case 'new': return AppColors.primary;
      case 'contacted': return AppColors.info;
      case 'qualified': return AppColors.warning;
      case 'proposal': return AppColors.accent;
      case 'won': return AppColors.success;
      case 'lost': return AppColors.error;
      default: return AppColors.textMuted;
    }
  }
}
