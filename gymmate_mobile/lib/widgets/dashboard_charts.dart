import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;

class DashboardChart extends StatelessWidget {
  final List<charts.Series<dynamic, String>> seriesList;
  final bool animate;
  final String title;

  const DashboardChart({
    Key? key,
    required this.seriesList,
    this.animate = true,
    required this.title,
  }) : super(key: key);

  /// Create with mock data for testing
  factory DashboardChart.withSampleData(String title) {
    return DashboardChart(
      title: title,
      seriesList: _createSampleData(),
      animate: true,
    );
  }

  factory DashboardChart.createGymSampleData() {
    final gymData = [
      ChartData('Mon', 5),
      ChartData('Tue', 10),
      ChartData('Wed', 7),
      ChartData('Thu', 12),
      ChartData('Fri', 9),
      ChartData('Sat', 15),
      ChartData('Sun', 8),
    ];

    final series = [
      charts.Series<ChartData, String>(
        id: 'Weekly Check-ins',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (ChartData data, _) => data.day,
        measureFn: (ChartData data, _) => data.count,
        data: gymData,
      )
    ];

    return DashboardChart(
      title: 'Weekly Gym Check-ins',
      seriesList: series,
      animate: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      color: Theme.of(context).cardColor.withOpacity(0.95),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Divider(thickness: 1.2),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: charts.BarChart(
                seriesList,
                animate: animate,
                animationDuration: const Duration(milliseconds: 600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<charts.Series<ChartData, String>> _createSampleData() {
    final data = [
      ChartData('Strength', 45),
      ChartData('Cardio', 30),
      ChartData('Zumba', 15),
      ChartData('Yoga', 20),
      ChartData('Crossfit', 10),
    ];

    return [
      charts.Series<ChartData, String>(
        id: 'Members by Activity',
        colorFn: (_, __) => charts.MaterialPalette.purple.shadeDefault,
        domainFn: (ChartData data, _) => data.day,
        measureFn: (ChartData data, _) => data.count,
        data: data,
      )
    ];
  }
}

class ChartData {
  final String day;
  final int count;

  ChartData(this.day, this.count);
}