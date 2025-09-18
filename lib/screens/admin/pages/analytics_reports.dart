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

  @override
  void initState() {
    super.initState();
    // Set default range to last 7 days
    final now = DateTime.now();
    _selectedRange = DateTimeRange(
      start: now.subtract(const Duration(days: 6)),
      end: now,
    );
    _fetchAnalytics();
  }

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
      final Map<String, int> feedbackPerDay = {};
      int totalScans = 0;
      int totalPdfShares = 0;
      int totalFeedback = 0;

      // Aggregate scans and PDF shares
      if (scansSnap.exists) {
        for (final userScan in scansSnap.children) {
          for (final scan in userScan.children) {
            final ts = scan.child('timestamp').value;
            if (ts is String) {
              final dt = DateTime.tryParse(ts);
              if (dt != null && _isInRange(dt)) {
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
      if (feedbackSnap.exists) {
        for (final fb in feedbackSnap.children) {
          final ts = fb.child('timestamp').value;
          if (ts is String) {
            final dt = DateTime.tryParse(ts);
            if (dt != null && _isInRange(dt)) {
              final day = DateFormat('yyyy-MM-dd').format(dt);
              feedbackPerDay[day] = (feedbackPerDay[day] ?? 0) + 1;
              totalFeedback++;
            }
          }
        }
      }

      // Build daily stats list with all days in range
      final List<Map<String, dynamic>> dailyStats = [];
      final start = _selectedRange!.start;
      final end = _selectedRange!.end;
      
      for (int i = 0; i <= end.difference(start).inDays; i++) {
        final date = start.add(Duration(days: i));
        final dayStr = DateFormat('yyyy-MM-dd').format(date);
        dailyStats.add({
          'date': dayStr,
          'scans': scansPerDay[dayStr] ?? 0,
          'pdfShares': pdfSharesPerDay[dayStr] ?? 0,
          'feedback': feedbackPerDay[dayStr] ?? 0,
        });
      }

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

  bool _isInRange(DateTime date) {
    return date.isAfter(_selectedRange!.start.subtract(const Duration(days: 1))) && 
           date.isBefore(_selectedRange!.end.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd');
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Analytics & Reports',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedRange != null && !_loading)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchAnalytics,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchAnalytics,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Range Selector
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.date_range, color: Colors.deepPurple),
                                const SizedBox(width: 8),
                                Text(
                                  'Date Range',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                '${dateFormat.format(_selectedRange!.start)} - ${dateFormat.format(_selectedRange!.end)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              onPressed: () async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2022, 1, 1),
                                  lastDate: DateTime.now(),
                                  initialDateRange: _selectedRange,
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: Colors.deepPurple,
                                          onPrimary: Colors.white,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setState(() {
                                    _selectedRange = picked;
                                  });
                                  await _fetchAnalytics();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Summary Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              Icons.camera_alt,
                              'Scans',
                              _totalScans,
                              Colors.teal,
                              isSmallScreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              Icons.picture_as_pdf,
                              'PDF Shares',
                              _totalPdfShares,
                              Colors.redAccent,
                              isSmallScreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              Icons.feedback,
                              'Feedback',
                              _totalFeedback,
                              Colors.orange,
                              isSmallScreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Activity Overview Chart
                      if (_dailyStats.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.bar_chart, color: Colors.deepPurple),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Activity Overview',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 220,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: _getMaxY(_dailyStats),
                                    barTouchData: BarTouchData(
                                      enabled: true,
                                      touchTooltipData: BarTouchTooltipData(
                                        tooltipBgColor: Colors.white,
                                        tooltipBorder: BorderSide(color: Colors.grey.shade300),
                                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                          String label = '';
                                          Color color = Colors.teal;
                                          switch (rodIndex) {
                                            case 0:
                                              label = 'Scans: ${rod.toY.toInt()}';
                                              color = Colors.teal;
                                              break;
                                            case 1:
                                              label = 'PDF Shares: ${rod.toY.toInt()}';
                                              color = Colors.redAccent;
                                              break;
                                            case 2:
                                              label = 'Feedback: ${rod.toY.toInt()}';
                                              color = Colors.orange;
                                              break;
                                          }
                                          return BarTooltipItem(
                                            label,
                                            TextStyle(color: color, fontWeight: FontWeight.w600),
                                          );
                                        },
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                          getTitlesWidget: (value, meta) {
                                            return Text(
                                              value.toInt().toString(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            final idx = value.toInt();
                                            if (idx < 0 || idx >= _dailyStats.length) {
                                              return const SizedBox.shrink();
                                            }
                                            final date = _dailyStats[idx]['date'];
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Text(
                                                DateFormat('MM/dd').format(DateTime.parse(date)),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      horizontalInterval: 1,
                                      getDrawingHorizontalLine: (value) {
                                        return FlLine(
                                          color: Colors.grey.shade200,
                                          strokeWidth: 1,
                                        );
                                      },
                                    ),
                                    borderData: FlBorderData(show: false),
                                    barGroups: List.generate(_dailyStats.length, (idx) {
                                      final scans = _dailyStats[idx]['scans'] as int;
                                      final pdfShares = _dailyStats[idx]['pdfShares'] as int;
                                      final feedback = _dailyStats[idx]['feedback'] as int;
                                      
                                      return BarChartGroupData(
                                        x: idx,
                                        barRods: [
                                          BarChartRodData(
                                            toY: scans.toDouble(),
                                            color: Colors.teal,
                                            width: 8,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          BarChartRodData(
                                            toY: pdfShares.toDouble(),
                                            color: Colors.redAccent,
                                            width: 8,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          BarChartRodData(
                                            toY: feedback.toDouble(),
                                            color: Colors.orange,
                                            width: 8,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ],
                                      );
                                    }),
                                    groupsSpace: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Legend
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildLegendItem('Scans', Colors.teal),
                                  _buildLegendItem('PDF Shares', Colors.redAccent),
                                  _buildLegendItem('Feedback', Colors.orange),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Daily Details Table
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Icon(Icons.table_chart, color: Colors.deepPurple),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Daily Details',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: MaterialStateProperty.all(Colors.deepPurple.withOpacity(0.08)),
                                  dataRowColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                                    if (states.contains(MaterialState.selected)) {
                                      return Colors.deepPurple.withOpacity(0.16);
                                    }
                                    return null;
                                  }),
                                  columns: [
                                    DataColumn(
                                      label: Text(
                                        'Date',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Scans',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'PDF Shares',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Feedback',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                  rows: _dailyStats.map((stat) {
                                    return DataRow(cells: [
                                      DataCell(Text(
                                        DateFormat('MMM dd').format(DateTime.parse(stat['date'])),
                                        style: const TextStyle(fontSize: 12),
                                      )),
                                      DataCell(Text(
                                        stat['scans'].toString(),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      )),
                                      DataCell(Text(
                                        stat['pdfShares'].toString(),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      )),
                                      DataCell(Text(
                                        stat['feedback'].toString(),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      )),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'No data available for this date range',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  double _getMaxY(List<Map<String, dynamic>> stats) {
    double maxY = 1;
    for (final stat in stats) {
      final maxValue = [
        (stat['scans'] as int).toDouble(),
        (stat['pdfShares'] as int).toDouble(),
        (stat['feedback'] as int).toDouble(),
      ].reduce((a, b) => a > b ? a : b);
      if (maxValue > maxY) maxY = maxValue;
    }
    return maxY < 1 ? 1 : maxY + 1;
  }

  Widget _buildSummaryCard(IconData icon, String label, int count, Color color, bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: isSmallScreen ? 20 : 24),
            radius: isSmallScreen ? 18 : 22,
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 18 : 20,
              color: Colors.grey.shade800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
} 