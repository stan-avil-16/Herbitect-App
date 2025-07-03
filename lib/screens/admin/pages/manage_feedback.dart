import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageFeedbackPage extends StatefulWidget {
  const ManageFeedbackPage({super.key});

  @override
  State<ManageFeedbackPage> createState() => _ManageFeedbackPageState();
}

class _ManageFeedbackPageState extends State<ManageFeedbackPage> {
  List<Map<String, dynamic>> _feedbackList = [];
  List<Map<String, dynamic>> _filteredFeedback = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'all'; // all, seen, unseen
  Map<String, Map<String, dynamic>> _userDetails = {};
  Map<String, Map<String, dynamic>> _plantDetails = {};

  @override
  void initState() {
    super.initState();
    _fetchFeedback();
  }

  Future<void> _fetchFeedback() async {
    setState(() { _loading = true; _error = null; });
    try {
      final ref = FirebaseDatabase.instance.ref('feedback');
      final snapshot = await ref.get();
      
      if (!snapshot.exists) {
        setState(() { _feedbackList = []; _filteredFeedback = []; _loading = false; });
        return;
      }

      final feedback = <Map<String, dynamic>>[];
      final data = snapshot.value;
      
      if (data is Map) {
        data.forEach((key, value) {
          final feedbackItem = Map<String, dynamic>.from(value as Map);
          feedbackItem['id'] = key.toString();
          feedbackItem['status'] = feedbackItem['status'] ?? 'unseen';
          feedback.add(feedbackItem);
        });
      }

      // Sort by timestamp (newest first)
      feedback.sort((a, b) {
        final aTime = DateTime.parse(a['timestamp'] ?? '');
        final bTime = DateTime.parse(b['timestamp'] ?? '');
        return bTime.compareTo(aTime);
      });

      setState(() { 
        _feedbackList = feedback; 
        _filteredFeedback = feedback;
        _loading = false; 
      });

      // Fetch user and plant details
      await _fetchUserAndPlantDetails();
    } catch (e) {
      setState(() { _error = 'Failed to load feedback: $e'; _loading = false; });
    }
  }

  Future<void> _fetchUserAndPlantDetails() async {
    try {
      // Fetch user details
      for (final feedback in _feedbackList) {
        final userId = feedback['userId']?.toString();
        if (userId != null && userId.isNotEmpty) {
          final userRef = FirebaseDatabase.instance.ref('users/$userId');
          final userSnapshot = await userRef.get();
          if (userSnapshot.exists) {
            _userDetails[userId] = Map<String, dynamic>.from(userSnapshot.value as Map);
          }
        }

        // Fetch plant details
        final classId = feedback['classId']?.toString();
        if (classId != null) {
          final plantRef = FirebaseDatabase.instance.ref('plants/$classId');
          final plantSnapshot = await plantRef.get();
          if (plantSnapshot.exists) {
            _plantDetails[classId] = Map<String, dynamic>.from(plantSnapshot.value as Map);
          }
        }
      }
      setState(() {});
    } catch (e) {
      print('Error fetching details: $e');
    }
  }

  void _filterFeedback() {
    setState(() {
      if (_statusFilter == 'all') {
        _filteredFeedback = _feedbackList;
      } else {
        _filteredFeedback = _feedbackList.where((f) => f['status'] == _statusFilter).toList();
      }
    });
  }

