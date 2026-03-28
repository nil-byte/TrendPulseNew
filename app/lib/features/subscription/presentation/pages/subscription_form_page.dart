import 'package:flutter/material.dart';

class SubscriptionFormPage extends StatelessWidget {
  final String? subId;

  const SubscriptionFormPage({super.key, this.subId});

  @override
  Widget build(BuildContext context) {
    final mode = subId == null ? 'New' : 'Edit ($subId)';
    return Scaffold(
      appBar: AppBar(title: Text('Subscription — $mode')),
      body: Center(
        child: Text(
          'SubscriptionForm — $mode',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
