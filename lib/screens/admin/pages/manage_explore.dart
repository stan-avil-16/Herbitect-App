import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ManageExplorePage extends StatefulWidget {
  static String? initialTab;
  const ManageExplorePage({super.key});

  @override
  State<ManageExplorePage> createState() => _ManageExplorePageState();
}

enum ContentType { spotlight, explore }

class _ManageExplorePageState extends State<ManageExplorePage> {
  ContentType? _selectedType;
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (ManageExplorePage.initialTab != null) {
      if (ManageExplorePage.initialTab == 'spotlight') {
        _selectedType = ContentType.spotlight;
        _onSelect(ContentType.spotlight);
      } else if (ManageExplorePage.initialTab == 'explore') {
        _selectedType = ContentType.explore;
        _onSelect(ContentType.explore);
      }
      ManageExplorePage.initialTab = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCard('Spotlight', Icons.psychology, () => _onSelect(ContentType.spotlight), _selectedType == ContentType.spotlight),
              _buildCard('Explore More', Icons.explore, () => _onSelect(ContentType.explore), _selectedType == ContentType.explore),
              _buildCard('Add Content', Icons.add, _onAddContent, false, color: Colors.green.shade100),
            ],
          ),
        ),
        if (_selectedType != null)
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : _items.isEmpty
                        ? const Center(child: Text('No content found.'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(24),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 18),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green.shade50,
                                      Colors.green.shade100,
                                      Colors.white,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.08),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedType == ContentType.spotlight ? (item['spotlight'] ?? '') : (item['title'] ?? ''),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                fontFamily: 'Georgia',
                                                color: Color(0xFF1B5E20),
                                              ),
                                            ),
                                            if (_selectedType == ContentType.explore)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 8.0),
      child: Text(
                                                  item['explore'] ?? '',
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    color: Color(0xFF388E3C),
                                                    fontFamily: 'Georgia',
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Color(0xFF388E3C)),
                                            tooltip: 'Edit',
                                            onPressed: () => _editItemDialog(item),
                                          ),
                                          const SizedBox(height: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                            tooltip: 'Delete',
                                            onPressed: () => _confirmDelete(item),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
      ],
    );
  }

  Widget _buildCard(String label, IconData icon, VoidCallback onTap, bool selected, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 100,
        decoration: BoxDecoration(
          color: selected ? Colors.green.shade200 : (color ?? Colors.white),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(2, 4),
            ),
          ],
          border: Border.all(color: selected ? Colors.green : Colors.grey.shade300, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.green.shade800),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  void _onSelect(ContentType type) async {
    setState(() { _selectedType = type; _loading = true; _error = null; _items = []; });
    try {
      final ref = FirebaseDatabase.instance.ref(type == ContentType.spotlight ? 'spotlight' : 'explore');
      final snapshot = await ref.get();
      List<Map<String, dynamic>> items = [];
      if (snapshot.exists) {
        if (snapshot.value is List) {
          final list = List.from(snapshot.value as List);
          for (var e in list) {
            if (e != null) items.add(Map<String, dynamic>.from(e));
          }
        } else if (snapshot.value is Map) {
          final map = Map.from(snapshot.value as Map);
          for (var e in map.values) {
            if (e != null) items.add(Map<String, dynamic>.from(e));
          }
        }
      }
      setState(() { _items = items; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load content: $e'; _loading = false; });
    }
  }

  void _editItemDialog(Map<String, dynamic> item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditContentDialog(
        type: _selectedType!,
        item: item,
      ),
    );
    if (result == true) {
      _onSelect(_selectedType!);
    }
  }

  void _onAddContent() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddContentDialog(),
    );
    if (result == true && _selectedType != null) {
      _onSelect(_selectedType!);
    }
  }

  void _confirmDelete(Map<String, dynamic> item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Confirmation'),
        content: const Text('Are you sure you want to delete this content? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _deleteItem(item);
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    try {
      DatabaseReference ref;
      if (_selectedType == ContentType.spotlight) {
        ref = FirebaseDatabase.instance.ref('spotlight/${item['id'] ?? item['id'] ?? ''}');
      } else {
        ref = FirebaseDatabase.instance.ref('explore/${item['id'] ?? item['id'] ?? ''}');
      }
      await ref.remove();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Content deleted successfully!')));
      _onSelect(_selectedType!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }
}

class EditContentDialog extends StatefulWidget {
  final ContentType type;
  final Map<String, dynamic> item;
  const EditContentDialog({super.key, required this.type, required this.item});

  @override
  State<EditContentDialog> createState() => _EditContentDialogState();
}

class _EditContentDialogState extends State<EditContentDialog> {
  late TextEditingController _spotlightController;
  late TextEditingController _titleController;
  late TextEditingController _exploreController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _spotlightController = TextEditingController(text: widget.item['spotlight'] ?? '');
    _titleController = TextEditingController(text: widget.item['title'] ?? '');
    _exploreController = TextEditingController(text: widget.item['explore'] ?? '');
  }

  @override
  void dispose() {
    _spotlightController.dispose();
    _titleController.dispose();
    _exploreController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      DatabaseReference ref;
      Map<String, dynamic> update;
      if (widget.type == ContentType.spotlight) {
        ref = FirebaseDatabase.instance.ref('spotlight/${widget.item['id'] ?? widget.item['id'] ?? ''}');
        update = {'spotlight': _spotlightController.text.trim()};
      } else {
        ref = FirebaseDatabase.instance.ref('explore/${widget.item['id'] ?? widget.item['id'] ?? ''}');
        update = {
          'title': _titleController.text.trim(),
          'explore': _exploreController.text.trim(),
        };
      }
      await ref.update(update);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Content updated successfully!')));
    } catch (e) {
      setState(() { _error = 'Failed to update: $e'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.type == ContentType.spotlight ? 'Edit Spotlight' : 'Edit Explore Content'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.type == ContentType.spotlight)
              TextField(
                controller: _spotlightController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Spotlight', border: OutlineInputBorder()),
              ),
            if (widget.type == ContentType.explore) ...[
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _exploreController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Explore Content', border: OutlineInputBorder()),
              ),
            ],
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
}

class AddContentDialog extends StatefulWidget {
  const AddContentDialog({super.key});

  @override
  State<AddContentDialog> createState() => _AddContentDialogState();
}

class _AddContentDialogState extends State<AddContentDialog> {
  ContentType? _type;
  final TextEditingController _spotlightController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _exploreController = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_type == null) {
      setState(() { _error = 'Please select content type.'; });
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      DatabaseReference ref;
      Map<String, dynamic> data;
      if (_type == ContentType.spotlight) {
        ref = FirebaseDatabase.instance.ref('spotlight').push();
        data = {'spotlight': _spotlightController.text.trim()};
      } else {
        ref = FirebaseDatabase.instance.ref('explore').push();
        data = {
          'title': _titleController.text.trim(),
          'explore': _exploreController.text.trim(),
        };
      }
      await ref.set(data);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Content added successfully!')));
    } catch (e) {
      setState(() { _error = 'Failed to add: $e'; _saving = false; });
    }
  }

  @override
  void dispose() {
    _spotlightController.dispose();
    _titleController.dispose();
    _exploreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 12,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.green.shade700, size: 32),
                  const SizedBox(width: 10),
                  const Text(
                    'Add Content',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Georgia',
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [Colors.green.shade50, Colors.green.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<ContentType>(
                      value: _type,
                      items: const [
                        DropdownMenuItem(value: ContentType.spotlight, child: Text('Spotlight')),
                        DropdownMenuItem(value: ContentType.explore, child: Text('Explore More')),
                      ],
                      onChanged: (val) => setState(() => _type = val),
                      decoration: InputDecoration(
                        labelText: 'Content Type',
                        prefixIcon: Icon(Icons.category, color: Colors.green.shade700),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_type == ContentType.spotlight)
                      TextField(
                        controller: _spotlightController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Spotlight',
                          prefixIcon: Icon(Icons.psychology, color: Colors.orange.shade700),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    if (_type == ContentType.explore) ...[
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          prefixIcon: Icon(Icons.title, color: Colors.blue.shade700),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _exploreController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Explore Content',
                          prefixIcon: Icon(Icons.explore, color: Colors.green.shade700),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Add', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
