import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsReportsPage extends StatefulWidget {
  const AnalyticsReportsPage({super.key});

  @override
  State<AnalyticsReportsPage> createState() => _AnalyticsReportsPageState();
}

class _AnalyticsReportsPageState extends State<AnalyticsReportsPage> {
  DateTimeRange? _selectedRange;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _dailyStats = [];
  int _totalScans = 0;
  int _totalPdfShares = 0;
  int _totalFeedback = 0;

  Future<void> _fetchAnalytics() async {
    if (_selectedRange == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final db = FirebaseDatabase.instance;
      final scansRef = db.ref('scans');
      final feedbackRef = db.ref('feedback');
      final scansSnap = await scansRef.get();
      final feedbackSnap = await feedbackRef.get();
      final Map<String, int> scansPerDay = {};
      final Map<String, int> pdfSharesPerDay = {};
      int totalScans = 0;
      int totalPdfShares = 0;
      // Aggregate scans and PDF shares
      if (scansSnap.exists) {
        for (final userScan in scansSnap.children) {
          for (final scan in userScan.children) {
            final ts = scan.child('timestamp').value;
            if (ts is String) {
              final dt = DateTime.tryParse(ts);
              if (dt != null && dt.isAfter(_selectedRange!.start.subtract(const Duration(days: 1))) && dt.isBefore(_selectedRange!.end.add(const Duration(days: 1)))) {
                final day = DateFormat('yyyy-MM-dd').format(dt);
                scansPerDay[day] = (scansPerDay[day] ?? 0) + 1;
                totalScans++;
                final pdfCount = scan.child('sharePdfCount').value;
                if (pdfCount is int) {
                  pdfSharesPerDay[day] = (pdfSharesPerDay[day] ?? 0) + pdfCount;
                  totalPdfShares += pdfCount;
                } else if (pdfCount is double) {
                  pdfSharesPerDay[day] = (pdfSharesPerDay[day] ?? 0) + pdfCount.toInt();
                  totalPdfShares += pdfCount.toInt();
                }
              }
            }
          }
        }
      }
      // Aggregate feedback
      int totalFeedback = 0;
      if (feedbackSnap.exists) {
        for (final fb in feedbackSnap.children) {
          final ts = fb.child('timestamp').value;
          if (ts is String) {
            final dt = DateTime.tryParse(ts);
            if (dt != null && dt.isAfter(_selectedRange!.start.subtract(const Duration(days: 1))) && dt.isBefore(_selectedRange!.end.add(const Duration(days: 1)))) {
              totalFeedback++;
            }
          }
        }
      }
      // Build daily stats list (only days with data)
      final Set<String> allDays = {...scansPerDay.keys, ...pdfSharesPerDay.keys};
      final List<Map<String, dynamic>> dailyStats = allDays.map((dayStr) => {
        'date': dayStr,
        'scans': scansPerDay[dayStr] ?? 0,
        'pdfShares': pdfSharesPerDay[dayStr] ?? 0,
      }).toList();
      dailyStats.sort((a, b) => a['date'].compareTo(b['date']));
      setState(() {
        _totalScans = totalScans;
        _totalPdfShares = totalPdfShares;
        _totalFeedback = totalFeedback;
        _dailyStats = dailyStats;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load analytics: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        backgroundColor: Colors.deepPurple,
        actions: [
          if (_selectedRange != null && !_loading)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchAnalytics,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(_selectedRange == null
                      ? 'Select Date Range'
                      : '${dateFormat.format(_selectedRange!.start)} - ${dateFormat.format(_selectedRange!.end)}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2022, 1, 1),
                      lastDate: DateTime.now(),
                      initialDateRange: _selectedRange,
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedRange = picked;
                      });
                      await _fetchAnalytics();
                    }
                  },
                ),
                if (_selectedRange != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                    label: const Text('Export PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    onPressed: () {
                      // TODO: Export report as PDF
                    },
                  ),
                if (_selectedRange != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.table_chart, color: Colors.green),
                    label: const Text('Export CSV'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                    onPressed: () {
                      // TODO: Export report as CSV
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (_selectedRange == null)
              const Center(
                child: Text('Select a date range to view analytics and generate reports.',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
              ),
            if (_selectedRange != null && _loading)
              const Center(child: CircularProgressIndicator()),
            if (_selectedRange != null && !_loading && _error == null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSummaryCard(Icons.camera_alt, 'Scans', _totalScans, Colors.teal),
                  _buildSummaryCard(Icons.picture_as_pdf, 'PDF Shares', _totalPdfShares, Colors.redAccent),
                  _buildSummaryCard(Icons.feedback, 'Feedback', _totalFeedback, Colors.orange),
                ],
              ),
              const SizedBox(height: 24),
              if (_dailyStats.isEmpty)
                const Center(child: Text('No data for this range'))
              else ...[
                Text('Activity Overview', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getMaxY(_dailyStats),
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= _dailyStats.length) return const SizedBox.shrink();
                              final date = _dailyStats[idx]['date'];
                              return Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  DateFormat('MM/dd').format(DateTime.parse(date)),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(_dailyStats.length, (idx) {
                        final scans = _dailyStats[idx]['scans'] as int;
                        final pdfShares = _dailyStats[idx]['pdfShares'] as int;
                        return BarChartGroupData(
                          x: idx,
                          barRods: [
                            BarChartRodData(
                              toY: scans.toDouble(),
                              color: Colors.teal,
                              width: 10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            BarChartRodData(
                              toY: pdfShares.toDouble(),
                              color: Colors.redAccent,
                              width: 10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                          showingTooltipIndicators: [0, 1],
                        );
                      }),
                      groupsSpace: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Daily Details', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.deepPurple.withOpacity(0.08)),
                    dataRowColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                      if (states.contains(MaterialState.selected)) {
                        return Colors.deepPurple.withOpacity(0.16);
                      }
                      return null;
                    }),
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Scans')),
                      DataColumn(label: Text('PDF Shares')),
                    ],
                    rows: _dailyStats.map((stat) {
                      return DataRow(cells: [
                        DataCell(Text(stat['date'])),
                        DataCell(Text(stat['scans'].toString())),
                        DataCell(Text(stat['pdfShares'].toString())),
                      ]);
                    }).toList(),
                  ),
                ),
              ],
            ],
            if (_error != null)
              Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  double _getMaxY(List<Map<String, dynamic>> stats) {
    double maxY = 5;
    for (final stat in stats) {
      maxY = [maxY, (stat['scans'] as int).toDouble(), (stat['pdfShares'] as int).toDouble()].reduce((a, b) => a > b ? a : b);
    }
    return maxY < 5 ? 5 : maxY + 2;
  }

  Widget _buildSummaryCard(IconData icon, String label, int count, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: 28),
              radius: 24,
            ),
            const SizedBox(height: 10),
            Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
} 