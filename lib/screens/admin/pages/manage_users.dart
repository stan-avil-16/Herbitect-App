import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, int> _bookmarkCounts = {};
  Map<String, int> _scanCounts = {};
  Map<String, int> _searchCounts = {};
  Map<String, int> _pdfShareCounts = {};
  Set<String> _expandedUsers = {};

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _filteredUsers = _users.where((user) {
        final name = (user['name'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) || email.contains(_searchQuery);
      }).toList();
    });
  }

  Future<void> _fetchUsers() async {
    setState(() { _loading = true; _error = null; });
    try {
      final ref = FirebaseDatabase.instance.ref('users');
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        setState(() { _users = []; _filteredUsers = []; _loading = false; _error = 'No users found.'; });
        return;
      }
      final data = snapshot.value as Map<dynamic, dynamic>;
      final users = <Map<String, dynamic>>[];
      for (var entry in data.entries) {
        final user = Map<String, dynamic>.from(entry.value as Map);
        user['id'] = entry.key.toString();
        if ((user['role'] ?? 'user') == 'user') {
          users.add(user);
        }
      }
      users.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      setState(() { _users = users; _filteredUsers = users; _loading = false; });
      await _fetchUserCounts(users);
    } catch (e) {
      setState(() { _error = 'Failed to load users: $e'; _loading = false; });
    }
  }

  Future<void> _fetchUserCounts(List<Map<String, dynamic>> users) async {
    final db = FirebaseDatabase.instance;
    for (final user in users) {
      final uid = user['id'];
      // Bookmarks
      final bookmarksSnap = await db.ref('users/$uid/bookmarks').get();
      int bookmarkCount = 0;
      if (bookmarksSnap.exists) {
        final data = bookmarksSnap.value;
        if (data is List) {
          bookmarkCount = data.length;
        } else if (data is Map) {
          bookmarkCount = data.length;
        }
      }
      _bookmarkCounts[uid] = bookmarkCount;
      // Scans
      final scansSnap = await db.ref('scans/$uid').get();
      int scanCount = 0;
      int pdfShareCount = 0;
      if (scansSnap.exists) {
        scanCount = scansSnap.children.length;
        for (final scan in scansSnap.children) {
          final shareCount = scan.child('sharePdfCount').value;
          if (shareCount is int) {
            pdfShareCount += shareCount;
          } else if (shareCount is double) {
            pdfShareCount += shareCount.toInt();
          }
        }
      }
      _scanCounts[uid] = scanCount;
      _pdfShareCounts[uid] = pdfShareCount;
      // Searches
      final searchSnap = await db.ref('search/$uid').get();
      int searchCount = 0;
      if (searchSnap.exists) {
        searchCount = searchSnap.children.length;
      }
      _searchCounts[uid] = searchCount;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users by name or email...',
                prefixIcon: Icon(Icons.search, color: Colors.green.shade700),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _filteredUsers.isEmpty
              ? const Center(child: Text('No users found', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredUsers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    final uid = user['id'];
                    final expanded = _expandedUsers.contains(uid);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          setState(() {
                            if (expanded) {
                              _expandedUsers.remove(uid);
                            } else {
                              _expandedUsers.add(uid);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.green.shade100,
                                    child: Icon(Icons.person, size: 32, color: Colors.green.shade700),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(user['name'] ?? 'Unknown', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Georgia', color: Color(0xFF1B5E20))),
                                        const SizedBox(height: 6),
                                        Text('Email: ${user['email'] ?? 'N/A'}', style: const TextStyle(fontSize: 16)),
                                        const SizedBox(height: 6),
                                        Text('Registered: ${user['timestamp'] ?? 'N/A'}', style: const TextStyle(fontSize: 15, color: Colors.grey)),
                                        if (user['phone'] != null && user['phone'].toString().isNotEmpty)
                                          Text('Phone: ${user['phone']}', style: const TextStyle(fontSize: 15, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (expanded) ...[
                                const SizedBox(height: 16),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildCountTile(Icons.bookmark, 'Bookmarks', _bookmarkCounts[uid] ?? 0, Colors.green),
                                      _buildCountTile(Icons.camera_alt, 'Scans', _scanCounts[uid] ?? 0, Colors.teal),
                                      _buildCountTile(Icons.picture_as_pdf, 'PDF Shares', _pdfShareCounts[uid] ?? 0, Colors.redAccent),
                                      _buildCountTile(Icons.search, 'Searches', _searchCounts[uid] ?? 0, Colors.orange),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCountTile(IconData icon, String label, int count, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }
}
