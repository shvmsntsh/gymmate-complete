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
        colorFn: (_, __) => charts.ColorUtil.fromDartColor(Colors.amber.shade400),
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
    return SizedBox(
      height: 180,
      child: charts.BarChart(
        seriesList,
        animate: animate,
        animationDuration: const Duration(milliseconds: 600),
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
        colorFn: (_, __) => charts.ColorUtil.fromDartColor(Colors.amber.shade400),
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