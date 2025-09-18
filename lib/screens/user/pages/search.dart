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
  bool isSearching = false;
  bool hasSearched = false;

  // Constants for plant database management
  static const int ML_CLASSES_COUNT = 41; // Classes 0-40 (including "Not a Leaf")
  static const int TOTAL_PLANTS_COUNT = 105; // Plants 0-104
  static const int NOT_A_LEAF_CLASS_ID = 40; // "Not a Leaf" class ID

  @override
  void initState() {
    super.initState();
    _loadPlantData();
    // Do not show any plants by default
    filteredPlants = [];
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
    // Clear the search bar and results when the page is re-entered
    _searchController.clear();
    setState(() {
      filteredPlants = [];
      hasSearched = false;
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
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        filteredPlants = [];
        hasSearched = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
      hasSearched = true;
    });

    // Simulate loading time for better UX
    await Future.delayed(const Duration(milliseconds: 800));

    // First, find exact matches (symptom exactly matches query)
    final exactMatches = allPlants.where((plant) {
      final symptoms = List<String>.from(plant['symptoms'] ?? []);
      return symptoms.any((symptom) => symptom.toLowerCase() == query.toLowerCase());
    }).toList();
    
    // Then, find partial matches (symptom contains query, but not exact)
    final partialMatches = allPlants.where((plant) {
      final symptoms = List<String>.from(plant['symptoms'] ?? []);
      return symptoms.any((symptom) => symptom.toLowerCase().contains(query.toLowerCase())) &&
             !symptoms.any((symptom) => symptom.toLowerCase() == query.toLowerCase());
    }).toList();
    
    setState(() {
      filteredPlants = [...exactMatches, ...partialMatches];
      isSearching = false;
    });

    // Log search to Firebase if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final searchData = {
          'userId': user.uid,
          'query': query,
          'timestamp': DateTime.now().toIso8601String(),
          'resultPlantIds': filteredPlants.map((p) => p['id']).toList(),
        };
        final ref = FirebaseDatabase.instance.ref('search/${user.uid}').push();
        await ref.set(searchData);
      } catch (e) {
        // Silently handle Firebase errors
      }
    }
  }

  void _onSymptomChipTap(String symptom) {
    _searchController.text = symptom;
    _onSearch();
  }

  @override
  Widget build(BuildContext context) {
    final isSearchActive = _searchController.text.trim().isNotEmpty;
    
    return Container(
      color: const Color(0xFFF5FFF5),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar with Search Button
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  // Force UI update when text changes
                });
              },
              decoration: InputDecoration(
                labelText: 'Enter a symptom...',
                hintText: 'e.g. Cough',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Colors.green),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Colors.green),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Colors.green, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                suffixIcon: isSearchActive
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () { 
                              _searchController.clear(); 
                              setState(() {
                                filteredPlants = [];
                                hasSearched = false;
                              });
                            },
                          ),
                          if (!isSearching)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: ElevatedButton(
                                onPressed: _onSearch,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: const Size(60, 32),
                                ),
                                child: const Text('Search', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          if (isSearching)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                ),
                              ),
                            ),
                        ],
                      )
                    : null,
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
            // Results or Prompt
            Expanded(
              child: (!hasSearched)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 64, color: Colors.green.shade200),
                          const SizedBox(height: 16),
                          const Text(
                            'Type the name of a symptom and tap search to see results.',
                            style: TextStyle(fontSize: 18, color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          child: isSearching
                              ? const Center(child: CircularProgressIndicator())
                              : filteredPlants.isEmpty
                                  ? const Center(child: Text('No plants found for this symptom.'))
                                  : ListView.builder(
                                      itemCount: filteredPlants.length,
                                      itemBuilder: (context, index) {
                                        final plant = filteredPlants[index];
                                        final plantId = plant['id'] ?? (plantIds.length > index ? plantIds[index] : null);
                                        Widget leadingWidget;
                                        if (plantId != null) {
                                          leadingWidget = ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.asset(
                                              'assets/plant_img/$plantId.jpg',
                                              width: 48,
                                              height: 48,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_florist, size: 40, color: Colors.green),
                                            ),
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
          ],
        ),
      ),
    );
  }
}
