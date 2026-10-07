import 'package:flutter/widgets.dart';

class AppNavigation extends InheritedWidget {
  final ValueChanged<int> onSelectTab;
  final VoidCallback onOpenPriceComparison;

  const AppNavigation({
    super.key,
    required this.onSelectTab,
    required this.onOpenPriceComparison,
    required super.child,
  });

  static AppNavigation of(BuildContext context) {
    final navigation = context.dependOnInheritedWidgetOfExactType<AppNavigation>();
    assert(navigation != null, 'AppNavigation is missing from the widget tree.');
    return navigation!;
  }

  @override
  bool updateShouldNotify(AppNavigation oldWidget) =>
      onSelectTab != oldWidget.onSelectTab ||
      onOpenPriceComparison != oldWidget.onOpenPriceComparison;
}
