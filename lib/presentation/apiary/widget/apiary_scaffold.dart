import 'package:auto_route/auto_route.dart';
import 'package:beebase/presentation/apiary/widget/android_apiary_scaffold.dart';
import 'package:beebase/presentation/apiary/widget/apiary_scaffold_action.dart';
import 'package:beebase/presentation/apiary/widget/ios_apiary_scaffold.dart';
import 'package:flutter/material.dart';

/// Platform-forked page shell shared by every Apiary screen: Liquid Glass
/// chrome on iOS ([IosApiaryScaffold]), Material 3 on Android
/// ([AndroidApiaryScaffold]). Body content is passed through untouched so
/// layout and business logic never fork — only the surrounding chrome does.
final class ApiaryScaffold extends StatelessWidget {
  const ApiaryScaffold({required this.title, required this.body, this.showBackButton = true, this.trailingAction, super.key});

  final String title;
  final Widget body;
  final bool showBackButton;
  final ApiaryScaffoldAction? trailingAction;

  @override
  Widget build(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS => IosApiaryScaffold(
        title: title,
        body: body,
        showBackButton: showBackButton,
        trailingAction: trailingAction,
        onBack: () => context.router.maybePop(),
      ),
      _ => AndroidApiaryScaffold(title: title, body: body, showBackButton: showBackButton, trailingAction: trailingAction),
    };
  }
}
