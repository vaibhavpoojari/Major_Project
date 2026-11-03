import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/localization_service.dart';
import '../widgets/emergency_ui_components.dart';

class AccidentHistoryScreen extends StatefulWidget {
  const AccidentHistoryScreen({super.key});

  @override
  State<AccidentHistoryScreen> createState() => _AccidentHistoryScreenState();
}

class _AccidentHistoryScreenState extends State<AccidentHistoryScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _allReports = [];
  String _selectedFilter = 'All'; // 'All', 'Dispatched', 'Cancelled', 'Failed'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final reports = await _dbService.getCrashReports();
      if (mounted) {
        setState(() {
          _allReports = reports;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredReports {
    if (_selectedFilter == 'All') return _allReports;
    if (_selectedFilter == 'Dispatched') {
      return _allReports.where((r) =>
          (r['alertStatus'] == 'Dispatched' || r['status'] == 'Dispatched' || r['status'] == 'Pending') &&
          r['isCancelled'] != true).toList();
    }
    if (_selectedFilter == 'Cancelled') {
      return _allReports.where((r) => r['isCancelled'] == true || r['status'] == 'Cancelled').toList();
    }
    if (_selectedFilter == 'Failed') {
      return _allReports.where((r) =>
          r['smsStatus'] == 'Failed' ||
          (r['smsStatus'] ?? '').toString().toLowerCase().contains('failed')).toList();
    }
    return _allReports;
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'clear_history'.tr,
            style: const TextStyle(fontFamily: 'Outfit', color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'clear_history_confirm'.tr,
            style: const TextStyle(fontFamily: 'Inter', color: Color(0xFFCBD5E1), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('cancel'.tr, style: const TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await _dbService.clearCrashReports();
                _loadHistory();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Accident event logs cleared successfully."),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              },
              child: Text('clear'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showReportDetails(Map<String, dynamic> report) {
    final String crashType = report['crashType'] ?? 'Unknown Crash';
    final String time = report['incidentTime'] ?? report['timestamp'] ?? 'Recent';
    final dynamic force = report['maxAcceleration'] ?? 35.0;
    final String forceStr = force is num ? "${force.toStringAsFixed(1)} m/s²" : "$force m/s²";
    final double? lat = report['latitude'] is num ? (report['latitude'] as num).toDouble() : null;
    final double? lng = report['longitude'] is num ? (report['longitude'] as num).toDouble() : null;
    final String gpsStr = (lat != null && lng != null) ? "$lat, $lng" : "Unavailable";
    final String mapUrl = report['googleMapsUrl'] ?? (lat != null && lng != null ? "https://maps.google.com/?q=$lat,$lng" : "Unavailable");
    final String smsStatus = report['smsStatus'] ?? report['status'] ?? 'Unknown';
    final String hospName = report['nearestHospital'] ?? 'Hospital lookup unavailable';
    final String hospDist = report['hospitalDistance'] ?? 'N/A';
    final String hospPhone = report['hospitalPhone'] ?? 'Unavailable';
    final String hospStatus = report['hospitalStatus'] ?? 'Notified';
    final List<dynamic> smsDispatchResults = report['smsDispatchResults'] is List ? report['smsDispatchResults'] as List : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          crashType,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          forceStr,
                          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Color(0xFFFB7185)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(
                        time,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const Divider(height: 28, color: Color(0xFF26334D)),

                  // GPS Location Details
                  const SectionHeader(title: "Location Telematics", subtitle: "Victim accident coordinates & map link"),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF26334D)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 8),
                            Text(
                              "GPS: $gpsStr",
                              style: const TextStyle(fontFamily: 'Courier', fontSize: 13, color: Colors.white),
                            ),
                          ],
                        ),
                        if (report['locationAccuracy'] != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            "Accuracy: ${report['locationAccuracy']}",
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFF94A3B8)),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          mapUrl,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF38BDF8)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Hospital Notification Details
                  const SectionHeader(title: "Hospital Dispatch", subtitle: "Nearest emergency healthcare facility"),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF26334D)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hospName,
                          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text("Distance: $hospDist", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF94A3B8))),
                            const Spacer(),
                            Text("Status: $hospStatus", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF10B981))),
                          ],
                        ),
                        if (hospPhone.isNotEmpty && hospPhone != 'Unavailable') ...[
                          const SizedBox(height: 4),
                          Text("Phone: $hospPhone", style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFFCBD5E1))),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SMS Delivery Logs & Retries
                  const SectionHeader(title: "SMS Delivery & Retry Logs", subtitle: "Gateway submission & recipient confirmation"),
                  if (smsDispatchResults.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF26334D)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mark_email_read_outlined, size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Text(
                            "Status: $smsStatus",
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.white),
                          ),
                        ],
                      ),
                    )
                  else
                    ...smsDispatchResults.map((r) {
                      final item = r is Map ? r : {};
                      final String rec = item['maskedRecipient'] ?? item['recipient'] ?? 'Recipient';
                      final String stat = item['statusDisplay'] ?? item['status'] ?? 'Sent';
                      final String method = item['method'] ?? 'SMS';
                      final int retries = item['retryAttempts'] ?? 0;
                      final List<dynamic> logs = item['attemptLogs'] is List ? item['attemptLogs'] as List : [];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF26334D)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  rec,
                                  style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (stat.toLowerCase().contains('failed')
                                            ? const Color(0xFFE11D48)
                                            : const Color(0xFF10B981))
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    stat,
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: stat.toLowerCase().contains('failed')
                                          ? const Color(0xFFFB7185)
                                          : const Color(0xFF34D399),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Method: $method | Retries: $retries",
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFF94A3B8)),
                            ),
                            if (logs.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ...logs.map((att) {
                                final logItem = att is Map ? att : {};
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Text(
                                    "  • Attempt #${logItem['attempt'] ?? 1}: ${logItem['statusDisplay'] ?? logItem['status']} (${logItem['elapsedMs'] ?? 0}ms)",
                                    style: const TextStyle(fontFamily: 'Courier', fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocalization.languageNotifier,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF0B0F19),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'accident_history'.tr,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            actions: [
              if (_allReports.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFFB7185), size: 24),
                  tooltip: 'clear_history'.tr,
                  onPressed: _confirmClearHistory,
                ),
            ],
          ),
          body: Column(
            children: [
              // Filter Chips
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFF0F172A),
                child: Row(
                  children: [
                    _buildFilterChip('All', 'filter_all'.tr),
                    const SizedBox(width: 8),
                    _buildFilterChip('Dispatched', 'filter_dispatched'.tr),
                    const SizedBox(width: 8),
                    _buildFilterChip('Cancelled', 'filter_cancelled'.tr),
                    const SizedBox(width: 8),
                    _buildFilterChip('Failed', 'filter_failed'.tr),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48)))
                    : _filteredReports.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                                      border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.3)),
                                    ),
                                    child: const Icon(Icons.history_outlined, size: 40, color: Color(0xFFFB7185)),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    'no_history'.tr,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredReports.length,
                            itemBuilder: (context, index) {
                              final report = _filteredReports[index];
                              final String crashType = report['crashType'] ?? 'Accident Event';
                              final String time = report['incidentTime'] ?? report['timestamp'] ?? 'Recent';
                              final dynamic force = report['maxAcceleration'] ?? 35.0;
                              final String forceStr = force is num ? "${force.toStringAsFixed(1)} m/s²" : "$force m/s²";
                              final String smsStatus = report['smsStatus'] ?? report['status'] ?? 'Dispatched';
                              final bool isCancelled = report['isCancelled'] == true;

                              Color badgeColor = const Color(0xFF10B981);
                              if (isCancelled) {
                                badgeColor = const Color(0xFFF59E0B);
                              } else if (smsStatus.toLowerCase().contains('failed')) {
                                badgeColor = const Color(0xFFE11D48);
                              }

                              return InteractivePressable(
                                onTap: () => _showReportDetails(report),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF161E2E),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFF26334D)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.18),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: badgeColor.withValues(alpha: 0.15),
                                              border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                                            ),
                                            child: Icon(
                                              isCancelled ? Icons.verified_user_outlined : Icons.car_crash_rounded,
                                              color: badgeColor,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  crashType,
                                                  style: const TextStyle(
                                                    fontFamily: 'Outfit',
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  time,
                                                  style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 11.5,
                                                    color: Color(0xFF94A3B8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: badgeColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              isCancelled ? 'Safe' : smsStatus,
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: badgeColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 22, color: Color(0xFF26334D)),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.speed, size: 14, color: Color(0xFF38BDF8)),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Force: $forceStr",
                                                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.white70),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                'details'.tr,
                                                style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.arrow_forward_ios, size: 11, color: Color(0xFF38BDF8)),
                                            ],
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
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final bool isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE11D48) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFE11D48) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
