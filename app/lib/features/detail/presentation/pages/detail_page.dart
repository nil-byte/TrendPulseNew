import 'package:flutter/material.dart';

class DetailPage extends StatelessWidget {
  final String taskId;

  const DetailPage({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail')),
      body: Center(
        child: Text(
          'Detail — taskId: $taskId',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
