import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:material_ui/material_ui.dart';

/// marionette_flutter 0.7.0 only knows the widget types of the deprecated
/// `package:flutter/material.dart`. The `material_ui` classes are distinct
/// types, so without this its element listing no longer treats buttons,
/// switches and text fields as single elements. Mirrors Marionette's built-in
/// rules; drop it once marionette_flutter supports `material_ui`.
const marionetteMaterialUiConfiguration = MarionetteConfiguration(
  isInteractiveElement: _isInteractive,
  shouldStopTraversalAtElement: _stopsTraversal,
  extractText: _text,
);

/// Interactive widgets whose descendants carry their label or value.
bool _isPassThrough(Widget widget) => switch (widget) {
  InkWell() ||
  DropdownButton() ||
  DropdownButtonFormField() ||
  PopupMenuButton() ||
  RadioListTile() => true,
  _ => false,
};

bool _isInteractive(Element element) => switch (element.widget) {
  Checkbox() ||
  CheckboxListTile() ||
  FloatingActionButton() ||
  IconButton() ||
  Radio() ||
  Slider() ||
  Switch() ||
  SwitchListTile() ||
  TextField() ||
  TextFormField() ||
  ButtonStyleButton() => true,
  final widget => _isPassThrough(widget),
};

bool _stopsTraversal(Element element) =>
    _isInteractive(element) && !_isPassThrough(element.widget);

String? _text(Element element) => switch (element.widget) {
  TextField(:final controller) => controller?.text,
  TextFormField(:final controller) => controller?.text,
  _ => null,
};
