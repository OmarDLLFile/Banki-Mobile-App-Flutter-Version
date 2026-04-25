import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../widgets/aurora_background.dart';
import '../widgets/top_right_back_button.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int touchedIndex = -1;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> statsStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    statsStream = FirebaseFirestore.instance
        .collection("transactions")
        .where("userId", isEqualTo: uid)
        .snapshots();
  }

  Map<String, double> loadStats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    double deposit = 0;
    double withdraw = 0;
    double transfer = 0;
    double billPayment = 0;

    for (final doc in docs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0).toDouble();

      switch (data['type']) {
        case 'deposit':
          deposit += amount;
          break;
        case 'withdraw':
          withdraw += amount;
          break;
        case 'transfer_sent':
          transfer += amount;
          break;
        case 'bill_payment':
          billPayment += amount;
          break;
      }
    }

    return {
      "deposit": deposit,
      "withdraw": withdraw,
      "transfer": transfer,
      "billPayment": billPayment,
    };
  }

  List<_AnalyticsSlice> buildSlices(Map<String, double> stats) {
    return [
      _AnalyticsSlice(
        label: 'Deposit',
        value: stats['deposit'] ?? 0,
        color: const Color(0xFF3CE6B0),
        icon: Icons.arrow_downward_rounded,
      ),
      _AnalyticsSlice(
        label: 'Withdraw',
        value: stats['withdraw'] ?? 0,
        color: const Color(0xFFFF7E79),
        icon: Icons.arrow_upward_rounded,
      ),
      _AnalyticsSlice(
        label: 'Transfer',
        value: stats['transfer'] ?? 0,
        color: const Color(0xFF7AA8FF),
        icon: Icons.send_rounded,
      ),
      _AnalyticsSlice(
        label: 'Bills',
        value: stats['billPayment'] ?? 0,
        color: const Color(0xFFE6C15A),
        icon: Icons.receipt_long_rounded,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Analytics"),
        actions: const [TopRightBackButton()],
      ),
      body: AuroraBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth > 780
                ? 740.0
                : constraints.maxWidth;
            final cardWidth = contentWidth > 560
                ? (contentWidth - 12) / 2
                : contentWidth;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: statsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final stats = loadStats(snapshot.data!.docs);
                final slices = buildSlices(stats);
                final total = slices.fold<double>(
                  0,
                  (runningTotal, slice) => runningTotal + slice.value,
                );

                final activeIndex = touchedIndex >= 0 ? touchedIndex : 0;
                final activeSlice = slices[activeIndex];

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
                                "Interactive Cashflow",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Tap a segment to spotlight where your money moves.",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: slices.map((slice) {
                                  final percent = total == 0
                                      ? 0.0
                                      : (slice.value / total) * 100;

                                  return SizedBox(
                                    width: cardWidth,
                                    child: _metricCard(slice, percent),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        FrostedPanel(
                          child: Column(
                            children: [
                              SizedBox(
                                height: contentWidth < 420 ? 236 : 268,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    PieChart(
                                      PieChartData(
                                        sectionsSpace: 4,
                                        centerSpaceRadius: contentWidth < 420
                                            ? 56
                                            : 70,
                                        pieTouchData: PieTouchData(
                                          touchCallback: (event, response) {
                                            setState(() {
                                              if (!event
                                                      .isInterestedForInteractions ||
                                                  response?.touchedSection ==
                                                      null) {
                                                touchedIndex = -1;
                                                return;
                                              }

                                              touchedIndex = response!
                                                  .touchedSection!
                                                  .touchedSectionIndex;
                                            });
                                          },
                                        ),
                                        sections: List.generate(slices.length, (
                                          index,
                                        ) {
                                          final slice = slices[index];
                                          final isTouched =
                                              index == touchedIndex;
                                          final percent = total == 0
                                              ? 0
                                              : (slice.value / total) * 100;

                                          return PieChartSectionData(
                                            value: slice.value == 0
                                                ? 0.01
                                                : slice.value,
                                            color: slice.color,
                                            radius: isTouched ? 84 : 72,
                                            title: percent == 0
                                                ? ''
                                                : '${percent.toStringAsFixed(0)}%',
                                            titleStyle: TextStyle(
                                              fontSize: contentWidth < 420
                                                  ? 12
                                                  : 14,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          );
                                        }),
                                      ),
                                      swapAnimationDuration: const Duration(
                                        milliseconds: 900,
                                      ),
                                      swapAnimationCurve: Curves.easeOutQuart,
                                    ),
                                    SizedBox(
                                      width: contentWidth < 420 ? 108 : 132,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            activeSlice.icon,
                                            color: activeSlice.color,
                                            size: 28,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            activeSlice.label,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '\$${activeSlice.value.toStringAsFixed(2)}',
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: contentWidth < 420
                                                    ? 17
                                                    : 20,
                                                fontWeight: FontWeight.w800,
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

  Widget _metricCard(_AnalyticsSlice slice, double percent) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(slice.icon, color: slice.color),
          const SizedBox(height: 10),
          Text(
            slice.label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${slice.value.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${percent.toStringAsFixed(1)}% of total',
            style: TextStyle(color: slice.color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsSlice {
  const _AnalyticsSlice({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;
}
