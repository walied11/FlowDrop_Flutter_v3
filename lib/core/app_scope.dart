import 'package:flutter/widgets.dart';
import '../services/settings_store.dart';

/// يوفّر إعدادات التطبيق لكل الشاشات ويعيد البناء عند تغييرها.
class AppScope extends InheritedNotifier<AppSettings> {
  const AppScope({
    super.key,
    required AppSettings settings,
    required Widget child,
  }) : super(notifier: settings, child: child);

  static AppSettings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }
}
