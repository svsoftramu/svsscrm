import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ConversionRateChart extends StatelessWidget {
  final int totalLeads;
  final int convertedLeads;

  const ConversionRateChart({super.key, required this.totalLeads, required this.convertedLeads});

  @override
  Widget build(BuildContext context) {
    if (totalLeads == 0) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('No conversion data', style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
      );
    }

    final rate = (convertedLeads / totalLeads * 100);
    final remaining = totalLeads - convertedLeads;

    return SizedBox(
      height: 180,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 36,
                sections: [
                  PieChartSectionData(
                    value: convertedLeads.toDouble(),
                    color: AppColors.success,
                    title: '${rate.toStringAsFixed(1)}%',
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    radius: 45,
                  ),
                  PieChartSectionData(
                    value: remaining.toDouble(),
                    color: const Color(0xFFE2E8F0),
                    title: '',
                    radius: 40,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegendItem(color: AppColors.success, label: 'Converted', value: '$convertedLeads'),
              const SizedBox(height: 8),
              _LegendItem(color: const Color(0xFFE2E8F0), label: 'Pending', value: '$remaining'),
              const SizedBox(height: 12),
              Text('${rate.toStringAsFixed(1)}% rate', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }
}
