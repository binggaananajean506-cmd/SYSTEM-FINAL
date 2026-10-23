import 'dart:convert';

import 'package:flutter/material.dart';

import 'semantic_colors.dart';

/// Style the street map itself; satellite imagery and marker artwork stay intact.
String? buildESugidMapStyle(Brightness brightness) {
  if (brightness == Brightness.light) return null;
  const colors = ESugidColors.dark;
  String hex(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2)}';
  Map<String, Object> rule(String element, Color color, [String? feature]) => {
    'featureType': ?feature,
    'elementType': element,
    'stylers': [
      {'color': hex(color)},
    ],
  };
  return jsonEncode([
    rule('geometry', colors.background),
    rule('labels.text.fill', colors.textSecondary),
    rule('labels.text.stroke', colors.background),
    rule('geometry', colors.surfaceAlt, 'road'),
    rule('labels.text.fill', colors.textPrimary, 'road'),
    rule('geometry', colors.successSurface, 'poi.park'),
    rule('geometry', colors.infoSurface, 'water'),
  ]);
}
