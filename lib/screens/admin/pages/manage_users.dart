import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() { _loading = true; _error = null; });
    try {
      final ref = FirebaseDatabase.instance.ref('users');
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        setState(() { _users = []; _loading = false; _error = 'No users found.'; });
        return;
      }
      final data = snapshot.value as Map<dynamic, dynamic>;
      final users = <Map<String, dynamic>>[];
      data.forEach((key, value) {
        final user = Map<String, dynamic>.from(value as Map);
        user['id'] = key.toString();
        users.add(user);
      });
      users.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      setState(() { _users = users; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load users: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final user = _users[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['name'] ?? 'Unknown', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Email: ${user['email'] ?? 'N/A'}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Registered: ${user['timestamp'] ?? 'N/A'}', style: const TextStyle(fontSize: 15, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}
