import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:herbal_i/screens/user/pages/bookmarks.dart';
import 'package:herbal_i/screens/user/components/plant_result_modal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';

final GlobalKey<_PersonalizationTileState> _personalizationTileKey = GlobalKey<_PersonalizationTileState>();

class DashboardPage extends StatefulWidget {
  final void Function()? onGoToBookmarks;
  const DashboardPage({super.key, this.onGoToBookmarks});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<dynamic> _allSpotlights = [];
  List<dynamic> _allExplores = [];
  List<dynamic> _currentSpotlights = [];
  List<dynamic> _currentExplores = [];
  Timer? _timer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDataAndStartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDataAndStartTimer() async {
    setState(() { _loading = true; });
    final spotlightsSnap = await FirebaseDatabase.instance.ref('spotlight').once();
    final exploresSnap = await FirebaseDatabase.instance.ref('explore').once();
    List<dynamic> spotlights = [];
    List<dynamic> explores = [];
    final spotVal = spotlightsSnap.snapshot.value;
    if (spotVal is List) {
      spotlights = spotVal;
    } else if (spotVal is Map) {
      spotlights = (spotVal as Map).values.toList();
    }
    spotlights = spotlights.where((e) => e != null).toList();
    final expVal = exploresSnap.snapshot.value;
    if (expVal is Map) {
      explores = (expVal as Map).values.toList();
    } else if (expVal is List) {
      explores = expVal;
    }
    explores = explores.where((e) => e != null).toList();
    setState(() {
      _allSpotlights = spotlights;
      _allExplores = explores;
      _loading = false;
    });
    _randomizeContent();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _randomizeContent());
  }

  void _randomizeContent() {
    final rand = Random();
    List<dynamic> spotCopy = List.from(_allSpotlights);
    List<dynamic> expCopy = List.from(_allExplores);
    spotCopy.shuffle(rand);
    expCopy.shuffle(rand);
    setState(() {
      _currentSpotlights = spotCopy.take(5).toList();
      _currentExplores = expCopy.take(8).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          return RefreshIndicator(
            onRefresh: () async {
              final tileState = _personalizationTileKey.currentState;
              if (tileState != null) {
                await tileState.refreshPersonalizationData();
              }
              await _fetchDataAndStartTimer();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                    Text(
                      "Welcome to Herbitect!",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
            const SizedBox(height: 16),
                    _PersonalizationTile(
                      key: _personalizationTileKey,
                      user: user,
                      onGoToBookmarks: widget.onGoToBookmarks,
                    ),
                    const SizedBox(height: 18),
                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildSpotlightTile(_currentSpotlights),
                    const SizedBox(height: 18),
                    _loading
                        ? const SizedBox.shrink()
                        : _buildExploreMoreSection(_currentExplores),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpotlightTile(List<dynamic> spotlights) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: const Color(0xFFF1FAF3),
      shadowColor: const Color(0xFF43A047).withOpacity(0.10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF43A047).withOpacity(0.18), width: 1.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.psychology, color: Color(0xFF43A047), size: 28),
                  const SizedBox(width: 8),
                  Text(
                    "Herbal Spotlight",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (spotlights.isEmpty)
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[400], size: 22),
                    const SizedBox(width: 8),
                    Text(
                      "No spotlights available.",
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                )
              else
                ...spotlights.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        e['spotlight'] ?? '',
                        style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[800]),
                        textAlign: TextAlign.justify,
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExploreMoreSection(List<dynamic> explores) {
    final List<Color> tileColors = [
      Color(0xFFE8F5E9),
      Color(0xFFE3F2FD),
      Color(0xFFFFF3E0),
      Color(0xFFF3E5F5),
      Color(0xFFFFEBEE),
      Color(0xFFE0F2F1),
      Color(0xFFE1F5FE),
      Color(0xFFFFF9C4),
    ];
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.explore, color: Color(0xFF43A047), size: 28),
                const SizedBox(width: 8),
                Text(
                  "Explore More",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (explores.isEmpty)
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[400], size: 22),
                  const SizedBox(width: 8),
                  Text(
                    "No explore content available.",
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              )
            else
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: explores.length,
                  itemBuilder: (context, index) {
                    final color = tileColors[index % tileColors.length];
                    return Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                            color: Colors.grey.withOpacity(0.10),
                            blurRadius: 6,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            explores[index]['title'] ?? '',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.grey[900],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Text(
                              explores[index]['explore'] ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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

class _PersonalizationTile extends StatefulWidget {
  final User? user;
  final void Function()? onGoToBookmarks;
  const _PersonalizationTile({Key? key, required this.user, this.onGoToBookmarks}) : super(key: key);
  @override
  State<_PersonalizationTile> createState() => _PersonalizationTileState();
}

class _PersonalizationTileState extends State<_PersonalizationTile> with SingleTickerProviderStateMixin {
  int bookmarkCount = 0;
  String? lastSearchQuery;
  DateTime? lastSearchTime;
  Map<String, dynamic>? lastScanResult;
  bool loading = true;
  late AnimationController _controller;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _fetchPersonalizationData();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant _PersonalizationTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user?.uid != oldWidget.user?.uid) {
      _fetchPersonalizationData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Optionally, always refetch data when dependencies change
    // _fetchPersonalizationData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchPersonalizationData() async {
    if (widget.user == null) {
      setState(() { loading = false; });
      return;
    }
    final uid = widget.user!.uid;
    // Fetch bookmarks
    final bookmarksRef = FirebaseDatabase.instance.ref('users/$uid/bookmarks');
    final bookmarksSnapshot = await bookmarksRef.get();
    int count = 0;
    if (bookmarksSnapshot.exists) {
      final data = bookmarksSnapshot.value;
      if (data is List) {
        count = data.length;
      } else if (data is Map) {
        count = data.length;
      }
    }
    // Fetch last search
    final searchRef = FirebaseDatabase.instance.ref('search/$uid');
    final searchSnapshot = await searchRef.get();
    String? lastQuery;
    DateTime? lastTime;
    if (searchSnapshot.exists) {
      final searches = searchSnapshot.children.toList();
      searches.sort((a, b) {
        final aTime = DateTime.tryParse(a.child('timestamp').value?.toString() ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b.child('timestamp').value?.toString() ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      if (searches.isNotEmpty) {
        lastQuery = searches.first.child('query').value?.toString();
        lastTime = DateTime.tryParse(searches.first.child('timestamp').value?.toString() ?? '');
      }
    }
    // Fetch last scanned result (from scans)
    final scansRef = FirebaseDatabase.instance.ref('scans/$uid');
    final scansSnapshot = await scansRef.get();
    Map<String, dynamic>? lastScan;
    if (scansSnapshot.exists) {
      final scans = scansSnapshot.children.toList();
      scans.sort((a, b) {
        final aTime = DateTime.tryParse(a.child('timestamp').value?.toString() ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b.child('timestamp').value?.toString() ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      if (scans.isNotEmpty) {
        lastScan = {
          'plantName': scans.first.child('plantName').value,
          'confidence': scans.first.child('confidence').value,
          'classId': scans.first.child('classId').value,
          'timestamp': scans.first.child('timestamp').value,
        };
      }
    }
    setState(() {
      bookmarkCount = count;
      lastSearchQuery = lastQuery;
      lastSearchTime = lastTime;
      lastScanResult = lastScan;
      loading = false;
    });
  }

  Future<void> refreshPersonalizationData() async {
    await _fetchPersonalizationData();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.eco, color: Color(0xFF43A047), size: 32),
                const SizedBox(width: 8),
                Text(
                  "Personalization",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.user == null)
              Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.grey[400], size: 22),
                  const SizedBox(width: 8),
                  Text(
                    "Login to access your personalized data.",
                    style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[600]),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bookmark, color: Color(0xFF43A047), size: 22),
                      const SizedBox(width: 6),
                      Text(
                        "$bookmarkCount Bookmarked",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.grey[900]),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF43A047),
                          foregroundColor: Colors.white,
                          shape: StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          elevation: 0,
                        ),
                        onPressed: widget.onGoToBookmarks,
                        icon: Icon(Icons.arrow_forward, size: 18),
                        label: Text("View Bookmarks", style: GoogleFonts.poppins(fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.search, color: Colors.grey[700], size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: lastSearchQuery != null && lastSearchTime != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Last searched:", style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 13)),
                                  Text(
                                    lastSearchQuery!,
                                    style: GoogleFonts.poppins(color: Colors.grey[900], fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    "at "+_formatDateTime(lastSearchTime!),
                                    style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Color(0xFF43A047),
                                      side: BorderSide(color: Color(0xFF43A047)),
                                    ),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => SearchHistoryDialog(user: widget.user!),
                                      );
                                    },
                                    icon: Icon(Icons.history),
                                    label: Text("Search History", style: GoogleFonts.poppins()),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.grey[400], size: 20),
                                  const SizedBox(width: 6),
                                  Text("No search history yet.", style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13)),
                                ],
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(color: Colors.grey[400]),
              const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.camera_alt_outlined, color: Colors.grey[700], size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: lastScanResult != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Last Scan:", style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 13)),
                                  Text(
                                    lastScanResult!["plantName"] ?? '',
                                    style: GoogleFonts.poppins(color: Colors.grey[900], fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    "Confidence: "+((lastScanResult!["confidence"] ?? 0.0) * 100).toStringAsFixed(2)+"%",
                                    style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
                                  ),
                                  Text(
                                    "at "+_formatDateTime(DateTime.tryParse(lastScanResult!["timestamp"] ?? '') ?? DateTime(1970)),
                                    style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.grey[400], size: 20),
                                  const SizedBox(width: 6),
                                  Text("No scanned results yet.", style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13)),
                                ],
                              ),
                      ),
                    ],
                  ),
              const SizedBox(height: 10),
              const SizedBox(height: 10),
                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF43A047),
                        foregroundColor: Colors.white,
                        shape: StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => ScanHistoryDialog(user: widget.user!),
                        );
                      },
                      icon: Icon(Icons.history),
                      label: Text('Tap to view more', style: GoogleFonts.poppins(fontSize: 15)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return "${dt.day} ${_monthName(dt.month)} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
  String _monthName(int m) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[m - 1];
  }
}

