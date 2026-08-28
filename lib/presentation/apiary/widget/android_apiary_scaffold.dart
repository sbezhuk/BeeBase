import 'package:beebase/presentation/apiary/widget/apiary_scaffold_action.dart';
import 'package:beebase/presentation/component/honey_gradient_background.dart';
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
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        automaticallyImplyLeading: showBackButton,
        actions: action == null
            ? null
            : [IconButton(icon: Icon(action.materialIcon), tooltip: action.label, onPressed: action.onPressed)],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: HoneyGradientBackground()),
          SafeArea(child: body),
        ],
      ),
    );
  }
}
