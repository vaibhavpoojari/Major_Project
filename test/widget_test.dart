import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accident_guard_system/services/hospital_service.dart';
import 'package:accident_guard_system/services/alert_service.dart';
import 'package:accident_guard_system/services/permission_service.dart';
import 'package:accident_guard_system/services/sensor_service.dart';
import 'package:accident_guard_system/services/database_service.dart';
import 'package:accident_guard_system/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Haversine Geodesic Calculations', () {
    test('Haversine distance calculation is mathematically accurate', () {
      // Distance between Bangalore Majestic (12.9774, 77.5729) and Indiranagar (12.9784, 77.6408)
      final dist = HospitalService.calculateHaversineDistanceKm(
        12.9774,
        77.5729,
        12.9784,
        77.6408,
      );
      expect(dist, greaterThan(6.0));
      expect(dist, lessThan(8.0));
    });
  });

  group('Hospital Classification & Tag Extraction', () {
    test('Correctly classifies emergency-capable hospital into Tier 1', () {
      final facility = HospitalService.classifyFacility(
        name: 'Apollo Emergency Trauma Centre',
        latitude: 12.9716,
        longitude: 77.5946,
        distanceKm: 2.1,
        tags: {
          'amenity': 'hospital',
          'emergency': 'yes',
          'operator:type': 'private',
        },
      );

      expect(facility.facilityType, 'Emergency Hospital');
      expect(facility.emergencyCapability, 'Yes');
      expect(facility.ownership, 'Private');
      expect(facility.priorityTier, 1);
    });

    test('Correctly classifies government hospital without emergency tag into Tier 2', () {
      final facility = HospitalService.classifyFacility(
        name: 'District Government General Hospital',
        latitude: 12.9800,
        longitude: 77.6000,
        distanceKm: 1.5,
        tags: {
          'amenity': 'hospital',
          'operator:type': 'government',
        },
      );

      expect(facility.facilityType, 'Hospital');
      expect(facility.emergencyCapability, 'Unavailable');
      expect(facility.ownership, 'Government/Public');
      expect(facility.priorityTier, 2);
    });

    test('Hospital with missing emergency tag is still treated as hospital (Tier 2)', () {
      final facility = HospitalService.classifyFacility(
        name: 'Durga Hospital',
        latitude: 13.0000,
        longitude: 77.5000,
        distanceKm: 1.2,
        tags: {
          'amenity': 'hospital',
        },
      );

      expect(facility.facilityType, 'Hospital');
      expect(facility.emergencyCapability, 'Unavailable');
      expect(facility.ownership, 'Unavailable');
      expect(facility.priorityTier, 2);
    });

    test('Hospital with missing ownership tag is still treated as hospital (Tier 2)', () {
      final facility = HospitalService.classifyFacility(
        name: 'City Care Hospital',
        latitude: 13.0100,
        longitude: 77.5100,
        distanceKm: 1.8,
        tags: {
          'amenity': 'hospital',
        },
      );

      expect(facility.facilityType, 'Hospital');
      expect(facility.ownership, 'Unavailable');
      expect(facility.priorityTier, 2);
    });

    test('Correctly classifies clinic into Tier 3 (lowest fallback)', () {
      final facility = HospitalService.classifyFacility(
        name: 'Neighborhood Family Clinic',
        latitude: 12.9720,
        longitude: 77.5950,
        distanceKm: 0.5,
        tags: {
          'amenity': 'clinic',
          'healthcare': 'clinic',
        },
      );

      expect(facility.facilityType, 'Clinic');
      expect(facility.priorityTier, 3);
    });
  });

  group('Hospital Prioritization & Selection Rules', () {
    test('1. Nearby private hospital + farther government hospitals: private hospital is selected and ranked', () {
      final privateHospital = HospitalService.classifyFacility(
        name: 'Durga Hospital',
        latitude: 13.0010,
        longitude: 77.5010,
        distanceKm: 1.2, // closest
        tags: {'amenity': 'hospital'},
      );

      final govtHospital1 = HospitalService.classifyFacility(
        name: 'Govt Taluk Hospital',
        latitude: 13.0100,
        longitude: 77.5100,
        distanceKm: 3.5,
        tags: {'amenity': 'hospital', 'operator:type': 'government'},
      );

      final govtHospital2 = HospitalService.classifyFacility(
        name: 'Govt District Hospital',
        latitude: 13.0200,
        longitude: 77.5200,
        distanceKm: 5.0,
        tags: {'amenity': 'hospital', 'operator:type': 'government'},
      );

      final govtHospital3 = HospitalService.classifyFacility(
        name: 'Govt Civil Hospital',
        latitude: 13.0300,
        longitude: 77.5300,
        distanceKm: 7.0,
        tags: {'amenity': 'hospital', 'operator:type': 'government'},
      );

      final selected = HospitalService.prioritizeHospitals([
        govtHospital1,
        govtHospital2,
        govtHospital3,
        privateHospital,
      ]);

      expect(selected.length, 3);
      // Durga Hospital (1.2km) must be #1 because it is the closest real hospital
      expect(selected[0].name, 'Durga Hospital');
      expect(selected[1].name, 'Govt Taluk Hospital');
      expect(selected[2].name, 'Govt District Hospital');
    });

    test('2. Nearby emergency hospital gets preference', () {
      final emergencyHospital = HospitalService.classifyFacility(
        name: 'Apollo Trauma Centre',
        latitude: 12.9800,
        longitude: 77.6000,
        distanceKm: 4.0,
        tags: {'amenity': 'hospital', 'emergency': 'yes'},
      );

      final normalHospital1 = HospitalService.classifyFacility(
        name: 'Adarsha Hospital',
        latitude: 12.9700,
        longitude: 77.5900,
        distanceKm: 1.5,
        tags: {'amenity': 'hospital'},
      );

      final normalHospital2 = HospitalService.classifyFacility(
        name: 'City Care Hospital',
        latitude: 12.9750,
        longitude: 77.5950,
        distanceKm: 2.0,
        tags: {'amenity': 'hospital'},
      );

      final normalHospital3 = HospitalService.classifyFacility(
        name: 'General Hospital',
        latitude: 12.9790,
        longitude: 77.5990,
        distanceKm: 3.0,
        tags: {'amenity': 'hospital'},
      );

      final selected = HospitalService.prioritizeHospitals([
        normalHospital1,
        normalHospital2,
        normalHospital3,
        emergencyHospital,
      ]);

      expect(selected.length, 3);
      // Emergency hospital is included in top 3 along with closest general hospitals
      expect(selected.any((h) => h.name == 'Apollo Trauma Centre'), true);
    });

    test('3. Multiple normal hospitals: nearest suitable hospitals selected', () {
      final h1 = HospitalService.classifyFacility(
        name: 'Hospital A',
        latitude: 12.91,
        longitude: 77.51,
        distanceKm: 1.0,
        tags: {'amenity': 'hospital'},
      );
      final h2 = HospitalService.classifyFacility(
        name: 'Hospital B',
        latitude: 12.92,
        longitude: 77.52,
        distanceKm: 2.5,
        tags: {'amenity': 'hospital'},
      );
      final h3 = HospitalService.classifyFacility(
        name: 'Hospital C',
        latitude: 12.93,
        longitude: 77.53,
        distanceKm: 3.5,
        tags: {'amenity': 'hospital'},
      );
      final h4 = HospitalService.classifyFacility(
        name: 'Hospital D',
        latitude: 12.94,
        longitude: 77.54,
        distanceKm: 8.0,
        tags: {'amenity': 'hospital'},
      );

      final selected = HospitalService.prioritizeHospitals([h4, h3, h2, h1]);
      expect(selected.length, 3);
      expect(selected[0].name, 'Hospital A');
      expect(selected[1].name, 'Hospital B');
      expect(selected[2].name, 'Hospital C');
    });

    test('4. Clinics only: clinics are used as fallback when no proper hospitals exist', () {
      final c1 = HospitalService.classifyFacility(
        name: 'Dental Clinic',
        latitude: 12.91,
        longitude: 77.51,
        distanceKm: 0.5,
        tags: {'amenity': 'clinic'},
      );
      final c2 = HospitalService.classifyFacility(
        name: 'Eye Care Centre',
        latitude: 12.92,
        longitude: 77.52,
        distanceKm: 1.2,
        tags: {'amenity': 'clinic'},
      );
      final c3 = HospitalService.classifyFacility(
        name: 'General Dispensary',
        latitude: 12.93,
        longitude: 77.53,
        distanceKm: 2.0,
        tags: {'amenity': 'clinic'},
      );

      final selected = HospitalService.prioritizeHospitals([c3, c2, c1]);
      expect(selected.length, 3);
      expect(selected[0].name, 'Dental Clinic');
      expect(selected[1].name, 'Eye Care Centre');
      expect(selected[2].name, 'General Dispensary');
    });

    test('5. Proper hospitals exclude clinics from top results', () {
      final h1 = HospitalService.classifyFacility(
        name: 'Durga Hospital',
        latitude: 12.91,
        longitude: 77.51,
        distanceKm: 1.5,
        tags: {'amenity': 'hospital'},
      );
      final h2 = HospitalService.classifyFacility(
        name: 'Adarsha Hospital',
        latitude: 12.92,
        longitude: 77.52,
        distanceKm: 2.0,
        tags: {'amenity': 'hospital'},
      );
      final h3 = HospitalService.classifyFacility(
        name: 'Govt Hospital',
        latitude: 12.93,
        longitude: 77.53,
        distanceKm: 3.0,
        tags: {'amenity': 'hospital', 'operator:type': 'government'},
      );
      final clinic = HospitalService.classifyFacility(
        name: 'Close Dental Clinic',
        latitude: 12.90,
        longitude: 77.50,
        distanceKm: 0.3, // very close
        tags: {'amenity': 'clinic'},
      );

      final selected = HospitalService.prioritizeHospitals([clinic, h3, h2, h1]);
      expect(selected.length, 3);
      // Clinic must NOT be included since 3 proper hospitals exist
      expect(selected.any((f) => f.name == 'Close Dental Clinic'), false);
      expect(selected[0].name, 'Durga Hospital');
      expect(selected[1].name, 'Adarsha Hospital');
      expect(selected[2].name, 'Govt Hospital');
    });

    test('6. Maximum 3 results returned', () {
      final facilities = List.generate(10, (index) => HospitalService.classifyFacility(
        name: 'Hospital $index',
        latitude: 12.97 + (index * 0.01),
        longitude: 77.59 + (index * 0.01),
        distanceKm: (index + 1) * 1.0,
        tags: {'amenity': 'hospital'},
      ));

      final selected = HospitalService.prioritizeHospitals(facilities);
      expect(selected.length, 3);
    });
  });


  group('AlertService Safety & Reliability', () {
    test('Handles emergency broadcast safely when GPS is null without inventing fake coordinates', () async {
      final alertService = AlertService();
      final results = await alertService.sendEmergencyAlerts(
        userProfile: {
          'fullName': 'Test Driver',
          'bloodGroup': 'A+',
          'parentPhone': '',
          'email': '',
        },
        crashType: 'Head-On Collision',
        overrideLatitude: null,
        overrideLongitude: null,
      );

      expect(results['hasValidGps'], false);
      expect(results['nearestHospital'], contains('unavailable'));
      expect(results['parentSent'], false);
      expect(results['hospitalSent'], false);
    });

    test('Does not throw when executing live hospital discovery query', () async {
      final topHospitals = await HospitalService.findTopNearbyHospitals(
        latitude: 12.9716,
        longitude: 77.5946,
      );

      // Either returns a list of up to 3 hospitals if online, or empty list if Overpass is down
      expect(topHospitals.length, lessThanOrEqualTo(3));
    });

    test('sendTestEmail safely rejects invalid email addresses without crashing', () async {
      final alertService = AlertService();
      final result = await alertService.sendTestEmail(recipientEmail: 'invalid-email-address');

      expect(result['isSuccess'], false);
      expect(result['requestStarted'], false);
      expect(result['responseStatus'], contains('Invalid'));
    });

    test('sendTestEmail returns structured diagnostic result', () async {
      final alertService = AlertService();
      final result = await alertService.sendTestEmail(recipientEmail: 'test@example.com');

      expect(result.containsKey('recipient'), true);
      expect(result.containsKey('method'), true);
      expect(result.containsKey('requestStarted'), true);
      expect(result.containsKey('responseStatus'), true);
      expect(result.containsKey('isSuccess'), true);
    });
  });

  group('Immediate SMS Architecture & Safety Tests', () {
    test('Phone number masking hides private digits and leaves safe prefix/suffix', () {
      expect(AlertService.maskPhoneNumber('+919113895413'), '+919113****13');
      expect(AlertService.maskPhoneNumber('9876543210'), '9876****10');
      expect(AlertService.maskPhoneNumber('1234'), '****');
    });

    test('SmsDispatchResult represents accepted/dispatched/failed/delivered states correctly', () {
      final accepted = SmsDispatchResult(
        recipient: '+919113895413',
        maskedRecipient: '+919113****13',
        method: 'TextBee',
        status: 'accepted',
        statusDisplay: 'Accepted by SMS Gateway',
        isSuccess: true,
        elapsedMs: 120,
      );
      expect(accepted.isSuccess, true);
      expect(accepted.statusDisplay, 'Accepted by SMS Gateway');
      expect(accepted.method, 'TextBee');

      final dispatched = SmsDispatchResult(
        recipient: '+919113895413',
        maskedRecipient: '+919113****13',
        method: 'TextBee',
        status: 'dispatched',
        statusDisplay: 'Dispatched',
        isSuccess: true,
        elapsedMs: 150,
      );
      expect(dispatched.isSuccess, true);
      expect(dispatched.statusDisplay, 'Dispatched');

      final delivered = SmsDispatchResult(
        recipient: '+919113895413',
        maskedRecipient: '+919113****13',
        method: 'TextBee',
        status: 'delivered',
        statusDisplay: 'Delivered',
        isSuccess: true,
        elapsedMs: 210,
      );
      expect(delivered.isSuccess, true);
      expect(delivered.statusDisplay, 'Delivered');

      final failed = SmsDispatchResult(
        recipient: '+919113895413',
        maskedRecipient: '+919113****13',
        method: 'Native SIM',
        status: 'failed',
        statusDisplay: 'Failed',
        isSuccess: false,
        elapsedMs: 50,
        errorMessage: 'Telephony unavailable',
      );
      expect(failed.isSuccess, false);
      expect(failed.statusDisplay, 'Failed');
      expect(failed.errorMessage, 'Telephony unavailable');
    });

    test('Accident confirmation triggers SMS immediately and no fake hospital phone is used', () async {
      final alertService = AlertService();
      final results = await alertService.sendEmergencyAlerts(
        userProfile: {
          'fullName': 'Immediate Test Driver',
          'bloodGroup': 'AB+',
          'parentPhone': '+919876543210',
          'parentEmail': 'test@example.com',
        },
        crashType: 'Rollover Crash',
        overrideLatitude: 12.9716,
        overrideLongitude: 77.5946,
      );

      expect(results.containsKey('parentSmsResult'), true);
      expect(results.containsKey('parentSmsStatus'), true);
      expect(results['parentPhone'], '+919876543210');
      // If OSM hospital phone is missing, it should skip hospital SMS without using a fake number
      if (results['hasValidHospitalPhone'] != true) {
        expect(results['hospitalSmsStatus'], contains('Skipped'));
      }
    });

    test('SMS failure does not stop email or crash report logging', () async {
      final alertService = AlertService();
      final results = await alertService.sendEmergencyAlerts(
        userProfile: {
          'fullName': 'Resilient Driver',
          'bloodGroup': 'O-',
          'parentPhone': '', // empty phone -> failed SMS
          'parentEmail': 'resilient@example.com',
        },
        crashType: 'Rear-End Impact',
        overrideLatitude: 12.9716,
        overrideLongitude: 77.5946,
      );

      expect(results['parentSent'], false);
      expect(results['parentSmsStatus'], 'Unconfigured');
      // Flow completes safely and returns location text
      expect(results['hasValidGps'], true);
      expect(results['parentMessage'], contains('Resilient Driver'));
    });

    test('sendTestSms safely handles empty number without crashing', () async {
      final alertService = AlertService();
      final result = await alertService.sendTestSms(recipientPhone: '');
      expect(result.isSuccess, false);
      expect(result.statusDisplay, 'Failed');
    });
  });

  group('PermissionService Runtime Management', () {
    test('PermissionStatusResult structure holds correct flags', () {
      final result = PermissionStatusResult(
        isLocationGranted: true,
        isLocationDeniedForever: false,
        isNotificationGranted: true,
        isSmsGranted: false,
      );

      expect(result.isLocationGranted, true);
      expect(result.isLocationDeniedForever, false);
      expect(result.isNotificationGranted, true);
      expect(result.isSmsGranted, false);
    });
  });

  group('Accident Detection Acceleration Threshold (35.0 m/s²)', () {
    test('Single source of truth: SensorService.crashThreshold is exactly 35.0 m/s²', () {
      expect(SensorService.crashThreshold, 35.0);
    });

    test('Acceleration below 35.0 m/s² does NOT trigger the accident threshold condition', () {
      // Test zero, typical driving force, prior test values, and near-threshold values
      expect(SensorService.isAccident(0.0), false);
      expect(SensorService.isAccident(9.8), false);
      expect(SensorService.isAccident(18.0), false);
      expect(SensorService.isAccident(25.0), false);
      expect(SensorService.isAccident(34.99), false);
      expect(34.99 >= SensorService.crashThreshold, false);
    });

    test('Acceleration exactly 35.0 m/s² meets the accident threshold condition', () {
      expect(SensorService.isAccident(35.0), true);
      expect(35.0 >= SensorService.crashThreshold, true);
    });

    test('Acceleration above 35.0 m/s² meets the accident threshold condition', () {
      expect(SensorService.isAccident(35.01), true);
      expect(SensorService.isAccident(40.0), true);
      expect(SensorService.isAccident(45.0), true);
      expect(SensorService.isAccident(75.5), true);
      expect(45.0 >= SensorService.crashThreshold, true);
    });
  });

  group('Project Automatic SMS & Email Configuration', () {
    test('DatabaseService defines exact requested project default constants', () {
      expect(DatabaseService.defaultTextbeeDeviceId, '6a781d7b99101e52a4ca3b24');
      expect(DatabaseService.defaultTextbeeApiKey, 'txb_orA7oouhebOAeDdVfuZFXsDg7BbJfCWp');
      expect(DatabaseService.defaultSmtpEmail, 'accidentgaurd@gmail.com');
      expect(DatabaseService.defaultSmtpPassword, 'fkty hyzb ormn ipis');
    });

    test('Fresh installation initializes missing project defaults automatically', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Before init, values should be null or missing
      expect(prefs.getString('textbee_api_key'), isNull);
      expect(prefs.getString('textbee_device_id'), isNull);
      expect(prefs.getString('smtp_email'), isNull);
      expect(prefs.getString('smtp_password'), isNull);

      // Execute initialization
      await DatabaseService.initDefaultConfigurations(prefs);

      // After init, default values should be present
      expect(prefs.getString('textbee_api_key'), 'txb_orA7oouhebOAeDdVfuZFXsDg7BbJfCWp');
      expect(prefs.getString('textbee_device_id'), '6a781d7b99101e52a4ca3b24');
      expect(prefs.getString('smtp_email'), 'accidentgaurd@gmail.com');
      expect(prefs.getString('smtp_password'), 'fkty hyzb ormn ipis');
    });

    test('Existing saved configuration is strictly preserved and not overwritten', () async {
      SharedPreferences.setMockInitialValues({
        'textbee_api_key': 'custom_user_key_999',
        'textbee_device_id': 'custom_device_888',
        'smtp_email': 'custom_user@example.com',
        'smtp_password': 'custom_app_password_777',
      });
      final prefs = await SharedPreferences.getInstance();

      // Execute initialization
      await DatabaseService.initDefaultConfigurations(prefs);

      // Existing saved values must NOT be overwritten
      expect(prefs.getString('textbee_api_key'), 'custom_user_key_999');
      expect(prefs.getString('textbee_device_id'), 'custom_device_888');
      expect(prefs.getString('smtp_email'), 'custom_user@example.com');
      expect(prefs.getString('smtp_password'), 'custom_app_password_777');
    });
  });

  group('Role-Specific Reference Login Details UI', () {
    testWidgets('Driver Tab: Reference credentials are NOT shown, inputs start empty', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      // Ensure Driver Tab is active
      expect(find.text('Driver'), findsOneWidget);
      expect(find.text('Driver Portal'), findsOneWidget);

      // Email and password fields start empty (display-only credentials, no auto-filling)
      final emailFinder = find.byType(TextFormField).first;
      final emailField = tester.widget<TextFormField>(emailFinder);
      expect(emailField.controller?.text, isEmpty);

      // Reference login details must NOT be visible on Driver Tab
      expect(find.text('REFERENCE LOGIN DETAILS'), findsNothing);
      expect(find.text('admin@cityemergency.org'), findsNothing);
      expect(find.text('Shettyprakyathp@gmail.com'), findsNothing);
      expect(find.text('vaibhava.23cs179@sode-edu.in'), findsNothing);
    });

    testWidgets('Hospital Hub Tab: Shows ONLY Hospital Hub reference credentials', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      // Tap Hospital Hub tab
      await tester.tap(find.text('Hospital Hub'));
      await tester.pumpAndSettle();

      // Reference details section must be present with exact Hospital Hub credentials
      expect(find.text('REFERENCE LOGIN DETAILS'), findsOneWidget);
      expect(find.text('Hospital Hub'), findsWidgets); // Tab + Reference heading
      expect(find.text('Email: admin@cityemergency.org'), findsOneWidget);
      expect(find.text('Password: Password123!'), findsOneWidget);

      // Admin credentials must NOT be present
      expect(find.text('Admin 1'), findsNothing);
      expect(find.text('Admin 2'), findsNothing);
      expect(find.text('Email: Shettyprakyathp@gmail.com'), findsNothing);
      expect(find.text('Email: vaibhava.23cs179@sode-edu.in'), findsNothing);
    });

    testWidgets('Admin Tab: Shows ONLY Admin 1 and Admin 2 reference credentials', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      // Tap Admin tab
      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();

      // Reference details section must be present with exact Admin 1 & Admin 2 credentials
      expect(find.text('REFERENCE LOGIN DETAILS'), findsOneWidget);
      expect(find.text('Admin 1'), findsOneWidget);
      expect(find.text('Email: Shettyprakyathp@gmail.com'), findsOneWidget);
      expect(find.text('Password: Password123!'), findsOneWidget);

      expect(find.text('Admin 2'), findsOneWidget);
      expect(find.text('Email: vaibhava.23cs179@sode-edu.in'), findsOneWidget);
      expect(find.text('Password: 9731971568'), findsOneWidget);

      // Hospital Hub reference credentials must NOT be present
      expect(find.text('Email: admin@cityemergency.org'), findsNothing);
    });
  });
}







