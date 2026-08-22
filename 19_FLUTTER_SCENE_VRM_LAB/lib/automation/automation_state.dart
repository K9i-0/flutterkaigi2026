import '../main.dart';

class VrmLabAutomationState {
  static VrmLabController? controller;

  static void attach(VrmLabController value) {
    controller = value;
  }

  static void detach(VrmLabController value) {
    if (identical(controller, value)) controller = null;
  }
}
