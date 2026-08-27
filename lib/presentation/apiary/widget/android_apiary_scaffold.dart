import 'package:beebase/presentation/apiary/widget/apiary_scaffold_action.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:flutter/material.dart';

/// Apiary page shell for Android: a standard Material 3 [Scaffold]/[AppBar],
/// matching the platform's own back-navigation affordance rather than
/// borrowing the iOS glass treatment.
final class AndroidApiaryScaffold extends StatelessWidget {
  const AndroidApiaryScaffold({
    required this.title,
    required this.body,
    this.showBackButton = true,
    this.trailingAction,
    super.key,
  });

  final String title;
  final Widget body;
  final bool showBackButton;
  final ApiaryScaffoldAction? trailingAction;

  @override
  Widget build(BuildContext context) {
    final action = trailingAction;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: showBackButton,
        actions: action == null
            ? null
            : [IconButton(icon: Icon(action.materialIcon), tooltip: action.label, onPressed: action.onPressed)],
      ),
      body: SafeArea(child: body),
    );
  }
}
