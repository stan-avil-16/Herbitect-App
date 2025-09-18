import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:herbal_i/screens/user/login_page.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';


class PlantResultModal extends StatefulWidget {
  final int classId;
  final double confidence;
  final String? scanKey;
  final VoidCallback? onDownloadPdf;
  final VoidCallback? onBookmark;
  final VoidCallback? onScrollMore;
  final bool showConfidence;
  final VoidCallback? onClosed;

  const PlantResultModal({
    Key? key,
    required this.classId,
    required this.confidence,
    this.scanKey,
    this.onDownloadPdf,
    this.onBookmark,
    this.onScrollMore,
    this.showConfidence = true,
    this.onClosed,
  }) : super(key: key);

  @override
  State<PlantResultModal> createState() => _PlantResultModalState();
}

class _PlantResultModalState extends State<PlantResultModal> {
  Map<dynamic, dynamic>? plantData;
  bool loading = true;
  bool showMore = false;
  bool _pendingShowMore = false;
  bool _pendingBookmark = false;
  bool _isBookmarked = false;
  bool _checkingBookmark = false;
  bool _isNotALeaf = false;
  bool _feedbackShown = false;

  // Constants for plant database management
  static const int ML_CLASSES_COUNT = 41; // Classes 0-40 (including "Not a Leaf")
  static const int TOTAL_PLANTS_COUNT = 105; // Plants 0-104
  static const int NOT_A_LEAF_CLASS_ID = 40; // "Not a Leaf" class ID

