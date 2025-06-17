
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: charts.BarChart(
                seriesList,
                animate: animate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<charts.Series<ChartData, String>> _createSampleData() {
    final data = [
      ChartData('Mon', 12),
      ChartData('Tue', 18),
      ChartData('Wed', 8),
      ChartData('Thu', 15),
      ChartData('Fri', 10),
    ];

    return [
      charts.Series<ChartData, String>(
        id: 'Visits',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
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