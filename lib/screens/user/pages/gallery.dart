import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:herbal_i/screens/user/components/gallery_plant_modal.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  List<Map<String, dynamic>> allPlants = [];
  bool loading = true;
  bool hasError = false;
  String errorMessage = '';

  // Constants for plant database management
  static const int ML_CLASSES_COUNT = 41; // Classes 0-40 (including "Not a Leaf")
  static const int TOTAL_PLANTS_COUNT = 105; // Plants 0-104
  static const int NOT_A_LEAF_CLASS_ID = 40; // "Not a Leaf" class ID

  @override
  void initState() {
    super.initState();
    fetchAllPlants();
  }

  Future<void> fetchAllPlants() async {
    setState(() {
      loading = true;
      hasError = false;
      errorMessage = '';
    });

    try {
      print('Gallery: Starting to fetch plants from Firebase...');
      final plantsRef = FirebaseDatabase.instance.ref('plants');
      print('Gallery: Firebase reference created');
      
      final snapshot = await plantsRef.get();
      print('Gallery: Snapshot exists: ${snapshot.exists}');
      print('Gallery: Snapshot value type: ${snapshot.value.runtimeType}');
      
      if (!snapshot.exists) {
        print('Gallery: No plants found in Firebase database');
        // Try to load from local JSON as fallback
        await loadPlantsFromLocalJson();
        return;
      }

      if (snapshot.value == null) {
        print('Gallery: Snapshot value is null');
        setState(() {
          loading = false;
          hasError = true;
          errorMessage = 'No data received from database';
        });
        return;
      }

      final plantsData = snapshot.value as Map<dynamic, dynamic>;
      print('Gallery: Plants data type: ${plantsData.runtimeType}');
      print('Gallery: Number of plants: ${plantsData.length}');
      
      List<Map<String, dynamic>> plants = [];
      
      plantsData.forEach((key, value) {
        try {
          print('Gallery: Processing plant with key: $key');
          
          final classId = int.parse(key.toString());
          
          // Skip "Not a Leaf" class from gallery
          if (classId == NOT_A_LEAF_CLASS_ID) {
            print('Gallery: Skipping "Not a Leaf" class from gallery');
            return;
          }
          
          // Validate plant ID range
          if (classId < 0 || classId >= TOTAL_PLANTS_COUNT) {
            print('Gallery: Skipping invalid plant ID: $classId');
            return;
          }
          
          final plantData = Map<String, dynamic>.from(value as Map);
          plantData['classId'] = classId;
          plants.add(plantData);
          print('Gallery: Successfully added plant: ${plantData['name']}');
        } catch (e) {
          print('Gallery: Error processing plant $key: $e');
          // Skip invalid entries
        }
      });

      print('Gallery: Total plants processed: ${plants.length}');

      // Sort plants by name for better organization
      plants.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

      setState(() {
        allPlants = plants;
        loading = false;
      });
      
      print('Gallery: Successfully loaded ${plants.length} plants from Firebase (excluding "Not a Leaf")');
    } catch (e) {
      print('Gallery: Error fetching plants from Firebase: $e');
      print('Gallery: Error stack trace: ${e.toString()}');
      
      // Try to load from local JSON as fallback
      await loadPlantsFromLocalJson();
    }
  }

  Future<void> loadPlantsFromLocalJson() async {
    try {
      print('Gallery: Loading plants from local JSON file...');
      final jsonString = await rootBundle.loadString('assets/plants.json');
      final jsonData = json.decode(jsonString);
      final plantsData = jsonData['plants'] as Map<String, dynamic>;
      
      List<Map<String, dynamic>> plants = [];
      
      plantsData.forEach((key, value) {
        try {
          final classId = int.parse(key);
          
          // Skip "Not a Leaf" class from gallery
          if (classId == NOT_A_LEAF_CLASS_ID) {
            print('Gallery: Skipping "Not a Leaf" class from local gallery');
            return;
          }
          
          // Validate plant ID range
          if (classId < 0 || classId >= TOTAL_PLANTS_COUNT) {
            print('Gallery: Skipping invalid plant ID: $classId');
            return;
          }
          
          final plantData = Map<String, dynamic>.from(value as Map);
          plantData['classId'] = classId;
          plants.add(plantData);
        } catch (e) {
          print('Gallery: Error processing local plant $key: $e');
        }
      });

      plants.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

      setState(() {
        allPlants = plants;
        loading = false;
        hasError = false;
      });
      
      print('Gallery: Successfully loaded ${plants.length} plants from local JSON (excluding "Not a Leaf")');
    } catch (e) {
      print('Gallery: Error loading from local JSON: $e');
      setState(() {
        loading = false;
        hasError = true;
        errorMessage = 'Failed to load plants from both Firebase and local storage: $e';
      });
    }
  }

  void showPlantDetails(Map<String, dynamic> plantData) {
    showDialog(
      context: context,
      builder: (context) => GalleryPlantModal(
        classId: plantData['classId'],
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
                      const Text(
                        'Failed to load plants',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            errorMessage,
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: fetchAllPlants,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : allPlants.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No plants available',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Plant database is empty',
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
                      onRefresh: fetchAllPlants,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: allPlants.length,
                        itemBuilder: (context, index) {
                          final plant = allPlants[index];
                          final imagePath = 'assets/plant_img/${plant['classId']}.jpg';
                          
                          return Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () => showPlantDetails(plant),
                              borderRadius: BorderRadius.circular(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Plant Image
                                  Expanded(
                                    flex: 4,
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child: Image.asset(
                                        imagePath,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.grey[300],
                                          child: Icon(
                                            Icons.image_not_supported,
                                            size: 48,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // Plant Name
                                  Expanded(
                                    flex: 1,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: Center(
                                        child: Text(
                                          plant['name'] ?? 'Unknown Plant',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
