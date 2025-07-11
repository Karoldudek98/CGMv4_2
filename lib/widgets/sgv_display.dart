// lib/widgets/sgv_display.dart
import 'package:flutter/material.dart';
import 'package:cgmv4/widgets/current_sgv_value.dart'; // <-- Ta linia!

class SgvDisplay extends StatelessWidget {
  final String sgv;
  final String direction;
  final String delta;
  final bool isLoading;

  const SgvDisplay({
    super.key,
    required this.sgv,
    required this.direction,
    required this.delta,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Text(
          'Aktualna Glikemia:',
          style: TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 10),
        // Używamy nowego widgetu CurrentSgvValue
        CurrentSgvValue(
          sgv: sgv,
          direction: direction,
          delta: delta,
        ),
        const SizedBox(height: 20),
        if (isLoading) const CircularProgressIndicator(),
      ],
    );
  }
}