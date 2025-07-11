// lib/widgets/direction_arrow.dart
import 'package:flutter/material.dart';

class DirectionArrow extends StatelessWidget {
  final String direction;
  final String delta; // Opcjonalnie, jeśli delta ma być zawsze ze strzałką

  const DirectionArrow({
    super.key,
    required this.direction,
    this.delta = '', // Domyślnie puste, jeśli nie ma delty
  });

  // Metoda pomocnicza do mapowania kierunków na strzałki
  String _getDirectionArrow(String direction) {
    switch (direction) {
      case 'DoubleUp': return '⇈';
      case 'SingleUp': return '↑';
      case 'FortyFiveUp': return '↗';
      case 'Flat': return '→';
      case 'FortyFiveDown': return '↘';
      case 'SingleDown': return '↓';
      case 'DoubleDown': return '⇊';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min, // Minimalizuje rozmiar Row do zawartości
      children: [
        Text(
          _getDirectionArrow(direction),
          style: const TextStyle(fontSize: 40),
        ),
        if (delta.isNotEmpty) ...[ // Wyświetla deltę tylko, jeśli nie jest pusta
          const SizedBox(width: 10),
          Text(
            '($delta)',
            style: const TextStyle(fontSize: 30),
          ),
        ],
      ],
    );
  }
}