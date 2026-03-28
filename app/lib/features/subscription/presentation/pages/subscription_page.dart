import 'package:flutter/material.dart';

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: Center(
        child: Text(
          'Subscription',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
