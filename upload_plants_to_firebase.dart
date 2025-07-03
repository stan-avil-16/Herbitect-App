import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
    
    // Read the plants.json file
    final file = File('assets/plants.json');
    if (!await file.exists()) {
      print('Error: plants.json file not found');
      return;
    }
    
    final jsonString = await file.readAsString();
    final jsonData = json.decode(jsonString);
    
    // Get the plants data
    final plantsData = jsonData['plants'] as Map<String, dynamic>;
    print('Found ${plantsData.length} plants in JSON file');
    
    // Upload to Firebase
    final database = FirebaseDatabase.instance;
    final plantsRef = database.ref('plants');
    
    print('Uploading plants to Firebase...');
    
    // Upload each plant
    for (final entry in plantsData.entries) {
      final plantId = entry.key;
      final plantData = entry.value as Map<String, dynamic>;
      
      try {
        await plantsRef.child(plantId).set(plantData);
        print('Uploaded plant: ${plantData['name']} (ID: $plantId)');
      } catch (e) {
        print('Error uploading plant $plantId: $e');
      }
    }
    
    print('Upload completed successfully!');
    
  } catch (e) {
    print('Error: $e');
  }
} 