  Future<void> _toggleStatus(String feedbackId, String currentStatus) async {
    try {
      final newStatus = currentStatus == 'seen' ? 'unseen' : 'seen';
      await FirebaseDatabase.instance.ref('feedback/$feedbackId/status').set(newStatus);
      
      setState(() {
        final index = _feedbackList.indexWhere((f) => f['id'] == feedbackId);
        if (index != -1) {
          _feedbackList[index]['status'] = newStatus;
        }
      });
      _filterFeedback();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Feedback marked as ${newStatus == 'seen' ? 'seen' : 'unseen'}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchFeedback,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with stats
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade50, Colors.green.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.feedback_outlined, color: Colors.green.shade700, size: 32),
                  const SizedBox(width: 12),
                  const Text(
                    'Feedback Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Georgia',
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard('Total', _feedbackList.length.toString(), Icons.feedback),
                  _buildStatCard('Unseen', _feedbackList.where((f) => f['status'] == 'unseen').length.toString(), Icons.mark_email_unread),
                  _buildStatCard('Seen', _feedbackList.where((f) => f['status'] == 'seen').length.toString(), Icons.mark_email_read),
                ],
              ),
            ],
          ),
        ),
        
        // Filter buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('Filter by status: ', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('All'),
                selected: _statusFilter == 'all',
                onSelected: (selected) {
                  setState(() { _statusFilter = 'all'; });
                  _filterFeedback();
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Unseen'),
                selected: _statusFilter == 'unseen',
                onSelected: (selected) {
                  setState(() { _statusFilter = 'unseen'; });
                  _filterFeedback();
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Seen'),
                selected: _statusFilter == 'seen',
                onSelected: (selected) {
                  setState(() { _statusFilter = 'seen'; });
                  _filterFeedback();
                },
              ),
            ],
          ),
        ),

        // Feedback list
        Expanded(
          child: _filteredFeedback.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.feedback_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No feedback found', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredFeedback.length,
                  itemBuilder: (context, index) {
                    final feedback = _filteredFeedback[index];
                    return _buildFeedbackCard(feedback);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.green.shade700, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {
    final userId = feedback['userId']?.toString();
    final classId = feedback['classId']?.toString();
    final userInfo = _userDetails[userId];
    final plantInfo = _plantDetails[classId];
    final status = feedback['status'] ?? 'unseen';
    final timestamp = DateTime.parse(feedback['timestamp'] ?? '');
    final resultRating = feedback['resultRating'] ?? 0;
    final uiRating = feedback['uiRating'] ?? 0;
    final comment = feedback['comment'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: status == 'unseen' ? Colors.orange.shade100 : Colors.green.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            status == 'unseen' ? Icons.mark_email_unread : Icons.mark_email_read,
            color: status == 'unseen' ? Colors.orange.shade700 : Colors.green.shade700,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userInfo?['name'] ?? userInfo?['email'] ?? 'Anonymous User',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    plantInfo?['name'] ?? 'Plant ID: $classId',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: List.generate(5, (i) => Icon(
                    i < resultRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  )),
                ),
                Text(
                  '${timestamp.day}/${timestamp.month}/${timestamp.year}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        subtitle: Text(
          comment.isNotEmpty ? comment : 'No comment provided',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(
            status == 'unseen' ? Icons.mark_email_read : Icons.mark_email_unread,
            color: status == 'unseen' ? Colors.orange.shade700 : Colors.green.shade700,
          ),
          onPressed: () => _toggleStatus(feedback['id'], status),
          tooltip: 'Mark as ${status == 'unseen' ? 'seen' : 'unseen'}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                
                // User details
                if (userInfo != null) ...[
                  const Text('User Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Name: ${userInfo['name'] ?? 'N/A'}'),
                  Text('Email: ${userInfo['email'] ?? 'N/A'}'),
                  const SizedBox(height: 8),
                ] else ...[
                  const Text('User Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text('Anonymous User'),
                  const SizedBox(height: 8),
                ],

                // Plant details
                if (plantInfo != null) ...[
                  const Text('Plant Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Name: ${plantInfo['name'] ?? 'N/A'}'),
                  Text('Scientific Name: ${plantInfo['scientificName'] ?? 'N/A'}'),
                  const SizedBox(height: 8),
                ] else ...[
                  const Text('Plant Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Plant ID: $classId'),
                  const SizedBox(height: 8),
                ],

                // Ratings
                const Text('Ratings:', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Text('Result Accuracy: '),
                    ...List.generate(5, (i) => Icon(
                      i < resultRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 20,
                    )),
                    Text(' ($resultRating/5)'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('UI Experience: '),
                    ...List.generate(5, (i) => Icon(
                      i < uiRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 20,
                    )),
                    Text(' ($uiRating/5)'),
                  ],
                ),
                const SizedBox(height: 8),

                // Comment
                if (comment.isNotEmpty) ...[
                  const Text('Comment:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(comment),
                  const SizedBox(height: 8),
                ],

                // Timestamp
                Text(
                  'Submitted: ${timestamp.toString().substring(0, 19)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 