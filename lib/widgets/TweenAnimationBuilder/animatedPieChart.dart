import 'dart:math' as math;
import 'package:flutter/foundation.dart'; // para listEquals
import 'package:flutter/material.dart';

class AnimatedPieChart extends StatefulWidget {
  final List<double> percentages;
  final List<Color> colors;
  final double donutThickness;
  final double spaceBetweenSections; // en grados
  final double centerHolePercentage;
  final Duration duration;

  const AnimatedPieChart({
    Key? key,
    required this.percentages,
    required this.colors,
    this.donutThickness = 24.0,
    this.spaceBetweenSections = 4.0,
    this.centerHolePercentage = 0.8,
    this.duration = const Duration(milliseconds: 800),
  }) : super(key: key);

  @override
  _AnimatedPieChartState createState() => _AnimatedPieChartState();
}

class _AnimatedPieChartState extends State<AnimatedPieChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedPieChart old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.percentages, widget.percentages)) {
      _ctrl.reset();
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => CustomPaint(
          painter: _AnimatedCirclePieChartPainter(
            percentages: widget.percentages,
            colors: widget.colors,
            donutThickness: widget.donutThickness,
            spaceBetweenSections: widget.spaceBetweenSections,
            centerHolePercentage: widget.centerHolePercentage,
            progress: _anim.value,
          ),
        ),
      ),
    );
  }
}

class _AnimatedCirclePieChartPainter extends CustomPainter {
  final List<double> percentages;
  final List<Color> colors;
  final double donutThickness;
  final double spaceBetweenSections; // en grados
  final double centerHolePercentage;
  final double progress; // 0.0 → 1.0

  _AnimatedCirclePieChartPainter({
    required this.percentages,
    required this.colors,
    this.donutThickness = 25.0,
    this.spaceBetweenSections = 4.0,
    this.centerHolePercentage = 0.6,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRad =
        size.width < size.height ? size.width * 0.45 : size.height * 0.45;
    final innerRad = outerRad * centerHolePercentage;

    // Fondo blanco
    canvas.drawCircle(center, outerRad, Paint()..color = Colors.white);

    // Filtramos índices de porciones > 0
    final valid = <int>[];
    for (int i = 0; i < percentages.length; i++) {
      if (percentages[i] > 0) valid.add(i);
    }

    // Si no hay valores válidos, no dibujamos nada
    if (valid.isEmpty) return;

    final total = valid.fold<double>(
      0.0,
      (sum, i) => sum + percentages[i],
    );

    // Convertimos el espacio entre secciones a radianes
    final spaceInRadians = spaceBetweenSections * math.pi / 180;

    // Calculamos el ángulo total disponible después de restar todos los espacios
    final totalSpaces = valid.length > 1 ? spaceInRadians * valid.length : 0;
    final availableAngle = 2 * math.pi - totalSpaces;

    double startAngle = -math.pi / 2; // Comenzamos desde arriba (90 grados)

    for (int vi = 0; vi < valid.length; vi++) {
      final i = valid[vi];

      // Calculamos el ángulo de barrido proporcional al valor
      final sweepWithoutSpace =
          availableAngle * (percentages[i] / total) * progress;

      // Dibujamos el arco con el color correspondiente
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = donutThickness
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRad + donutThickness / 2),
        startAngle,
        sweepWithoutSpace,
        false,
        paint,
      );

      // Avanzamos el ángulo de inicio para la siguiente sección,
      // incluyendo el espacio entre secciones
      startAngle += sweepWithoutSpace + spaceInRadians;
    }

    // Dibujamos el hueco central
    canvas.drawCircle(center, innerRad, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _AnimatedCirclePieChartPainter old) {
    return old.progress != progress ||
        !listEquals(old.percentages, percentages) ||
        !listEquals(old.colors, colors) ||
        old.donutThickness != donutThickness ||
        old.spaceBetweenSections != spaceBetweenSections ||
        old.centerHolePercentage != centerHolePercentage;
  }
}
