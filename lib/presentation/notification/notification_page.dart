import 'package:auto_route/auto_route.dart';
import 'package:beebase/utils/extensions/theme_colors.dart';
import 'package:beebase/utils/extensions/theme_spacing.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

@RoutePage()
final class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: Text('notification.page.title'.tr())),
      body: SafeArea(
        child: ListView.separated(
          padding: EdgeInsets.all(context.spacing.md),
          itemCount: 12,
          separatorBuilder: (_, _) => SizedBox(height: context.spacing.sm),
          itemBuilder: (context, index) {
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  Icons.notifications_outlined,
                  color: context.colors.primary,
                ),
                title: Text(
                  'notification.page.item'.tr(
                    namedArgs: {'index': '${index + 1}'},
                  ),
                ),
                textColor: context.colors.textPrimary,
              ),
            );
          },
        ),
      ),
    );
  }
}
