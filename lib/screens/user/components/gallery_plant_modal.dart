import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

class GalleryPlantModal extends StatefulWidget {
  final int classId;

  const GalleryPlantModal({
    Key? key,
    required this.classId,
  }) : super(key: key);

  @override
  State<GalleryPlantModal> createState() => _GalleryPlantModalState();
}

class _GalleryPlantModalState extends State<GalleryPlantModal> {
  Map<dynamic, dynamic>? plantData;
  bool loading = true;
  bool showMore = false;
  bool _isInvalidPlant = false;

  // Constants for plant database management
  static const int ML_CLASSES_COUNT = 41; // Classes 0-40 (including "Not a Leaf")
  static const int TOTAL_PLANTS_COUNT = 105; // Plants 0-104
  static const int NOT_A_LEAF_CLASS_ID = 40; // "Not a Leaf" class ID

  @override
  void initState() {
    super.initState();
    
    // Validate plant ID range
    if (widget.classId < 0 || widget.classId >= TOTAL_PLANTS_COUNT) {
      setState(() {
        _isInvalidPlant = true;
        loading = false;
        plantData = {
          'name': 'Invalid Plant ID',
          'scientificName': 'Plant ID out of range',
          'uses': ['Plant ID ${widget.classId} is not valid.'],
          'howToUse': ['Please try with a different plant.'],
          'caution': ['Invalid plant identification.'],
          'foundIn': 'Invalid plant ID',
        };
      });
    } else if (widget.classId == NOT_A_LEAF_CLASS_ID) {
      setState(() {
        _isInvalidPlant = true;
        loading = false;
        plantData = {
          'name': 'Not a Leaf',
          'scientificName': 'No plant detected',
          'uses': ['This is not a plant leaf.'],
          'howToUse': ['Please try with a clear image of a plant leaf.'],
          'caution': ['Ensure the image contains a visible plant leaf.'],
          'foundIn': 'No plant detected',
        };
      });
    } else {
      fetchPlantInfo();
    }
  }

  Future<void> fetchPlantInfo() async {
    try {
      final ref = FirebaseDatabase.instance.ref('plants/${widget.classId}');
      final snapshot = await ref.get();
      if (snapshot.exists) {
        setState(() {
          plantData = Map<dynamic, dynamic>.from(snapshot.value as Map);
          loading = false;
        });
      } else {
        setState(() {
          plantData = null;
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        plantData = null;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle image path for invalid plants and "Not a Leaf"
    String imagePath;
    if (_isInvalidPlant) {
      imagePath = 'assets/logo.png'; // Use logo for invalid plants
    } else {
      imagePath = 'assets/plant_img/${widget.classId}.jpg';
    }
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 24, bottom: 80),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            imagePath,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const SizedBox(height: 180),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          plantData?['name'] ?? 'Unknown',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          plantData?['scientificName'] ?? '',
                          style: const TextStyle(
                              fontSize: 16, fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 12),
                        if (plantData?['uses'] != null)
                          Text(
                            (plantData!['uses'] is List)
                                ? (plantData!['uses'] as List).join("\n")
                                : plantData!['uses'].toString(),
                            style: const TextStyle(fontSize: 15),
                          ),
                        const SizedBox(height: 16),
                        if (showMore && plantData != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              if (plantData!['howToUse'] != null) ...[
                                const Text('How to Use:', style: TextStyle(fontWeight: FontWeight.bold)),
                                if (plantData!['howToUse'] is List)
                                  ...List.generate((plantData!['howToUse'] as List).length, (i) => Text('- ${plantData!['howToUse'][i]}'))
                                else
                                  Text(plantData!['howToUse'].toString()),
                                const SizedBox(height: 8),
                              ],
                              if (plantData!['caution'] != null) ...[
                                const Text('Caution:', style: TextStyle(fontWeight: FontWeight.bold)),
                                if (plantData!['caution'] is List)
                                  ...List.generate((plantData!['caution'] as List).length, (i) => Text('- ${plantData!['caution'][i]}'))
                                else
                                  Text(plantData!['caution'].toString()),
                                const SizedBox(height: 8),
                              ],
                              if (plantData!['foundIn'] != null)
                                Text('Found In: ${plantData!['foundIn']}'),
                              if (plantData!['wikiUrl'] != null && !_isInvalidPlant)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: InkWell(
                                    child: const Text('Wikipedia', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                                    onTap: () async {
                                      final url = plantData!['wikiUrl'];
                                      print('Attempting to launch Wikipedia URL: $url');
                                      final shouldOpen = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Open Wikipedia?'),
                                          content: const Text('This will open the link in your browser. Continue?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Open')),
                                          ],
                                        ),
                                      );
                                      if (shouldOpen == true) {
                                        final uri = Uri.parse(url);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        } else {
                                          print('Could not launch URL: $url');
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Could not open the link: $url')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                // X (close) button
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.close, size: 22, color: Colors.black54),
                    ),
                  ),
                ),
                // Scroll More area (no login required for gallery)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24)),
                    child: Container(
                      height: 80,
                      color: Colors.white.withOpacity(0.9),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                showMore = !showMore;
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(showMore ? Icons.expand_less : Icons.expand_more, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  showMore ? 'Show Less' : 'Show More',
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            height: 1,
                            color: Colors.grey.shade300,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 