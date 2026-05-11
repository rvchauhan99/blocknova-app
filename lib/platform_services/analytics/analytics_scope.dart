import 'package:flutter/widgets.dart';

import 'analytics_service.dart';

class AnalyticsScope extends InheritedWidget {
  const AnalyticsScope({
    super.key,
    required this.analytics,
    required super.child,
  });

  final AnalyticsService analytics;

  static AnalyticsService? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AnalyticsScope>()?.analytics;
  }

  @override
  bool updateShouldNotify(AnalyticsScope oldWidget) =>
      analytics != oldWidget.analytics;
}
