import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:herbal_i/screens/user/components/plant_result_modal.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> with WidgetsBindingObserver {
  List<Map<String, dynamic>> bookmarkedPlants = [];
  bool loading = true;
  bool hasError = false;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchBookmarkedPlants();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasInitialized) {
      // Only refresh when app comes back to foreground and we've already loaded once
      fetchBookmarkedPlants();
    }
  }

  Future<void> fetchBookmarkedPlants() async {
    if (loading && _hasInitialized) return; // Prevent multiple simultaneous loads
    
    setState(() {
      loading = true;
      hasError = false;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          loading = false;
          bookmarkedPlants = [];
          _hasInitialized = true;
        });
        return;
      }

      // Get user's bookmarks with confidence values
      final bookmarksRef = FirebaseDatabase.instance.ref('users/${user.uid}/bookmarks');
      final bookmarksSnapshot = await bookmarksRef.get();
      
      if (!bookmarksSnapshot.exists) {
        setState(() {
          loading = false;
          bookmarkedPlants = [];
          _hasInitialized = true;
        });
        return;
      }

      final bookmarksData = bookmarksSnapshot.value;
      List<Map<String, dynamic>> plants = [];
      
      if (bookmarksData is List) {
        // Old format: just class IDs
        for (int classId in bookmarksData) {
          try {
            final plantRef = FirebaseDatabase.instance.ref('plants/$classId');
            final plantSnapshot = await plantRef.get();
            if (plantSnapshot.exists) {
              final plantData = Map<String, dynamic>.from(plantSnapshot.value as Map);
              plantData['classId'] = classId;
              plantData['confidence'] = 1.0; // Default for old bookmarks
              plants.add(plantData);
            }
          } catch (e) {
            continue;
          }
        }
      } else if (bookmarksData is Map) {
        // New format: classId -> confidence mapping
        for (var entry in bookmarksData.entries) {
          try {
            final classId = int.parse(entry.key);
            final confidence = entry.value is double ? entry.value : 1.0;
            
            final plantRef = FirebaseDatabase.instance.ref('plants/$classId');
            final plantSnapshot = await plantRef.get();
            if (plantSnapshot.exists) {
              final plantData = Map<String, dynamic>.from(plantSnapshot.value as Map);
              plantData['classId'] = classId;
              plantData['confidence'] = confidence;
              plants.add(plantData);
            }
          } catch (e) {
            continue;
          }
        }
      }

      setState(() {
        bookmarkedPlants = plants;
        loading = false;
        _hasInitialized = true;
      });
    } catch (e) {
      setState(() {
        loading = false;
        hasError = true;
        _hasInitialized = true;
      });
    }
  }

  Future<void> removeBookmark(int classId) async {
    // Show confirmation dialog first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Bookmark'),
        content: const Text('Are you sure you want to remove this bookmark?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final bookmarksRef = FirebaseDatabase.instance.ref('users/${user.uid}/bookmarks');
      final bookmarksSnapshot = await bookmarksRef.get();
      
      if (bookmarksSnapshot.exists) {
        final bookmarksData = bookmarksSnapshot.value;
        if (bookmarksData is List) {
          // Old format: remove from list
          List<dynamic> bookmarks = List<dynamic>.from(bookmarksData);
          bookmarks.remove(classId);
          await bookmarksRef.set(bookmarks);
        } else if (bookmarksData is Map) {
          // New format: remove from map
          Map<String, dynamic> bookmarks = Map<String, dynamic>.from(bookmarksData);
          bookmarks.remove(classId.toString());
          await bookmarksRef.set(bookmarks);
        }
        
        // Refresh the list
        await fetchBookmarkedPlants();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove bookmark')),
      );
    }
  }

  void showPlantDetails(Map<String, dynamic> plantData) {
    showDialog(
      context: context,
      builder: (context) => PlantResultModal(
        classId: plantData['classId'],
        confidence: plantData['confidence'] ?? 1.0, // Use actual confidence
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Failed to load bookmarks'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: fetchBookmarkedPlants,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : bookmarkedPlants.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No bookmarks yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bookmark plants from detection results to see them here',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchBookmarkedPlants,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: bookmarkedPlants.length,
                        itemBuilder: (context, index) {
                          final plant = bookmarkedPlants[index];
                          final imagePath = 'assets/plant_img/${plant['classId']}.jpg';
                          final confidence = plant['confidence'] ?? 1.0;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () => showPlantDetails(plant),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Plant Image
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        imagePath,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[300],
                                          child: Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Plant Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            plant['name'] ?? 'Unknown Plant',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            plant['scientificName'] ?? '',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: confidence >= 0.8 ? Colors.green : Colors.orange,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            plant['uses'] is List
                                                ? (plant['uses'] as List).take(2).join(', ')
                                                : (plant['uses']?.toString() ?? ''),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Remove Bookmark Button
                                    IconButton(
                                      onPressed: () => removeBookmark(plant['classId']),
                                      icon: const Icon(
                                        Icons.bookmark_remove,
                                        color: Colors.red,
                                      ),
                                      tooltip: 'Remove bookmark',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
