import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import 'report.dart';

const double _height = 170;
const double _leftPad = 44;
const double _topPad = 8;
const double _bottomPad = 20;

class DailyBarChart extends StatefulWidget {
  const DailyBarChart({super.key, required this.days});

  final List<DailyTotal> days;

  @override
  State<DailyBarChart> createState() => _DailyBarChartState();
}

class _DailyBarChartState extends State<DailyBarChart> {
  int? _selected;

  int? _indexAt(double dx, double width) {
    if (widget.days.isEmpty || dx < _leftPad) return null;

    final groupWidth = (width - _leftPad) / widget.days.length;
    return ((dx - _leftPad) / groupWidth).floor().clamp(0, widget.days.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedDay = _selected == null ? null : widget.days[_selected!];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            return GestureDetector(
              onTapDown: (details) =>
                  setState(() => _selected = _indexAt(details.localPosition.dx, width)),
              child: CustomPaint(
                size: Size(width, _height),
                painter: _ChartPainter(
                  days: widget.days,
                  selected: _selected,
                  incomeColor: const Color(0xFF10B981),
                  expenseColor: const Color(0xFFF43F5E),
                  gridColor: theme.colorScheme.outlineVariant,
                  textColor: theme.colorScheme.outline,
                  highlightColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _legend(const Color(0xFF10B981), 'Pemasukan'),
            const SizedBox(width: 16),
            _legend(const Color(0xFFF43F5E), 'Pengeluaran'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          selectedDay == null
              ? 'Ketuk satu hari untuk melihat rinciannya.'
              : '${formatDate(selectedDay.date)}: pemasukan ${formatRupiah(selectedDay.income)}, '
                  'pengeluaran ${formatRupiah(selectedDay.expense)}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.days,
    required this.selected,
    required this.incomeColor,
    required this.expenseColor,
    required this.gridColor,
    required this.textColor,
    required this.highlightColor,
  });

  final List<DailyTotal> days;
  final int? selected;
  final Color incomeColor;
  final Color expenseColor;
  final Color gridColor;
  final Color textColor;
  final Color highlightColor;

  static final NumberFormat _compact = NumberFormat.compact(locale: 'id_ID');

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;

    final plotHeight = size.height - _topPad - _bottomPad;
    final plotWidth = size.width - _leftPad;
    final maxValue = days.fold<int>(1, (max, day) => math.max(max, math.max(day.income, day.expense)));

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (final ratio in const [0.0, 0.5, 1.0]) {
      final y = _topPad + plotHeight - ratio * plotHeight;
      canvas.drawLine(Offset(_leftPad, y), Offset(size.width, y), gridPaint);
      _text(
        canvas,
        _compact.format(maxValue * ratio),
        Offset(0, y - 6),
        width: _leftPad - 6,
        align: TextAlign.right,
      );
    }

    final groupWidth = plotWidth / days.length;
    final barWidth = math.max(2.0, (groupWidth - 3) / 2);
    final incomePaint = Paint()..color = incomeColor;
    final expensePaint = Paint()..color = expenseColor;

    for (var i = 0; i < days.length; i++) {
      final x = _leftPad + i * groupWidth;

      if (selected == i) {
        canvas.drawRect(
          Rect.fromLTWH(x, _topPad, groupWidth, plotHeight),
          Paint()..color = highlightColor,
        );
      }

      _bar(canvas, x + 1, days[i].income, maxValue, plotHeight, barWidth, incomePaint);
      _bar(canvas, x + 1 + barWidth, days[i].expense, maxValue, plotHeight, barWidth, expensePaint);

      if (i == 0 || (i + 1) % 5 == 0) {
        final dayNumber = int.parse(days[i].date.substring(8));
        _text(
          canvas,
          '$dayNumber',
          Offset(x + groupWidth / 2 - 12, size.height - _bottomPad + 4),
          width: 24,
          align: TextAlign.center,
        );
      }
    }
  }

  void _bar(
    Canvas canvas,
    double x,
    int value,
    int maxValue,
    double plotHeight,
    double barWidth,
    Paint paint,
  ) {
    if (value <= 0) return;

    final height = math.max(2.0, value / maxValue * plotHeight);
    canvas.drawRect(
      Rect.fromLTWH(x, _topPad + plotHeight - height, barWidth, height),
      paint,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset, {
    required double width,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: 9, color: textColor)),
      textAlign: align,
      textDirection: ui.TextDirection.ltr,
    )..layout(minWidth: width, maxWidth: width);

    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) {
    return old.days != days || old.selected != selected;
  }
}