import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gymmate_mobile/services/invite_service.dart';
import 'package:gymmate_mobile/models/invite_code_model.dart';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import 'package:gymmate_mobile/utils/role_utils.dart';

class InviteCodeListPage extends StatefulWidget {
  const InviteCodeListPage({super.key});

  @override
  _InviteCodeListPageState createState() => _InviteCodeListPageState();
}

class _InviteCodeListPageState extends State<InviteCodeListPage> {
  late Future<List<InviteCode>> _inviteCodesFuture;
  final InviteService _inviteService = InviteService();
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    // Initialize with an empty list future
    _inviteCodesFuture = Future.value([]);
    // Then refresh the list after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshList();
    });
  }

  void _refreshList() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuth) {
      setState(() {
        _inviteCodesFuture = _inviteService.fetchInviteCodes(
          authProvider.token!,
        );
      });
    } else {
      // Handle not being authenticated
      setState(() {
        _inviteCodesFuture = Future.error('Not authenticated');
      });
    }
  }

  Future<void> _generateCode() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuth) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Authentication error.')));
      return;
    }

    final currentRole = normalizeRole(authProvider.userRole);
    final isAdmin = isAdminRole(currentRole);
    final isGymOwner = isOwnerRole(currentRole);

    String? roleToGenerate;
    String? name;
    String? email;
    String? phoneNumber;

    if (isGymOwner) {
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => _GenerateInviteDialog(),
      );

      if (result == null) return; // User cancelled

      roleToGenerate = result['role'];
      name = result['name'];
      email = result['email'];
      phoneNumber = result['phone_number'];
    } else if (isAdmin) {
      roleToGenerate = 'gym_owner';
      // For superadmin, we might need a different dialog or flow
      // to collect gym owner details, but for now, we'll focus on gym_owner flow.
    }

    if (roleToGenerate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not allowed to generate invite codes.'),
        ),
      );
      return;
    }

    try {
      final newCode = await _inviteService.generateInviteCode(
        role: roleToGenerate,
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        token: authProvider.token!,
      );
      developer.log(
        'Generated code: ${newCode.code}',
        name: 'InviteCodeListPage',
      );
      _refreshList();
      _showGeneratedCodeDialog(newCode.code, roleToGenerate);
    } catch (e) {
      developer.log(
        'Failed to generate invite code: $e',
        name: 'InviteCodeListPage',
        error: e,
      );
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains(
          "User with this phone number already exists",
        )) {
          errorMessage = "A user with this phone number already exists.";
        } else {
          errorMessage = "Failed to generate code: ${e.toString()}";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showGeneratedCodeDialog(String code, String role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Code Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share this code with a new ${role == 'gym_owner' ? 'gym owner' : 'gym member'}:',
            ),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied to clipboard!')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<InviteCode>>(
        future: _inviteCodesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 50,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshList,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            final isGymOwner = isOwnerRole(authProvider.userRole);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.no_meeting_room,
                    size: 60,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isGymOwner
                        ? 'No Member Invite Codes Found'
                        : 'No Invite Codes Found',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isGymOwner
                        ? 'Generate a new code to invite gym members.'
                        : 'Generate a new code to get started.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          } else {
            final codes = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async => _refreshList(),
              child: ListView.builder(
                itemCount: codes.length,
                itemBuilder: (context, index) {
                  final code = codes[index];
                  return ListTile(
                    leading: Icon(
                      code.used ? Icons.check_circle : Icons.hourglass_empty,
                      color: code.used ? Colors.green : Colors.orange,
                    ),
                    title: Text(
                      code.code,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Role: ${code.role} | Used: ${code.used ? 'Yes' : 'No'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(code.createdAt.toLocal().toString().split(' ')[0]),
                        if (!code.used) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code.code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Code copied to clipboard!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            tooltip: 'Copy invite code',
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _generateCode,
        tooltip: 'Generate Invite Code',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GenerateInviteDialog extends StatefulWidget {
  @override
  __GenerateInviteDialogState createState() => __GenerateInviteDialogState();
}

class __GenerateInviteDialogState extends State<_GenerateInviteDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedRole;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate Invite'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedRole,
                hint: const Text('Select Role'),
                items: [
                  const DropdownMenuItem(
                    value: 'gym_member',
                    child: Text('Gym Member'),
                  ),
                  const DropdownMenuItem(
                    value: 'gym_trainer',
                    child: Text('Gym Trainer'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value;
                  });
                },
                validator: (value) => value == null ? 'Role is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(r"^\S+@\S+\.\S+$").hasMatch(value)) {
                    return 'Invalid email format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Phone number is required';
                  }
                  if (!RegExp(r'^(?:\+91)?[6-9]\d{9}$').hasMatch(value)) {
                    return 'Invalid Indian phone number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'role': _selectedRole!,
                'name': _nameController.text,
                'email': _emailController.text,
                'phone_number': _phoneController.text,
              });
            }
          },
          child: const Text('Generate'),
        ),
      ],
    );
  }
}
