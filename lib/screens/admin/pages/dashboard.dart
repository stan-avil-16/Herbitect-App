import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:herbal_i/screens/admin/pages/manage_users.dart';
import 'package:herbal_i/screens/admin/pages/manage_plants.dart';

class DashboardPage extends StatefulWidget {
  final void Function(int)? onTileTap;
  const DashboardPage({super.key, this.onTileTap});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  int _totalUsers = 0;
  int _totalPlants = 0;
  int _totalSpotlight = 0;
  int _totalExplore = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCounts();
  }

  Future<void> _fetchCounts() async {
    try {
      final usersSnapshot = await _dbRef.child('users').get();
      final plantsSnapshot = await _dbRef.child('plants').get();
      final spotlightSnapshot = await _dbRef.child('spotlight').get();
      final exploreSnapshot = await _dbRef.child('explore').get();

      if (!mounted) return;

      setState(() {
        _totalUsers = usersSnapshot.children.length;
        _totalPlants = plantsSnapshot.children.length;
        _totalSpotlight = spotlightSnapshot.children.length;
        _totalExplore = exploreSnapshot.children.length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching counts: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildDashboardCard(
              title: 'Total Users',
              count: _totalUsers,
              icon: Icons.person,
              color: Colors.green.shade400,
              onTap: () {
                if (widget.onTileTap != null) {
                  widget.onTileTap!(2); // Manage Users index
                }
              },
            ),
            _buildDashboardCard(
              title: 'Total Plants',
              count: _totalPlants,
              icon: Icons.local_florist,
              color: Colors.teal.shade400,
              onTap: () {
                if (widget.onTileTap != null) {
                  widget.onTileTap!(1); // Manage Plants index
                }
              },
            ),
            _buildDashboardCard(
              title: 'Spotlight',
              count: _totalSpotlight,
              icon: Icons.psychology,
              color: Colors.orange.shade400,
              onTap: () {
                if (widget.onTileTap != null) {
                  widget.onTileTap!(3); // Manage Explore index, Spotlight tab
                }
              },
            ),
            _buildDashboardCard(
              title: 'Explore More',
              count: _totalExplore,
              icon: Icons.explore,
              color: Colors.blue.shade400,
              onTap: () {
                if (widget.onTileTap != null) {
                  widget.onTileTap!(4); // Manage Explore index, Explore tab
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: color.withAlpha(85),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: Colors.white),
              const SizedBox(height: 15),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 30,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
