import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import 'package:gymmate_mobile/pages/login_page.dart';
import 'package:gymmate_mobile/main.dart';
import 'package:gymmate_mobile/services/auth_service.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          children: [
            _buildProfileHeader(context, authProvider.userName),
            const SizedBox(height: 30),
            _buildProfileCard(context, authProvider),
            const SizedBox(height: 30),
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, String? userName) {
    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.person, size: 30, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userName ?? 'User',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'View your profile details below',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileCard(BuildContext context, AuthProvider authProvider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildInfoRow(context, Icons.email_outlined, 'Email', authProvider.userEmail ?? 'N/A'),
            const Divider(height: 20),
            _buildInfoRow(context, Icons.shield_outlined, 'Role', authProvider.userRole ?? 'N/A'),
            if (authProvider.userRole != 'superadmin' && authProvider.gymName != null) ...[
              const Divider(height: 20),
              _buildInfoRow(context, Icons.business_outlined, 'Gym', authProvider.gymName!),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 16),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.logout),
      label: const Text('Logout'),
      onPressed: () async {
        print('[LOGOUT] Logout button clicked. Showing confirmation dialog.');
        final confirmed = await showLogoutConfirmation(context);
        print('[LOGOUT] Confirmation dialog result: ${confirmed == true ? 'YES' : 'NO'}');
        if (confirmed) {
          await Provider.of<AuthProvider>(context, listen: false).logout();
          await AuthService.logout();
          print('[LOGOUT] Session cleared. Navigating to /login using navigatorKey.');
          try {
            navigatorKey.currentState!.pushNamedAndRemoveUntil(
              '/login',
              (Route<dynamic> route) => false,
            );
            print('[LOGOUT] Navigation to /login triggered.');
          } catch (e, st) {
            print('[LOGOUT][ERROR] Navigation to /login failed: $e\n$st');
          }
        } else {
          print('[LOGOUT] NO clicked. Staying on dashboard.');
        }
      },
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white, 
        backgroundColor: Colors.redAccent,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
} 