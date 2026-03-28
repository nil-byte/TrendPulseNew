import 'package:flutter/material.dart';

class SubscriptionTasksPage extends StatelessWidget {
  final String subId;

  const SubscriptionTasksPage({super.key, required this.subId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tasks — $subId')),
      body: Center(
        child: Text(
          'SubscriptionTasks — subId: $subId',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
