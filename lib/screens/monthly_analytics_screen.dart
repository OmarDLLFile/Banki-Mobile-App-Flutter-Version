import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../widgets/aurora_background.dart';
import '../widgets/top_right_back_button.dart';

class MonthlyAnalyticsScreen extends StatefulWidget {
  const MonthlyAnalyticsScreen({super.key});

  @override
  State<MonthlyAnalyticsScreen> createState() => _MonthlyAnalyticsScreenState();
}

class _MonthlyAnalyticsScreenState extends State<MonthlyAnalyticsScreen> {
  static const List<String> monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  bool showBarChart = false;
  int highlightedMonth = DateTime.now().month - 1;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> monthlyDataStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    monthlyDataStream = FirebaseFirestore.instance
        .collection("transactions")
        .where("userId", isEqualTo: uid)
        .snapshots();
  }

  List<double> loadMonthlyData(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final months = List<double>.filled(12, 0);

    for (final doc in docs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0).toDouble();
      final timestamp = data['timestamp'];

      if (timestamp == null || timestamp is! Timestamp) {
        continue;
      }

      final monthIndex = timestamp.toDate().month - 1;
      months[monthIndex] += amount;
    }

    return months;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Monthly Analytics"),
        actions: const [TopRightBackButton()],
      ),
      body: AuroraBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth > 780
                ? 740.0
                : constraints.maxWidth;
            final summaryCardWidth = contentWidth > 560
                ? (contentWidth - 12) / 2
                : contentWidth;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: monthlyDataStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = loadMonthlyData(snapshot.data!.docs);
                final peakValue = data.reduce((a, b) => a > b ? a : b);
                final total = data.fold<double>(
                  0,
                  (runningTotal, value) => runningTotal + value,
                );
                final selectedValue = data[highlightedMonth];

                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: contentWidth,
                    child: ListView(
                      padding: const EdgeInsets.only(top: 72, bottom: 20),
                      children: [
                        FrostedPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Monthly Flow",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Tap any month to spotlight it or switch the chart mode.",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: summaryCardWidth,
                                    child: _summaryCard(
                                      "Total Yearly Volume",
                                      '\$${total.toStringAsFixed(2)}',
                                      const Color(0xFF7BFFD4),
                                    ),
                                  ),
                                  SizedBox(
                                    width: summaryCardWidth,
                                    child: _summaryCard(
                                      "Peak Month",
                                      monthLabels[data.indexOf(peakValue)],
                                      const Color(0xFF7AA8FF),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        FrostedPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SegmentedButton<bool>(
                                    segments: const [
                                      ButtonSegment<bool>(
                                        value: false,
                                        label: Text('Line'),
                                        icon: Icon(Icons.show_chart_rounded),
                                      ),
                                      ButtonSegment<bool>(
                                        value: true,
                                        label: Text('Bars'),
                                        icon: Icon(Icons.bar_chart_rounded),
                                      ),
                                    ],
                                    selected: {showBarChart},
                                    onSelectionChanged: (selection) {
                                      setState(() {
                                        showBarChart = selection.first;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                height: contentWidth < 420 ? 280 : 320,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 450),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: showBarChart
                                      ? _buildBarChart(data, peakValue)
                                      : _buildLineChart(data, peakValue),
                                ),
                              ),
                              const SizedBox(height: 18),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.white.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_month_rounded,
                                      color: Color(0xFF7BFFD4),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            monthLabels[highlightedMonth],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Volume: \$${selectedValue.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.72,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _summaryCard(String title, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<double> data, double peakValue) {
    return LineChart(
      key: const ValueKey('line'),
      LineChartData(
        minY: 0,
        maxY: peakValue == 0 ? 100 : peakValue * 1.25,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: peakValue == 0 ? 25 : peakValue / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _buildTitles(),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBorder: BorderSide.none,
            tooltipRoundedRadius: 14,
            getTooltipColor: (_) => const Color(0xFF14303B),
          ),
          touchCallback: (event, response) {
            if (response?.lineBarSpots?.isNotEmpty == true) {
              setState(() {
                highlightedMonth = response!.lineBarSpots!.first.x
                    .toInt()
                    .clamp(0, 11);
              });
            }
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              data.length,
              (i) => FlSpot(i.toDouble(), data[i]),
            ),
            isCurved: true,
            barWidth: 5,
            color: const Color(0xFF7BFFD4),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final active = index == highlightedMonth;

                return FlDotCirclePainter(
                  radius: active ? 6 : 4,
                  color: active
                      ? const Color(0xFF7AA8FF)
                      : const Color(0xFF7BFFD4),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF7BFFD4).withValues(alpha: 0.36),
                  const Color(0xFF7BFFD4).withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<double> data, double peakValue) {
    return BarChart(
      key: const ValueKey('bar'),
      BarChartData(
        minY: 0,
        maxY: peakValue == 0 ? 100 : peakValue * 1.25,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: peakValue == 0 ? 25 : peakValue / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _buildTitles(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 14,
            getTooltipColor: (_) => const Color(0xFF14303B),
          ),
          touchCallback: (event, response) {
            if (response?.spot != null) {
              setState(() {
                highlightedMonth = response!.spot!.touchedBarGroupIndex;
              });
            }
          },
        ),
        barGroups: List.generate(data.length, (index) {
          final active = index == highlightedMonth;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data[index],
                width: 18,
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: active
                      ? [const Color(0xFF7AA8FF), const Color(0xFF7BFFD4)]
                      : [
                          const Color(0xFF7BFFD4).withValues(alpha: 0.7),
                          const Color(0xFF7AA8FF).withValues(alpha: 0.6),
                        ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  FlTitlesData _buildTitles() {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= monthLabels.length) {
              return const SizedBox.shrink();
            }

            final active = index == highlightedMonth;

            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                monthLabels[index],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? const Color(0xFF7BFFD4) : Colors.white70,
                ),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          getTitlesWidget: (value, meta) {
            return Text(
              value.toInt().toString(),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            );
          },
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }
}
