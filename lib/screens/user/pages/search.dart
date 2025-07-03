import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:herbal_i/screens/user/components/plant_result_modal.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  SearchPageState createState() => SearchPageState();
}

class SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();

  List<String> allSymptoms = [];
  List<String> suggestedSymptoms = [];
  List<Map<String, dynamic>> allPlants = [];
  List<Map<String, dynamic>> filteredPlants = [];
  List<String> plantIds = [];
  bool isLoading = true;

  // Constants for plant database management
  static const int ML_CLASSES_COUNT = 41; // Classes 0-40 (including "Not a Leaf")
  static const int TOTAL_PLANTS_COUNT = 105; // Plants 0-104
  static const int NOT_A_LEAF_CLASS_ID = 40; // "Not a Leaf" class ID

  @override
  void initState() {
    super.initState();
    _loadPlantData();
  }

  @override
  void dispose() {
    _searchController.clear();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Clear the search bar when the page is re-entered
    _searchController.clear();
    setState(() {
      filteredPlants = List.from(allPlants);
    });
  }

  Future<void> _loadPlantData() async {
    try {
      // Try loading from Firebase
      final snapshot = await FirebaseFirestore.instance.collection('plants').get();
      if (snapshot.docs.isNotEmpty) {
        allPlants = snapshot.docs.map((doc) => doc.data()).toList();
        plantIds = snapshot.docs.map((doc) => doc.id).toList();
      } else {
        // Fallback to local JSON
        await _loadFromLocalJson();
      }
    } catch (e) {
      // Fallback to local JSON
      await _loadFromLocalJson();
    }
    _extractSymptoms();
    setState(() {
      isLoading = false;
      filteredPlants = List.from(allPlants);
    });
  }

  Future<void> _loadFromLocalJson() async {
    final String jsonString = await rootBundle.loadString('assets/plants.json');
    final Map<String, dynamic> jsonData = json.decode(jsonString);
    final Map<String, dynamic> plantsMap = jsonData['plants'] as Map<String, dynamic>;
    allPlants = [];
    plantIds = [];
    plantsMap.forEach((id, plant) {
      final plantId = int.tryParse(id) ?? -1;
      
      // Skip "Not a Leaf" class from search results
      if (plantId == NOT_A_LEAF_CLASS_ID) {
        print('⏭️ Skipping "Not a Leaf" class from search results');
        return;
      }
      
      // Validate plant ID range
      if (plantId < 0 || plantId >= TOTAL_PLANTS_COUNT) {
        print('⚠️ Skipping invalid plant ID: $plantId');
        return;
      }
      
      final plantMap = Map<String, dynamic>.from(plant);
      plantMap['id'] = id;
      allPlants.add(plantMap);
      plantIds.add(id);
    });
    
    print('📊 Loaded ${allPlants.length} plants for symptom-based search (excluding "Not a Leaf")');
  }

  void _extractSymptoms() {
    final Set<String> symptomsSet = {};
    for (final plant in allPlants) {
      if (plant['symptoms'] != null) {
        for (final symptom in plant['symptoms']) {
          symptomsSet.add(symptom);
        }
      }
    }
    allSymptoms = symptomsSet.toList()..sort();
    suggestedSymptoms = allSymptoms.take(10).toList();
    print('🌿 Extracted ${allSymptoms.length} unique symptoms from ${allPlants.length} plants');
  }

  void _onSearch() async {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        filteredPlants = List.from(allPlants);
      });
      return;
    }
    setState(() {
      // First, find exact matches (symptom exactly matches query)
      final exactMatches = allPlants.where((plant) {
        final symptoms = List<String>.from(plant['symptoms'] ?? []);
        return symptoms.any((symptom) => symptom.toLowerCase() == query);
      }).toList();
      // Then, find partial matches (symptom contains query, but not exact)
      final partialMatches = allPlants.where((plant) {
        final symptoms = List<String>.from(plant['symptoms'] ?? []);
        return symptoms.any((symptom) => symptom.toLowerCase().contains(query)) &&
               !symptoms.any((symptom) => symptom.toLowerCase() == query);
      }).toList();
      filteredPlants = [...exactMatches, ...partialMatches];
    });
    print('🔍 Search for "$query" returned ${filteredPlants.length} plants');
    // Log search if valid and user is logged in (Realtime DB)
    if (filteredPlants.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final searchData = {
          'query': query,
          'timestamp': DateTime.now().toIso8601String(),
          'resultPlantIds': filteredPlants.map((p) => p['id']).toList(),
        };
        final ref = FirebaseDatabase.instance.ref('search/${user.uid}').push();
        await ref.set(searchData);
      }
    }
    // Clear the search bar after search
    _searchController.text = '';
  }

  void _onSymptomChipTap(String symptom) {
    _searchController.text = symptom;
    _onSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FFF5),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Enter a symptom...',
                hintText: 'e.g. Cough',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                        borderSide: const BorderSide(color: Colors.green),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _onSearch,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Symptom Suggestions
            const Text(
              'Common Symptoms',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: suggestedSymptoms
                    .map(
                      (symptom) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                              child: ActionChip(
                      label: Text(symptom),
                      backgroundColor: Colors.green,
                      labelStyle: const TextStyle(color: Colors.white),
                                onPressed: () => _onSymptomChipTap(symptom),
                    ),
                  ),
                )
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            // Display Plant Suggestions
            const Text(
              'Suggested Plants for Your Symptoms',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
                    child: filteredPlants.isEmpty
                        ? const Center(child: Text('No plants found for this symptom.'))
                        : ListView.builder(
                            itemCount: filteredPlants.length,
                itemBuilder: (context, index) {
                              final plant = filteredPlants[index];
                              final plantId = plant['id'] ?? (plantIds.length > index ? plantIds[index] : null);
                              Widget leadingWidget;
                              if (plantId != null) {
                                leadingWidget = Image.asset(
                                  'assets/plant_img/$plantId.jpg',
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_florist, size: 40, color: Colors.green),
                                );
                              } else {
                                leadingWidget = const Icon(Icons.local_florist, size: 40, color: Colors.green);
                              }
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 6,
                    child: ListTile(
                                  leading: leadingWidget,
                                  title: Text(plant['name'] ?? ''),
                                  subtitle: Text((plant['uses'] != null && plant['uses'].isNotEmpty) ? plant['uses'][0] : ''),
                      contentPadding: const EdgeInsets.all(16),
                      onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => PlantResultModal(
                                        classId: int.tryParse(plantId.toString()) ?? 0,
                                        confidence: 1.0,
                                        showConfidence: false,
                                      ),
                                    );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
