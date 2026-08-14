import 'package:flutter/material.dart';
import 'package:obd2app/core/theme/app_tokens.dart';

enum AppErrorIcon { startup, notFound }

class RecoverableErrorView extends StatelessWidget {
  const RecoverableErrorView({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final AppErrorIcon icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Semantics(
          liveRegion: true,
          child: RecoverableErrorPanel(
            icon: icon,
            title: title,
            message: message,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
        ),
      ),
    );
  }
}

class RecoverableErrorPanel extends StatelessWidget {
  const RecoverableErrorPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel and onAction must either both be set or both be null.',
       );

  final AppErrorIcon icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  IconData get _iconData => switch (icon) {
    AppErrorIcon.startup => Icons.power_settings_new,
    AppErrorIcon.notFound => Icons.explore_off_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconData, size: 48),
              const SizedBox(height: AppSpacing.medium),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              Text(message, textAlign: TextAlign.center),
              if (onAction case final action?) ...[
                const SizedBox(height: AppSpacing.large),
                FilledButton(onPressed: action, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