class SearchHistoryDialog extends StatefulWidget {
  final User user;
  const SearchHistoryDialog({required this.user});
  @override
  State<SearchHistoryDialog> createState() => _SearchHistoryDialogState();
}

class _SearchHistoryDialogState extends State<SearchHistoryDialog> {
  List<Map<String, dynamic>> searches = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchSearchHistory();
  }

  Future<void> _fetchSearchHistory() async {
    final uid = widget.user.uid;
    final searchRef = FirebaseDatabase.instance.ref('search/$uid');
    final searchSnapshot = await searchRef.get();
    List<Map<String, dynamic>> searchList = [];
    if (searchSnapshot.exists) {
      final children = searchSnapshot.children.toList();
      children.sort((a, b) {
        final aTime = DateTime.tryParse(a.child('timestamp').value?.toString() ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b.child('timestamp').value?.toString() ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      for (final snap in children) {
        final query = snap.child('query').value?.toString();
        final timestamp = snap.child('timestamp').value?.toString();
        if (query != null && timestamp != null) {
          searchList.add({
            'query': query,
            'timestamp': timestamp,
          });
        }
      }
    }
    setState(() {
      searches = searchList;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 350,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(20),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Search History", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
                  const SizedBox(height: 10),
                  if (searches.isEmpty)
                    const Text("No search history found."),
                  if (searches.isNotEmpty)
                    Expanded(
                      child: ListView.separated(
                        itemCount: searches.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final s = searches[index];
                          final dt = DateTime.tryParse(s['timestamp'] ?? '') ?? DateTime(1970);
                          return ListTile(
                            title: Text(s['query']),
                            subtitle: Text(_formatDateTime(dt)),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return "${dt.day} ${_monthName(dt.month)} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
  String _monthName(int m) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[m - 1];
  }
}

class ScanHistoryDialog extends StatefulWidget {
  final User user;
  const ScanHistoryDialog({required this.user});
  @override
  State<ScanHistoryDialog> createState() => _ScanHistoryDialogState();
}

class _ScanHistoryDialogState extends State<ScanHistoryDialog> {
  List<Map<String, dynamic>> scans = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchScanHistory();
  }

  Future<void> _fetchScanHistory() async {
    final uid = widget.user.uid;
    final scansRef = FirebaseDatabase.instance.ref('scans/$uid');
    final scansSnapshot = await scansRef.get();
    List<Map<String, dynamic>> scanList = [];
    if (scansSnapshot.exists) {
      final children = scansSnapshot.children.toList();
      children.sort((a, b) {
        final aTime = DateTime.tryParse(a.child('timestamp').value?.toString() ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b.child('timestamp').value?.toString() ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      for (final snap in children) {
        final plantName = snap.child('plantName').value?.toString();
        final confidence = snap.child('confidence').value;
        final classId = snap.child('classId').value;
        final timestamp = snap.child('timestamp').value?.toString();
        if (plantName != null && confidence != null && classId != null && timestamp != null) {
          scanList.add({
            'plantName': plantName,
            'confidence': confidence,
            'classId': classId,
            'timestamp': timestamp,
          });
        }
      }
    }
    setState(() {
      scans = scanList;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 350,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(20),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Scan History", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                  const SizedBox(height: 10),
                  if (scans.isEmpty)
                    const Text("No scan history found."),
                  if (scans.isNotEmpty)
                    Expanded(
                      child: ListView.separated(
                        itemCount: scans.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final s = scans[index];
                          final dt = DateTime.tryParse(s['timestamp'] ?? '') ?? DateTime(1970);
                          return ListTile(
                            title: Text(s['plantName']),
                            subtitle: Text("Confidence: "+((s['confidence'] ?? 0.0) * 100).toStringAsFixed(2)+"%\nClass ID: "+s['classId'].toString()+"\n"+_formatDateTime(dt)),
                            trailing: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                showDialog(
                                  context: context,
                                  builder: (_) => PlantResultModal(
                                    classId: int.tryParse(s['classId'].toString()) ?? 0,
                                    confidence: (s['confidence'] is double) ? s['confidence'] : double.tryParse(s['confidence'].toString()) ?? 0.0,
                                  ),
                                );
                              },
                              child: const Text('View'),
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

  String _formatDateTime(DateTime dt) {
    return "${dt.day} ${_monthName(dt.month)} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
  String _monthName(int m) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[m - 1];
  }
}
