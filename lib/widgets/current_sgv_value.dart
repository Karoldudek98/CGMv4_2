// lib/widgets/current_sgv_value.dart
import 'package:flutter/material.dart';
import 'package:cgmv4/widgets/sgv_value_text.dart'; // Importujemy nowy widget SgvValueText
import 'package:cgmv4/widgets/direction_arrow.dart'; // Importujemy nowy widget DirectionArrow

class CurrentSgvValue extends StatelessWidget {
  final String sgv;
  final String direction;
  final String delta;

  const CurrentSgvValue({
    super.key,
    required this.sgv,
    required this.direction,
    required this.delta,
  });

  // Metoda _getDirectionArrow została przeniesiona do DirectionArrow,
  // więc możemy ją usunąć z tej klasy.
  // String _getDirectionArrow(String direction) { ... }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Używamy nowego widgetu SgvValueText
        SgvValueText(sgv: sgv),
        const SizedBox(height: 10),
        // Używamy nowego widgetu DirectionArrow
        DirectionArrow(direction: direction, delta: delta),
      ],
    );
  }
}