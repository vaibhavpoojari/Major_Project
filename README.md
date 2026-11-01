# 🛡️ Accident Guard

> **Smart Accident Detection and Emergency Alert System**

**Accident Guard** is a cross-platform Flutter application engineered for **Smart Accident Detection and Emergency Alert System**. It detects vehicular collisions using real-time accelerometer telemetry, activates a 30-second driver safety countdown with an audio buzzer, computes the nearest medical emergency facility via GPS, and autonomously dispatches multi-channel SOS alerts (Direct SIM SMS, TextBee SMS Gateway, and Email) with exact Google Maps coordinates and critical driver medical data.

---

## ✨ Key Features

- ⚡ **Real-Time Impact Telemetry**: Continuously tracks linear acceleration and G-force vectors using device sensors ($\ge 35.0\text{ m/s}^2$ trigger threshold).
- ⏱️ **Safety Countdown & False-Alarm Override**: Triggers a 30-second audio alarm allowing safe drivers to cancel accidental dispatches before alerts are transmitted.
- 🏥 **Nearest Hospital Geocoding**: Automatically calculates distance to registered trauma centers and emergency hubs using high-precision GPS.
- 📡 **Multi-Channel SOS Alerts**:
  - **Direct Device SIM SMS**: Hardware-level native SMS dispatch via Android platform channels.
  - **TextBee & Cloud SMS Gateways**: REST API-based fallback for instantaneous SMS delivery.
  - **SMTP Emergency Email**: Dispatches structured email notifications to emergency contacts.
  - **Google Maps Integration**: Direct routing link sent to responders for zero-delay navigation.
- 👥 **Multi-Role Portals**:
  - **🚗 Driver Portal**: Live sensor telemetry, manual emergency SOS trigger, engine killswitch status, and profile management.
  - **🏥 Hospital Hub**: Live feed of incoming crash dispatches, patient blood group, contact details, and route navigation.
  - **🛡️ Admin Console**: Complete system-wide overview of active drivers, registered hospitals, crash history, and engine state diagnostics.
- 🔄 **Hybrid Online / Offline Architecture**: Seamless Cloud Firestore integration with automatic local fallback using `shared_preferences`.

---

## 🛠️ Tech Stack

| Component | Technology |
|---|---|
| **Framework** | Flutter (Dart 3.x) |
| **State & UI** | Material 3, Custom Glassmorphic Dark UI |
| **Telemetry & Sensors** | `sensors_plus`, `geolocator` |
| **Backend & Cloud** | Google Firebase (Auth & Firestore) + Local Storage Fallback |
| **Alert Protocols** | Android Native Method Channels (SMS), TextBee API, Mailer (SMTP) |
| **Audio Alert** | `flutter_ringtone_player` / Web Audio API |

---

## 📂 Project Structure

```text
accident-guard/
├── android/                   # Native Android host app & MethodChannels
├── ios/                       # iOS configuration
├── web/                       # Web platform support
├── assets/                    # Static assets & icons
└── lib/
    ├── main.dart              # App entry point & theme configuration
    ├── screens/
    │   ├── login_screen.dart          # Multi-role authentication portal
    │   ├── user_registration.dart     # Driver registration & emergency contacts
    │   ├── hospital_registration.dart # Hospital facility registration
    │   ├── control_panel.dart         # Driver hub & alert settings
    │   ├── sensor_monitoring.dart     # Real-time G-force telemetry & crash detector
    │   ├── hospital_dashboard.dart    # Hospital dispatch monitoring
    │   └── admin_dashboard.dart       # Administrator system management
    ├── services/
    │   ├── alert_service.dart         # Multi-channel SMS & Email dispatch logic
    │   ├── database_service.dart      # Hybrid Firestore & offline persistence
    │   ├── hospital_service.dart      # Nearest hospital distance calculations
    │   ├── sensor_service.dart        # Accelerometer stream management
    │   ├── buzzer_service.dart        # Platform-adaptive audio alert service
    │   └── permission_service.dart    # Location, SMS, and sensor permissions
    └── widgets/
        └── emergency_ui_components.dart # Reusable UI cards, buttons, badges
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.12.2` or later)
- [Android Studio](https://developer.android.com/studio) or VS Code with Flutter extension
- Connected Android/iOS device or Chrome browser

### Installation & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/accident-guard.git
   cd accident-guard
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   ```bash
   # Run in Chrome
   flutter run -d chrome

   # Run on connected Android device
   flutter run -d android

   # Run as a local web server
   flutter run -d web-server --web-port=8080 --web-hostname=127.0.0.1
   ```

---

## 🔑 Demo & Test Accounts

You can test all roles immediately without setting up external backends:

| Role | Email | Password |
|---|---|---|
| **Driver** | `driver@guard.com` *(or register new)* | `Password123!` |
| **Hospital Hub** | `admin@cityemergency.org` | `Password123!` |
| **Administrator** | `shettyprakyathp@gmail.com` | `Password123!` |
| **Administrator (Alt)** | `vaibhava.23cs179@sode-edu.in` | `9731971568` |

---

## ⚙️ Configuration

### SMS Gateway (TextBee / Twilio / SIM)
1. Log in to the **Driver Portal** or open **Settings** in the Control Panel.
2. Under **SMS Dispatch Settings**, configure your preferred method:
   - **Native Device SIM**: Dispatches directly via your device's active carrier SIM (requires Android SMS permission).
   - **TextBee Gateway**: Enter your TextBee API Key and Device ID for automated background SMS.
   - **Twilio**: Input your Account SID, Auth Token, and Twilio phone number.

### Emergency Email (SMTP)
Configure SMTP settings in `alert_service.dart` or via the Driver Control Panel to send automated email notifications to emergency contacts.

---

## 📦 Building for Production

### Android APK
```bash
flutter build apk --release
```
The generated APK will be available at:
`build/app/outputs/flutter-apk/app-release.apk`

### Web Deployment
```bash
flutter build web --release
```
