---
trigger: model_decision
description: Apply when creating, editing, or refactoring Flutter UI widgets, screens, dialogs, sheets, or typography and color theming across ventoPOS and ventoPOS_Keygen.
---

# UI Presentation, Contrast, SafeArea & Design System Rules

1. **Single-Widget-Per-File (`1 Widget = 1 .dart File`)**:
   - Every `StatelessWidget`, `StatefulWidget`, `ConsumerWidget`, or `ConsumerStatefulWidget` MUST reside in its own dedicated `.dart` file in `snake_case.dart`.
   - Private helper widget classes (`class _Foo extends StatelessWidget`) and widget-returning `_build*` methods (>20 lines) are forbidden; extract them into separate files.
   - Keep barrel `export` statements when splitting existing files so `test/unit/` imports never break.

2. **Centralized M3 Design System & DRY Components**:
   - Never use hardcoded `Color(0x...)`, `Colors.slate/grey`, raw `TextStyle(fontSize: ...)`, or manual `Container(decoration: BoxDecoration(...))` for cards/chips/buttons.
   - Always use `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, and `lib/presentation/design_system/` components.
   - Reuse centralized components (`VentoModuleTabBar`, `VentoCollapsibleFilterScaffold`, `VentoModalSheetScaffold`, `VentoStructuredAddressFields`) instead of duplicating layouts per screen.

3. **Edge-to-Edge `SafeArea`, Button Contrast & Touch Targets (`targetSdk = 36`)**:
   - **Mandatory `SafeArea`**: All full-screen `Scaffold` bottom bars (`bottomNavigationBar`) and all `showModalBottomSheet` dialogs (`useSafeArea: true` + inner `SafeArea(top: false, bottom: true)` + keyboard `MediaQuery.viewInsetsOf(context).bottom`) must protect against system navigation bars and keyboard overlap.
   - **Blue & Filled Button Contrast (`Colors.white`)**: All blue-toned (`AppColors.action`, `AppColors.actionDark`, `AppColors.primary`, `AppColors.primaryDark`) and dark filled buttons (`ElevatedButton`, `FilledButton`) MUST use `#FFFFFF` (`Colors.white`) for text and icons. Never pass raw `AppTypography.*` styles with `AppColors.textPrimary` inside filled buttons without overriding `color: Colors.white`.
   - **Minimum Touch Target (`44dp`)**: Avoid `VisualDensity.compact` vertical compression on action buttons; maintain at least `44dp` vertical touch target height.

4. **Strict Language Separation**:
   - **User Interface (UI) & Agent Reports**: Exclusively in **Turkish** (all screen titles, labels, form hints, validation messages, SnackBars, dialogs, thermal receipts, templates, and all agent reports/analyses to the user).
   - **Code & Developer Artifacts**: Exclusively in **English** (class names, method names, variables, filenames, constants, comments, and Git commit messages).
