import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';

class GymOwnerDashboardPage extends StatelessWidget {
  const GymOwnerDashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome, ${authProvider.userName ?? 'Gym Owner'}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Gym: ${authProvider.gymName ?? '-'}'),
              Text('Email: ${authProvider.userEmail ?? '-'}'),
              const SizedBox(height: 16),
              Text('This is your gym owner dashboard.'),
            ],
          ),
        ),
      ),
    );
  }
} 