  @override
  void initState() {
    super.initState();
    _isNotALeaf = widget.classId == NOT_A_LEAF_CLASS_ID;
    
    if (_isNotALeaf) {
      // Handle "Not a Leaf" case
      setState(() {
        loading = false;
        plantData = {
          'name': 'Not a Leaf',
          'scientificName': 'No plant detected',
          'uses': ['This image does not appear to contain a plant leaf.'],
          'howToUse': ['Please try with a clear image of a plant leaf.'],
          'caution': ['Ensure the image contains a visible plant leaf for accurate identification.'],
          'foundIn': 'No plant detected in image',
        };
      });
    } else {
      // Validate class ID range for regular plants
      if (widget.classId < 0 || widget.classId >= TOTAL_PLANTS_COUNT) {
        setState(() {
          loading = false;
          plantData = {
            'name': 'Invalid Plant ID',
            'scientificName': 'Plant ID out of range',
            'uses': ['Plant ID ${widget.classId} is not valid.'],
            'howToUse': ['Please try with a different image.'],
            'caution': ['Invalid plant identification.'],
            'foundIn': 'Invalid plant ID',
          };
        });
      } else {
    fetchPlantInfo();
    _checkBookmarkStatus();
      }
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

  Future<void> _checkBookmarkStatus() async {
    // Don't check bookmarks for "Not a Leaf" or invalid plants
    if (_isNotALeaf || widget.classId < 0 || widget.classId >= TOTAL_PLANTS_COUNT) {
      setState(() { _isBookmarked = false; _checkingBookmark = false; });
      return;
    }
    
    setState(() { _checkingBookmark = true; });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _isBookmarked = false; _checkingBookmark = false; });
      return;
    }
    final ref = FirebaseDatabase.instance.ref('users/${user.uid}/bookmarks');
    final snapshot = await ref.get();
    if (snapshot.exists) {
      final bookmarksData = snapshot.value;
      bool isBookmarked = false;
      
      if (bookmarksData is List) {
        // Old format: just class IDs
        final bookmarks = List<dynamic>.from(bookmarksData);
        isBookmarked = bookmarks.contains(widget.classId);
      } else if (bookmarksData is Map) {
        // New format: classId -> confidence mapping
        final bookmarks = Map<String, dynamic>.from(bookmarksData);
        isBookmarked = bookmarks.containsKey(widget.classId.toString());
      }
      
      setState(() {
        _isBookmarked = isBookmarked;
        _checkingBookmark = false;
      });
    } else {
      setState(() { _isBookmarked = false; _checkingBookmark = false; });
    }
  }

  Future<void> _toggleBookmark() async {
    // Don't allow bookmarking "Not a Leaf" or invalid plants
    if (_isNotALeaf || widget.classId < 0 || widget.classId >= TOTAL_PLANTS_COUNT) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot bookmark this item')),
      );
      return;
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = FirebaseDatabase.instance.ref('users/${user.uid}/bookmarks');
    final snapshot = await ref.get();
    
    Map<String, dynamic> bookmarks = {};
    if (snapshot.exists) {
      final bookmarksData = snapshot.value;
      if (bookmarksData is List) {
        // Convert old format to new format
        final oldBookmarks = List<dynamic>.from(bookmarksData);
        for (int classId in oldBookmarks) {
          bookmarks[classId.toString()] = 1.0; // Default confidence for old bookmarks
        }
      } else if (bookmarksData is Map) {
        // Keep existing format
        bookmarks = Map<String, dynamic>.from(bookmarksData);
      }
    }
    
    final classIdStr = widget.classId.toString();
    if (bookmarks.containsKey(classIdStr)) {
      bookmarks.remove(classIdStr);
    } else {
      bookmarks[classIdStr] = widget.confidence; // Store actual confidence
    }
    
    await ref.set(bookmarks);
    setState(() { _isBookmarked = bookmarks.containsKey(classIdStr); });
  }

  void _handleAction(Future<void> Function() action, {String? pendingAction}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final result = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Login Required'),
          content: const Text('You need to login first.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Continue to Login'),
            ),
          ],
        ),
      );
      if (result == true) {
        setState(() {
          if (pendingAction == 'showMore') _pendingShowMore = true;
          if (pendingAction == 'bookmark') _pendingBookmark = true;
        });
        final loginResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoginPage(
              redirectToPlantId: widget.classId,
              confidence: widget.confidence,
              label: plantData?['name'] ?? '',
              pendingAction: pendingAction,
            ),
          ),
        );
        if (loginResult != null && loginResult is Map<String, dynamic> && loginResult['redirectToPlantId'] != null) {
          // After login, reopen the modal with the returned info
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              builder: (ctx) => PlantResultModal(
                classId: loginResult['redirectToPlantId'],
                confidence: loginResult['confidence'] ?? 0.0,
              ),
            );
          });
        }
      }
    } else {
      await action();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = FirebaseAuth.instance.currentUser;
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (user != null && args != null && args['redirectToPlantId'] == widget.classId) {
      if (args['pendingAction'] == 'showMore' && _pendingShowMore) {
        setState(() {
          showMore = true;
          _pendingShowMore = false;
        });
      }
      if (args['pendingAction'] == 'bookmark' && _pendingBookmark) {
        _toggleBookmark();
        setState(() { _pendingBookmark = false; });
      }
    }
  }

  Future<void> _shareAsPdf() async {
    // 1. Ask for confirmation
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share as PDF'),
        content: const Text('Are you sure you want to share the result as a PDF?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Share')),
        ],
      ),
    );
    if (confirm != true) return;

    // 2. Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Preparing your file...'),
          ],
        ),
      ),
    );

    // 3. Generate PDF
    final pdf = pw.Document();
    final logoBytes = await rootBundle.load('assets/logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    
    // Handle image for "Not a Leaf" and invalid plants
    pw.MemoryImage plantImage;
    try {
      if (_isNotALeaf || widget.classId < 0 || widget.classId >= TOTAL_PLANTS_COUNT) {
        plantImage = logoImage; // Use logo for "Not a Leaf" and invalid plants
      } else {
    final plantImageBytes = await rootBundle.load('assets/plant_img/${widget.classId}.jpg');
        plantImage = pw.MemoryImage(plantImageBytes.buffer.asUint8List());
      }
    } catch (e) {
      plantImage = logoImage; // Fallback to logo if plant image not found
    }
    final plantName = plantData?['name'] ?? 'Unknown';
    final scientificName = plantData?['scientificName'] ?? '';
    final usesList = (plantData?['uses'] is List)
        ? (plantData!['uses'] as List).map((e) => e.toString()).toList()
        : (plantData?['uses']?.toString().split('\n') ?? []);
    final howToUseList = (plantData?['howToUse'] is List)
        ? (plantData!['howToUse'] as List).map((e) => e.toString()).toList()
        : (plantData?['howToUse']?.toString().split('\n') ?? []);
    final cautionList = (plantData?['caution'] is List)
        ? (plantData!['caution'] as List).map((e) => e.toString()).toList()
        : (plantData?['caution']?.toString().split('\n') ?? []);
    final foundIn = plantData?['foundIn'] ?? '';
    final thankYou = 'Thank you! Visit the Herbitect App again.';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          final fadedGreen = PdfColor.fromInt(0xFF43A047);
          return pw.Stack(
            children: [
              pw.Positioned(
                top: 120,
                left: 0,
                right: 0,
                child: pw.Center(
                  child: pw.Opacity(
                    opacity: 0.12,
                    child: pw.Image(logoImage, width: 400, height: 400, fit: pw.BoxFit.contain),
                  ),
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.SizedBox(height: 24),
                  pw.Center(
                    child: pw.Text(
                      'Herbitect',
                      style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: fadedGreen),
                    ),
                  ),
                  pw.Center(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.only(top: 2, bottom: 8),
                      height: 4,
                      width: 120,
                      color: fadedGreen,
                    ),
                  ),
                  pw.Center(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: fadedGreen, width: 2),
                        borderRadius: pw.BorderRadius.circular(16),
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 16,
                        verticalRadius: 16,
                        child: pw.Image(plantImage, width: 180, height: 180, fit: pw.BoxFit.cover),
                      ),
                    ),
                  ),
                  pw.Center(
                    child: pw.Text(
                      plantName,
                      style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: fadedGreen),
                    ),
                  ),
                  pw.Center(
                    child: pw.Text(
                      scientificName,
                      style: pw.TextStyle(fontSize: 16, fontStyle: pw.FontStyle.italic, color: PdfColors.grey800),
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(),
                  if (usesList.isNotEmpty && usesList[0].trim().isNotEmpty) ...[
                    pw.Text('Uses:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: fadedGreen)),
                    pw.Bullet(text: usesList[0]),
                    ...usesList.skip(1).map((e) => pw.Bullet(text: e)),
                    pw.SizedBox(height: 8),
                  ],
                  if (howToUseList.isNotEmpty && howToUseList[0].trim().isNotEmpty) ...[
                    pw.Text('How to Use:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: fadedGreen)),
                    pw.Bullet(text: howToUseList[0]),
                    ...howToUseList.skip(1).map((e) => pw.Bullet(text: e)),
                    pw.SizedBox(height: 8),
                  ],
                  if (cautionList.isNotEmpty && cautionList[0].trim().isNotEmpty) ...[
                    pw.Text('Caution:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColor.fromInt(0xFFFF3333))),
                    pw.Bullet(text: cautionList[0]),
                    ...cautionList.skip(1).map((e) => pw.Bullet(text: e)),
                    pw.SizedBox(height: 8),
                  ],
                  if (foundIn.toString().trim().isNotEmpty) ...[
                    pw.Text('Found In:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: fadedGreen)),
                    pw.Text(foundIn, style: pw.TextStyle(fontSize: 13)),
                    pw.SizedBox(height: 8),
                  ],
                  pw.Spacer(),
                  pw.Divider(),
                  pw.Center(
                    child: pw.Text(
                      thankYou,
                      style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: fadedGreen),
                    ),
                  ),
                  pw.SizedBox(height: 12),
                ],
              ),
            ],
          );
        },
      ),
    );
    final pdfBytes = await pdf.save();

    // 4. Close loading dialog BEFORE sharing
    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    // 5. Save to temp file and share
    final tempDir = await getTemporaryDirectory();
    final fileName = '${plantName.replaceAll('/', '-')}-Herbitect.pdf';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Here is your Herbitect PDF!');

    // 6. Increment sharePdfCount for the scan
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !_isNotALeaf && widget.classId >= 0 && widget.classId < TOTAL_PLANTS_COUNT) {
        final scansRef = FirebaseDatabase.instance.ref('scans/${user.uid}');
        if (widget.scanKey != null) {
          // Directly increment for the known scan
          final shareCountRef = scansRef.child('${widget.scanKey}/sharePdfCount');
          final shareCountSnapshot = await shareCountRef.get();
          int currentCount = 0;
          if (shareCountSnapshot.exists && shareCountSnapshot.value is int) {
            currentCount = shareCountSnapshot.value as int;
          }
          await shareCountRef.set(currentCount + 1);
        } else {
          // Fallback: find the latest scan for this classId
          final scansSnapshot = await scansRef.get();
          if (scansSnapshot.exists) {
            DataSnapshot? latestScan;
            for (final child in scansSnapshot.children) {
              if (child.child('classId').value == widget.classId) {
                if (latestScan == null ||
                    DateTime.parse(child.child('timestamp').value as String).isAfter(
                        DateTime.parse(latestScan.child('timestamp').value as String))) {
                  latestScan = child;
                }
              }
            }
            if (latestScan != null) {
              final scanKey = latestScan.key;
              final shareCountRef = scansRef.child('$scanKey/sharePdfCount');
              final shareCountSnapshot = await shareCountRef.get();
              int currentCount = 0;
              if (shareCountSnapshot.exists && shareCountSnapshot.value is int) {
                currentCount = shareCountSnapshot.value as int;
              }
              await shareCountRef.set(currentCount + 1);
            }
          }
        }
      }
    } catch (e) {
      // Silently ignore errors to not break sharing
    }
  }

  Future<void> _showFeedbackDialog() async {
    if (_feedbackShown) return;
    _feedbackShown = true;
    int resultRating = 0;
    int uiRating = 0;
    TextEditingController commentController = TextEditingController();
    bool submitting = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.feedback_outlined, color: Colors.green.shade700, size: 28),
                          const SizedBox(width: 10),
                          const Text('Feedback', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Georgia', color: Color(0xFF1B5E20))),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text('Would you like to give feedback on the result?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 18),
                      const Text('Did the result match your expectation?', style: TextStyle(fontWeight: FontWeight.w600)),
                      Row(
                        children: List.generate(5, (i) => IconButton(
                          icon: Icon(i < resultRating ? Icons.star : Icons.star_border, color: Colors.amber, size: 28),
                          onPressed: () => setState(() => resultRating = i + 1),
                        )),
                      ),
                      const SizedBox(height: 10),
                      const Text('How was your experience with the result UI?', style: TextStyle(fontWeight: FontWeight.w600)),
                      Row(
                        children: List.generate(5, (i) => IconButton(
                          icon: Icon(i < uiRating ? Icons.star : Icons.star_border, color: Colors.amber, size: 28),
                          onPressed: () => setState(() => uiRating = i + 1),
                        )),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: commentController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Additional feedback',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.green.shade50,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () { Navigator.of(context).pop(); },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            ),
                            onPressed: submitting || resultRating == 0 || uiRating == 0 ? null : () async {
                              setState(() { submitting = true; });
                              final user = FirebaseAuth.instance.currentUser;
                              final feedbackRef = FirebaseDatabase.instance.ref('feedback').push();
                              await feedbackRef.set({
                                'userId': user?.uid ?? '',
                                'classId': widget.classId,
                                'resultRating': resultRating,
                                'uiRating': uiRating,
                                'comment': commentController.text.trim(),
                                'timestamp': DateTime.now().toIso8601String(),
                              });
                              setState(() { submitting = false; });
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you for your feedback!')));
                            },
                            child: submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Handle image path for "Not a Leaf" and invalid plants
    String imagePath;
    if (_isNotALeaf) {
      imagePath = 'assets/logo.png'; // Use logo for "Not a Leaf"
    } else if (widget.classId < 0 || widget.classId >= TOTAL_PLANTS_COUNT) {
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
                        if (widget.showConfidence)
                        Text(
                          'Confidence: ${(widget.confidence * 100).toStringAsFixed(2)}%',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.green, fontWeight: FontWeight.w500),
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
                              if (plantData!['wikiUrl'] != null && plantData!['wikiUrl'].isNotEmpty) ...[
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
                    onTap: () async {
                      if (widget.onClosed != null) {
                        widget.onClosed!();
                      }
                      Navigator.of(context).pop();
                    },
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
                // Blurred Scroll More area
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        height: 80,
                        color: Colors.white.withOpacity(0.7),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                _handleAction(() async {
                                  setState(() {
                                    showMore = true;
                                  });
                                }, pendingAction: 'showMore');
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.lock, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    showMore
                                        ? 'More Info Unlocked'
                                        : 'Scroll More',
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Share as PDF
                                TextButton.icon(
                                  onPressed: () {
                                    _handleAction(_shareAsPdf, pendingAction: 'sharePdf');
                                  },
                                  icon: const Icon(Icons.picture_as_pdf),
                                  label: const Text('Share as PDF'),
                                ),
                                // Add/Remove Bookmark (hidden for "Not a Leaf" and invalid plants)
                                if (!_isNotALeaf && widget.classId >= 0 && widget.classId < TOTAL_PLANTS_COUNT)
                                TextButton.icon(
                                  onPressed: _checkingBookmark
                                      ? null
                                      : () {
                                          _handleAction(() async {
                                            await _toggleBookmark();
                                          }, pendingAction: 'bookmark');
                                        },
                                  icon: Icon(_isBookmarked ? Icons.bookmark_remove : Icons.bookmark_add),
                                  label: Text(_isBookmarked ? 'Remove Bookmark' : 'Add Bookmark'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 