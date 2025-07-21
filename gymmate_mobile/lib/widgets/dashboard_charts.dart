import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;

class DashboardChart extends StatefulWidget {
  final List<charts.Series<dynamic, String>> seriesList;
  final bool animate;
  final String title;
  final bool showPercentages;

  const DashboardChart({
    Key? key,
    required this.seriesList,
    this.animate = true,
    required this.title,
    this.showPercentages = false,
  }) : super(key: key);

  @override
  State<DashboardChart> createState() => _DashboardChartState();
}

enum ChartType { bar, donut, line }

class _DashboardChartState extends State<DashboardChart> {
  ChartType _chartType = ChartType.bar;

  // Helper to convert List<Series<dynamic, String>> to List<Series<dynamic, num>> for line chart
  List<charts.Series<dynamic, num>> _convertSeriesToNum(List<charts.Series<dynamic, String>> stringSeriesList) {
    return stringSeriesList.map((series) {
      return charts.Series<dynamic, num>(
        id: series.id,
        colorFn: series.colorFn != null
            ? (dynamic d, int? i) => series.colorFn!(d)
            : null,
        domainFn: (dynamic d, int? i) => i ?? 0, // Always use the index for the x value
        measureFn: series.measureFn != null
            ? (dynamic d, int? i) => series.measureFn!(d) ?? 0
            : (dynamic d, int? i) => 0,
        data: series.data,
        labelAccessorFn: series.labelAccessorFn != null
            ? (dynamic d, int? i) => series.labelAccessorFn!(d)
            : null,
      );
    }).toList();
  }

  // Helper: Check if all data is empty (not just zero)
  bool _isDataEmpty() {
    if (widget.seriesList.isEmpty) return true;
    for (final series in widget.seriesList) {
      if (series.data.isEmpty) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.primary;
    final chartHeight = 180.0;
    final cardColor = theme.brightness == Brightness.dark
        ? Color(0xFF232012) // custom dark card
        : theme.cardColor;
    final borderRadius = BorderRadius.circular(16);
    final boxShadow = [
      BoxShadow(
        color: theme.brightness == Brightness.dark
            ? Colors.black.withOpacity(0.18)
            : Colors.grey.withOpacity(0.10),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];

    // Check for empty data (not all-zero)
    final isEmpty = _isDataEmpty();

    Widget chartWidget;
    if (isEmpty) {
      chartWidget = Center(
        child: Text(
          'No data',
          style: theme.textTheme.bodyMedium?.copyWith(color: gold.withOpacity(0.7)),
        ),
      );
    } else {
      switch (_chartType) {
        case ChartType.bar:
          chartWidget = charts.BarChart(
            widget.seriesList,
            animate: widget.animate,
            animationDuration: const Duration(milliseconds: 600),
            // No legend behavior here
          );
          break;
        case ChartType.line:
          // Build a num-indexed series for the line chart
          final lineSeriesList = widget.seriesList.map((series) {
            charts.Color colorFn(dynamic d, [int? i]) {
              try {
                final result = Function.apply(series.colorFn!, [d, i]);
                if (result is charts.Color) return result;
                return charts.MaterialPalette.blue.shadeDefault;
              } catch (_) {
                try {
                  final result = Function.apply(series.colorFn!, [d]);
                  if (result is charts.Color) return result;
                  return charts.MaterialPalette.blue.shadeDefault;
                } catch (_) {
                  return charts.MaterialPalette.blue.shadeDefault;
                }
              }
            }
            num? measureFn(dynamic d, [int? i]) {
              try {
                return Function.apply(series.measureFn!, [d, i]) as num?;
              } catch (_) {
                return Function.apply(series.measureFn!, [d]) as num?;
              }
            }
            String? labelAccessorFn(dynamic d, [int? i]) {
              if (series.labelAccessorFn == null) return null;
              try {
                return Function.apply(series.labelAccessorFn!, [d, i]) as String?;
              } catch (_) {
                return Function.apply(series.labelAccessorFn!, [d]) as String?;
              }
            }
            return charts.Series<dynamic, num>(
              id: series.id,
              colorFn: series.colorFn != null ? (d, i) => colorFn(d, i) : null,
              domainFn: (d, i) => i ?? 0,
              measureFn: series.measureFn != null ? (d, i) => measureFn(d, i) ?? 0 : (d, i) => 0,
              data: series.data,
              labelAccessorFn: series.labelAccessorFn != null ? (d, i) => labelAccessorFn(d, i) ?? '' : null,
            );
          }).toList();
          // Build tick labels for the x axis
          final tickLabels = widget.seriesList.isNotEmpty
              ? widget.seriesList.first.data.asMap().map((i, d) {
                  String label = '';
                  try {
                    label = widget.seriesList.first.domainFn!(d);
                  } catch (_) {
                    label = d.toString();
                  }
                  return MapEntry(i, label);
                })
              : <int, String>{};
          chartWidget = charts.LineChart(
            lineSeriesList,
            animate: widget.animate,
            animationDuration: const Duration(milliseconds: 600),
            defaultRenderer: charts.LineRendererConfig(includePoints: true),
            domainAxis: charts.NumericAxisSpec(
              tickProviderSpec: charts.StaticNumericTickProviderSpec(
                tickLabels.keys.map((i) => charts.TickSpec(i as num)).toList(),
              ),
              tickFormatterSpec: charts.BasicNumericTickFormatterSpec((num? value) {
                if (value == null) return '';
                return tickLabels[value.toInt()] ?? '';
              }),
            ),
          );
          break;
        case ChartType.donut:
          chartWidget = SizedBox(
            width: chartHeight,
            height: chartHeight,
            child: charts.PieChart(
              widget.seriesList,
              animate: widget.animate,
              animationDuration: const Duration(milliseconds: 600),
              defaultRenderer: charts.ArcRendererConfig<String>(
                arcWidth: 36,
                arcRendererDecorators: [
                  charts.ArcLabelDecorator(
                    labelPosition: charts.ArcLabelPosition.inside,
                    insideLabelStyleSpec: charts.TextStyleSpec(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? charts.MaterialPalette.white
                          : charts.MaterialPalette.black,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
          break;
      }
    }

    Widget chartContainer;
    if (_chartType == ChartType.donut && !isEmpty) {
      chartContainer = SizedBox(
        width: chartHeight,
        height: chartHeight,
        child: chartWidget,
      );
    } else {
      chartContainer = Expanded(child: chartWidget);
    }

    return Container(
      height: chartHeight,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: borderRadius,
        border: Border.all(color: gold.withOpacity(0.25), width: 1.2),
        boxShadow: boxShadow,
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          chartContainer,
          Column(
            children: [
              const SizedBox(height: 8),
              PopupMenuButton<ChartType>(
                icon: const Icon(Icons.bar_chart, size: 22),
                onSelected: (type) => setState(() => _chartType = type),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: ChartType.bar,
                    child: Row(children: [Icon(Icons.bar_chart), SizedBox(width: 8), Text('Bar')]),
                  ),
                  PopupMenuItem(
                    value: ChartType.donut,
                    child: Row(children: [Icon(Icons.donut_large), SizedBox(width: 8), Text('Donut')]),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChartData {
  final String day;
  final int count;

  ChartData(this.day, this.count);
}