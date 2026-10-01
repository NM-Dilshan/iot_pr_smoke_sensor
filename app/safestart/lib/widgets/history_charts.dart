import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/history_analytics.dart';
import '../models/history_filter.dart';
import '../models/safety_status.dart';
import '../theme/app_colors.dart';
import 'custom_card.dart';

Color historyStatusColor(SafetyStatus status) => switch (status) {
  SafetyStatus.safe => AppColors.safe,
  SafetyStatus.caution => AppColors.caution,
  SafetyStatus.danger => AppColors.danger,
};

class HistoryTrendChart extends StatelessWidget {
  const HistoryTrendChart({
    super.key,
    required this.points,
    required this.title,
  });
  final List<HistoryTrendPoint> points;
  final String title;

  @override
  Widget build(BuildContext context) => CustomCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        const Text(
          'Daily average · filtered demo records',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        const Text('Prototype Sensor Reading', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        if (points.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No trend data for this period.'),
          )
        else
          Semantics(
            label: points
                .map(
                  (p) =>
                      '${historyDate(p.date)}: ${p.averageReading.toStringAsFixed(3)}',
                )
                .join('; '),
            child: SizedBox(
              height: 210,
              child: CustomPaint(painter: _TrendPainter(points)),
            ),
          ),
        const Text(
          'Day / Date',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.points);
  final List<HistoryTrendPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(38, 12, size.width - 18, size.height - 32);
    final maxValue = math.max(
      0.1,
      (points.map((p) => p.averageReading).reduce(math.max) * 10).ceil() / 10,
    );
    void label(String text, Offset offset, {bool centered = false}) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(color: AppColors.secondaryText, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          centered
              ? (offset.dx - painter.width / 2).clamp(
                  0,
                  size.width - painter.width,
                )
              : offset.dx,
          offset.dy,
        ),
      );
    }

    for (var i = 0; i <= 4; i++) {
      final y = plot.bottom - plot.height * i / 4;
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        Paint()..color = AppColors.border,
      );
      label((maxValue * i / 4).toStringAsFixed(2), Offset(0, y - 6));
    }
    final first = points.first.date.millisecondsSinceEpoch;
    final span = points.last.date.millisecondsSinceEpoch - first;
    Offset position(HistoryTrendPoint point) => Offset(
      span == 0
          ? plot.center.dx
          : plot.left +
                plot.width * (point.date.millisecondsSinceEpoch - first) / span,
      plot.bottom - plot.height * point.averageReading / maxValue,
    );
    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final point = position(points[i]);
      if (i == 0) {
        line.moveTo(point.dx, point.dy);
      } else {
        line.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.gold
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    for (final point in points) {
      canvas.drawCircle(position(point), 3.5, Paint()..color = AppColors.gold);
    }
    for (final index in {0, points.length ~/ 2, points.length - 1}) {
      final point = points[index];
      label(
        '${point.date.month}/${point.date.day}',
        Offset(position(point).dx, plot.bottom + 12),
        centered: true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points;
}

class HistoryStatusChart extends StatelessWidget {
  const HistoryStatusChart({super.key, required this.analytics});
  final HistoryAnalytics analytics;

  @override
  Widget build(BuildContext context) => CustomCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Test Status Summary',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (final status in SafetyStatus.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${status.name.toUpperCase()}: ${analytics.count(status)} (${analytics.percentage(status).toStringAsFixed(1)}%)',
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: analytics.percentage(status) / 100,
                  color: historyStatusColor(status),
                  backgroundColor: AppColors.border,
                  minHeight: 10,
                  semanticsLabel: '${status.name} percentage',
                  semanticsValue:
                      '${analytics.percentage(status).toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
