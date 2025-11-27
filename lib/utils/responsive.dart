import 'package:flutter/material.dart';

enum ScreenSize { small, medium, large }

class R {
  static ScreenSize size(BoxConstraints c) {
    final w = c.maxWidth;
    if (w < 360) return ScreenSize.small;
    if (w < 600) return ScreenSize.medium;
    return ScreenSize.large;
  }

  static double dp(
    BoxConstraints c, {
    double s = 8,
    double m = 12,
    double l = 16,
  }) {
    switch (size(c)) {
      case ScreenSize.small:
        return s;
      case ScreenSize.medium:
        return m;
      case ScreenSize.large:
        return l;
    }
  }

  static double font(
    BoxConstraints c, {
    double s = 12,
    double m = 14,
    double l = 16,
  }) {
    switch (size(c)) {
      case ScreenSize.small:
        return s;
      case ScreenSize.medium:
        return m;
      case ScreenSize.large:
        return l;
    }
  }
}
