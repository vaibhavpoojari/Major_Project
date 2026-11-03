import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing offline emergency incident persistence and automatic retry queues.
/// Ensures that accident events occurring without internet or cellular connectivity are safely
/// retained on device storage and dispatched once connectivity returns.
class OfflineEventQueueService {
  static const String _prefQueueKey = 'accident_guard_pending_events';
  static final OfflineEventQueueService instance = OfflineEventQueueService._internal();

  OfflineEventQueueService._internal();

  factory OfflineEventQueueService() => instance;

  List<Map<String, dynamic>> _queue = [];
  bool _isProcessing = false;

  List<Map<String, dynamic>> get queue => List.unmodifiable(_queue);
  int get pendingCount => _queue.where((e) => e['status'] != 'completed').length;
  bool get isProcessing => _isProcessing;

  Future<int> getPendingCount() async {
    await init();
    return pendingCount;
  }

  Future<List<Map<String, dynamic>>> getPendingEvents() async {
    await init();
    return _queue.where((e) => e['status'] != 'completed').toList();
  }

  Future<void> removeEvent(String eventId) async {
    await init();
    _queue.removeWhere((e) => e['eventId'] == eventId);
    await _persistQueue();
  }

  /// Initialize the queue from persistent storage
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefQueueKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        _queue = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      // Graceful fallback if queue fails to parse
      _queue = [];
    }
  }

  /// Persist the current queue to local SharedPreferences
  Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefQueueKey, jsonEncode(_queue));
    } catch (_) {}
  }

  /// Enqueue an emergency incident for background retry
  Future<void> enqueueEvent({
    required String eventId,
    required String driverEmail,
    required String driverName,
    required String crashType,
    required double latitude,
    required double longitude,
    required double accuracy,
    required bool isStaleLocation,
    required List<String> recipients,
    required bool needsSmsRetry,
    required bool needsEmailRetry,
    required bool needsFirestoreSync,
    String? medicalNotes,
  }) async {
    // Prevent duplicate entries for the same event
    final existingIndex = _queue.indexWhere((e) => e['eventId'] == eventId);
    final eventPayload = {
      'eventId': eventId,
      'driverEmail': driverEmail,
      'driverName': driverName,
      'crashType': crashType,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'isStaleLocation': isStaleLocation,
      'recipients': recipients,
      'needsSmsRetry': needsSmsRetry,
      'needsEmailRetry': needsEmailRetry,
      'needsFirestoreSync': needsFirestoreSync,
      'medicalNotes': medicalNotes ?? '',
      'createdAt': DateTime.now().toIso8601String(),
      'retryAttempts': 0,
      'status': 'queued', // 'queued', 'retrying', 'completed', 'failed'
      'lastAttempt': null,
    };

    if (existingIndex >= 0) {
      _queue[existingIndex] = eventPayload;
    } else {
      _queue.insert(0, eventPayload);
    }

    await _persistQueue();
  }

  /// Mark an event as completed without deleting from local audit
  Future<void> markCompleted(String eventId) async {
    final index = _queue.indexWhere((e) => e['eventId'] == eventId);
    if (index >= 0) {
      _queue[index]['status'] = 'completed';
      _queue[index]['completedAt'] = DateTime.now().toIso8601String();
      await _persistQueue();
    }
  }

  /// Clear all pending events
  Future<void> clearQueue() async {
    _queue.clear();
    await _persistQueue();
  }

  /// Process pending retries based on current network and cellular availability
  Future<Map<String, dynamic>> processQueue({
    required Future<bool> Function(String phone, String message) sendSmsCallback,
    required Future<bool> Function(Map<String, dynamic> event) sendEmailCallback,
    required Future<bool> Function(Map<String, dynamic> event) syncFirestoreCallback,
    required bool isCellularAvailable,
    required bool isInternetAvailable,
  }) async {
    if (_isProcessing) {
      return {'status': 'already_processing', 'processed': 0};
    }
    _isProcessing = true;

    int processedCount = 0;
    int successCount = 0;

    try {
      final pendingEvents = _queue.where((e) => e['status'] == 'queued' || e['status'] == 'retrying').toList();

      for (var event in pendingEvents) {
        processedCount++;
        event['status'] = 'retrying';
        event['retryAttempts'] = (event['retryAttempts'] as int? ?? 0) + 1;
        event['lastAttempt'] = DateTime.now().toIso8601String();

        bool smsDone = !(event['needsSmsRetry'] == true);
        bool emailDone = !(event['needsEmailRetry'] == true);
        bool firestoreDone = !(event['needsFirestoreSync'] == true);

        // 1. Retry SMS if cellular is available
        if (!smsDone && isCellularAvailable) {
          final recipients = List<String>.from(event['recipients'] ?? []);
          final mapsLink = "https://maps.google.com/?q=${event['latitude']},${event['longitude']}";
          final timeStr = event['createdAt'] ?? DateTime.now().toString();
          final message = "EMERGENCY RETRY ALERT!\n"
              "Accident: ${event['crashType']}\n"
              "Location: $mapsLink (±${(event['accuracy'] as num?)?.toStringAsFixed(1) ?? '10'}m)\n"
              "Time: $timeStr\n"
              "Status: Offline Incident Dispatched on Network Recovery.";

          bool allRecipientsSucceeded = true;
          for (final phone in recipients) {
            try {
              final ok = await sendSmsCallback(phone, message);
              if (!ok) allRecipientsSucceeded = false;
            } catch (_) {
              allRecipientsSucceeded = false;
            }
          }
          if (allRecipientsSucceeded) {
            event['needsSmsRetry'] = false;
            smsDone = true;
          }
        }

        // 2. Retry Email and Firestore if internet is available
        if (isInternetAvailable) {
          if (!emailDone) {
            try {
              final emailOk = await sendEmailCallback(event);
              if (emailOk) {
                event['needsEmailRetry'] = false;
                emailDone = true;
              }
            } catch (_) {}
          }

          if (!firestoreDone) {
            try {
              final firestoreOk = await syncFirestoreCallback(event);
              if (firestoreOk) {
                event['needsFirestoreSync'] = false;
                firestoreDone = true;
              }
            } catch (_) {}
          }
        }

        if (smsDone && emailDone && firestoreDone) {
          event['status'] = 'completed';
          successCount++;
        }
      }

      await _persistQueue();
    } finally {
      _isProcessing = false;
    }

    return {
      'status': 'completed',
      'processed': processedCount,
      'succeeded': successCount,
      'remaining': pendingCount,
    };
  }
}
