// lib/widgets/refresh_button.dart
import 'package:flutter/material.dart';

class RefreshButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const RefreshButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.refresh),
      onPressed: isLoading ? null : onPressed,
    );
  }
}