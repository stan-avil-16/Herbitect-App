import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ManagePlantsPage extends StatefulWidget {
  const ManagePlantsPage({super.key});

  @override
  State<ManagePlantsPage> createState() => _ManagePlantsPageState();
}

class _ManagePlantsPageState extends State<ManagePlantsPage> {
  List<Map<String, dynamic>> _plants = [];
  List<Map<String, dynamic>> _filteredPlants = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPlants();
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
      _filteredPlants = _plants.where((plant) {
        final name = (plant['name'] ?? '').toString().toLowerCase();
        final sci = (plant['scientificName'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) || sci.contains(_searchQuery);
      }).toList();
    });
  }

  Future<void> _fetchPlants() async {
    setState(() { _loading = true; _error = null; });
    try {
      final ref = FirebaseDatabase.instance.ref('plants');
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        setState(() { _plants = []; _filteredPlants = []; _loading = false; _error = 'No plants found.'; });
        return;
      }
      final plants = <Map<String, dynamic>>[];
      final data = snapshot.value;
      if (data is Map) {
        data.forEach((key, value) {
          final plant = Map<String, dynamic>.from(value as Map);
          plant['id'] = key.toString();
          plants.add(plant);
        });
      } else if (data is List) {
        for (int i = 0; i < data.length; i++) {
          final value = data[i];
          if (value != null) {
            final plant = Map<String, dynamic>.from(value as Map);
            plant['id'] = i.toString();
            plants.add(plant);
          }
        }
      } else {
        setState(() { _plants = []; _filteredPlants = []; _loading = false; _error = 'Unexpected data format.'; });
        return;
      }
      plants.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      setState(() { _plants = plants; _filteredPlants = plants; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load plants: $e'; _loading = false; });
    }
  }

  void _editPlantDialog(Map<String, dynamic> plant) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditPlantDialog(plant: plant),
    );
    if (result == true) {
      _fetchPlants();
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
                hintText: 'Search plants by name or scientific name...',
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
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _filteredPlants.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final plant = _filteredPlants[index];
              return ListTile(
                leading: _buildPlantImage(plant),
                title: Text(plant['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(plant['scientificName'] ?? ''),
                trailing: ElevatedButton(
                  onPressed: () => _editPlantDialog(plant),
                  child: const Text('Edit'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlantImage(Map<String, dynamic> plant) {
    // Try to get image from plant['image'] or plant['img'] or fallback to assets/plant_img/{id}.jpg
    String? imageUrl = plant['image'] ?? plant['img'];
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(imageUrl),
        radius: 24,
        backgroundColor: Colors.grey[200],
      );
    } else if (plant['id'] != null) {
      // Try to load from assets
      return CircleAvatar(
        backgroundImage: AssetImage('assets/plant_img/${plant['id']}.jpg'),
        radius: 24,
        backgroundColor: Colors.grey[200],
        onBackgroundImageError: (_, __) {},
      );
    } else {
      // Fallback placeholder
      return CircleAvatar(
        child: Icon(Icons.local_florist, color: Colors.green[700]),
        radius: 24,
        backgroundColor: Colors.grey[200],
      );
    }
  }
}

class EditPlantDialog extends StatefulWidget {
  final Map<String, dynamic> plant;
  const EditPlantDialog({super.key, required this.plant});

  @override
  State<EditPlantDialog> createState() => _EditPlantDialogState();
}

class _EditPlantDialogState extends State<EditPlantDialog> {
  late TextEditingController _familyController;
  late TextEditingController _partsUsedController;
  late TextEditingController _usesController;
  late TextEditingController _howToUseController;
  late TextEditingController _cautionController;
  late TextEditingController _foundInController;
  late TextEditingController _wikiUrlController;
  late TextEditingController _symptomsController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _familyController = TextEditingController(text: widget.plant['family'] ?? '');
    _partsUsedController = TextEditingController(text: widget.plant['partsUsed'] ?? '');
    _usesController = TextEditingController(text: (widget.plant['uses'] is List) ? (widget.plant['uses'] as List).join('\n') : (widget.plant['uses'] ?? ''));
    _howToUseController = TextEditingController(text: (widget.plant['howToUse'] is List) ? (widget.plant['howToUse'] as List).join('\n') : (widget.plant['howToUse'] ?? ''));
    _cautionController = TextEditingController(text: (widget.plant['caution'] is List) ? (widget.plant['caution'] as List).join('\n') : (widget.plant['caution'] ?? ''));
    _foundInController = TextEditingController(text: widget.plant['foundIn'] ?? '');
    _wikiUrlController = TextEditingController(text: widget.plant['wikiUrl'] ?? '');
    _symptomsController = TextEditingController(text: (widget.plant['symptoms'] is List) ? (widget.plant['symptoms'] as List).join(', ') : (widget.plant['symptoms'] ?? ''));
  }

  @override
  void dispose() {
    _familyController.dispose();
    _partsUsedController.dispose();
    _usesController.dispose();
    _howToUseController.dispose();
    _cautionController.dispose();
    _foundInController.dispose();
    _wikiUrlController.dispose();
    _symptomsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final id = widget.plant['id'];
      final ref = FirebaseDatabase.instance.ref('plants/$id');
      final update = {
        'family': _familyController.text.trim(),
        'partsUsed': _partsUsedController.text.trim(),
        'uses': _usesController.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'howToUse': _howToUseController.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'caution': _cautionController.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'foundIn': _foundInController.text.trim(),
        'wikiUrl': _wikiUrlController.text.trim(),
        'symptoms': _symptomsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      };
      await ref.update(update);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plant updated successfully!')));
    } catch (e) {
      setState(() { _error = 'Failed to update: $e'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.plant['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(widget.plant['scientificName'] ?? '', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildField('Family', _familyController),
            _buildField('Parts Used', _partsUsedController),
            _buildField('Uses (one per line)', _usesController, maxLines: 4),
            _buildField('How To Use (one per line)', _howToUseController, maxLines: 4),
            _buildField('Caution (one per line)', _cautionController, maxLines: 3),
            _buildField('Found In', _foundInController),
            _buildField('Wikipedia URL', _wikiUrlController),
            _buildField('Symptoms (comma separated)', _symptomsController),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
