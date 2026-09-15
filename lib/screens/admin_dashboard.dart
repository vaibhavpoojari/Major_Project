import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../widgets/emergency_ui_components.dart';
import 'login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  late TabController _tabController;

  List<Map<String, dynamic>> _crashes = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _hospitals = [];
  List<Map<String, dynamic>> _engineStates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final crashesData = await _dbService.getCrashReports();
      final driversData = await _dbService.getDrivers();
      final hospitalsData = await _dbService.getHospitals();
      final engineStatesData = await _dbService.getEngineStates();

      setState(() {
        _crashes = crashesData;
        _drivers = driversData;
        _hospitals = hospitalsData;
        _engineStates = engineStatesData;
        _isLoading = false;
      });
    } catch (e) {
      print("AdminDashboard: Fetch error: $e");
      setState(() => _isLoading = false);
    }
  }

  void _logout() {
    _dbService.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _updateStatus(String reportId, String status) async {
    await _dbService.updateCrashReportStatus(reportId, status);
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_outlined, size: 22, color: Color(0xFFE11D48)),
            SizedBox(width: 10),
            Text("Admin Command Console"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
            tooltip: "Refresh Data",
            onPressed: _fetchData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF94A3B8)),
            tooltip: "Logout",
            onPressed: _logout,
          )
        ],
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B0F19), Color(0xFF111827), Color(0xFF161E2E)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48)))
              : Column(
                  children: [
                    // Top Stat Metrics Row
                    FadeSlideTransition(
                      duration: const Duration(milliseconds: 320),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                title: "Incidents",
                                count: _crashes.length,
                                icon: Icons.warning_amber_rounded,
                                color: const Color(0xFFE11D48),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                title: "Drivers",
                                count: _drivers.length,
                                icon: Icons.drive_eta_outlined,
                                color: const Color(0xFF38BDF8),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                title: "Hospitals",
                                count: _hospitals.length,
                                icon: Icons.local_hospital_outlined,
                                color: const Color(0xFF34D399),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Modern Tab Switcher
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 70),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF26334D)),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: Colors.white,
                          unselectedLabelColor: const Color(0xFF94A3B8),
                          labelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 11.5),
                          unselectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 11.5),
                          tabs: const [
                            Tab(text: "Incidents"),
                            Tab(text: "Live Engines"),
                            Tab(text: "Drivers"),
                            Tab(text: "Hospitals"),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tab Views
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAccidentsTab(),
                          _buildLiveMonitorTab(),
                          _buildDriversTab(),
                          _buildHospitalsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161E2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF26334D)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<int>(
            duration: const Duration(milliseconds: 500),
            tween: IntTween(begin: 0, end: count),
            builder: (context, val, child) {
              return Text(
                val.toString(),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccidentsTab() {
    if (_crashes.isEmpty) {
      return const Center(
        child: Text("No crash telemetry reports recorded.", style: TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _crashes.length,
      itemBuilder: (context, index) {
        final crash = _crashes[index];
        final bool isPending = crash['status'] == 'Pending';

        return FadeSlideTransition(
          delay: Duration(milliseconds: index * 50),
          duration: const Duration(milliseconds: 280),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF161E2E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isPending ? const Color(0xFFE11D48).withValues(alpha: 0.4) : const Color(0xFF26334D),
              ),
              boxShadow: [
                BoxShadow(
                  color: isPending ? const Color(0xFFE11D48).withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        crash['driverName'] ?? 'Unknown Driver',
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    StatusBadge(
                      label: crash['status'] ?? 'Pending',
                      type: isPending ? BadgeStatusType.critical : BadgeStatusType.active,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "${crash['crashType'] ?? 'Crash'} • Blood Group: ${crash['bloodGroup'] ?? 'O+'}",
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFFCBD5E1)),
                ),
                const SizedBox(height: 4),
                Text(
                  "GPS: ${crash['latitude']}, ${crash['longitude']}",
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                if (isPending) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InteractivePressable(
                      onTap: () => _updateStatus(crash['id'], 'Resolved'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF38BDF8)),
                            SizedBox(width: 6),
                            Text(
                              "Mark Resolved",
                              style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDriversTab() {
    if (_drivers.isEmpty) {
      return const Center(
        child: Text("No drivers registered.", style: TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _drivers.length,
      itemBuilder: (context, index) {
        final driver = _drivers[index];
        return FadeSlideTransition(
          delay: Duration(milliseconds: index * 50),
          duration: const Duration(milliseconds: 280),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF161E2E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF26334D)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                  ),
                  child: const Center(
                    child: Icon(Icons.drive_eta, color: Color(0xFF38BDF8), size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver['fullName'] ?? 'Driver Name',
                        style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Email: ${driver['email']}",
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                      Text(
                        "Parent Phone: ${driver['parentPhone']}",
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: driver['bloodGroup'] ?? 'O+',
                  type: BadgeStatusType.info,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHospitalsTab() {
    if (_hospitals.isEmpty) {
      return const Center(
        child: Text("No hospitals registered.", style: TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _hospitals.length,
      itemBuilder: (context, index) {
        final hosp = _hospitals[index];
        return FadeSlideTransition(
          delay: Duration(milliseconds: index * 50),
          duration: const Duration(milliseconds: 280),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF161E2E),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF26334D)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D399).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.3)),
                  ),
                  child: const Center(
                    child: Icon(Icons.local_hospital, color: Color(0xFF34D399), size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hosp['facilityName'] ?? 'Hospital Name',
                        style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Hotline: ${hosp['dispatchPhone']}",
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                      Text(
                        "GPS: ${hosp['latitude']}, ${hosp['longitude']}",
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                const StatusBadge(
                  label: "Connected",
                  type: BadgeStatusType.active,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveMonitorTab() {
    final activeEngines = _engineStates.where((state) => state['isEngineActive'] == true).toList();
    final inactiveEngines = _engineStates.where((state) => state['isEngineActive'] == false).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const EmergencyPulseIndicator(size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    "Active Monitoring: ${activeEngines.length}",
                    style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Color(0xFF34D399)),
                  ),
                ],
              ),
              Text(
                "Inactive: ${inactiveEngines.length}",
                style: const TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: _engineStates.isEmpty
              ? const Center(
                  child: Text("No live engine monitoring logs found.", style: TextStyle(fontFamily: 'Inter', color: Color(0xFF94A3B8))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  itemCount: _engineStates.length,
                  itemBuilder: (context, index) {
                    final state = _engineStates[index];
                    final bool isActive = state['isEngineActive'] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161E2E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.35) : const Color(0xFF26334D),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.sensors,
                            color: isActive ? const Color(0xFF34D399) : const Color(0xFF64748B),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state['driverName'] ?? 'Unknown Driver',
                                  style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Last GPS: ${state['latitude']}, ${state['longitude']}",
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            label: isActive ? "Engine Active" : "Standby",
                            type: isActive ? BadgeStatusType.active : BadgeStatusType.neutral,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
