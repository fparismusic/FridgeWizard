import 'package:flutter/foundation.dart';

class AppEvents {
  // "notificatore" globale. Ogni volta che cambia valore, avvisa chi ascolta.
  static final ValueNotifier<int> onDataChanged = ValueNotifier<int>(0);

  static void notifyDataChanged() {
    onDataChanged.value++;
  }
}