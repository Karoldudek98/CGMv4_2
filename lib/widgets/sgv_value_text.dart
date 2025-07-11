// lib/widgets/sgv_value_text.dart
import 'package:flutter/material.dart';

class SgvValueText extends StatelessWidget {
  final String sgv;

  const SgvValueText({
    super.key,
    required this.sgv,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '$sgv mg/dL',
      style: const TextStyle(
        fontSize: 60,
        fontWeight: FontWeight.bold,
        color: Colors.green,
      ),
    );
  }
}