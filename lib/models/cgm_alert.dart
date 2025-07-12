// lib/models/cgm_alert.dart

import 'package:flutter/material.dart';

class CgmAlert {
  final String message;
  final DateTime timestamp;
  final String type;
  final Color alertColor;
  bool isRead;
  DateTime? dismissedUntil;

  CgmAlert({
    required this.message,
    required this.timestamp,
    required this.type,
    required this.alertColor,
    this.isRead = false,
    this.dismissedUntil,
  });

  factory CgmAlert.fromJson(Map<String, dynamic> json) {
    return CgmAlert(
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: json['type'] as String,
      alertColor: Color(json['alertColor'] as int),
      isRead: json['isRead'] as bool? ?? false,
      dismissedUntil: json['dismissedUntil'] != null
          ? DateTime.parse(json['dismissedUntil'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'alertColor': alertColor.value,
      'isRead': isRead,
      'dismissedUntil': dismissedUntil?.toIso8601String(),
    };
  }

  String get id => '${type}_${timestamp.toIso8601String()}';

  bool get isActive => dismissedUntil == null || dismissedUntil!.isBefore(DateTime.now());
}