# ⚡ Ren Tracker v2.0 — Full Setup Guide
### Renish Electronics Attendance Management System
### With OneSignal Push Notifications

---

## 🔑 Login System

| Role | Login Method | Who Can Enter |
|------|-------------|----------------|
| Admin | Email + Password | rprpradeesh@gmail.com, rajadurair207@gmail.com ONLY |
| Employee | Phone Number OTP | Any phone number (verified via Firebase SMS) |

---

## 🔥 STEP 1 — Firebase Setup

1. Go to https://console.firebase.google.com
2. Create project → Enable:
   - **Authentication** → Email/Password + Phone
   - **Firestore Database** → production mode → asia-south1
3. Add admin accounts in Authentication:
   - rprpradeesh@gmail.com (set password)
   - rajadurair207@gmail.com (set password)
4. Download `google-services.json` → place in `android/app/`

---

## 🔒 STEP 2 — Apply Firestore Rules

1. Firestore → Rules tab
2. Paste contents of `firestore.rules`
3. Click Publish

---

## 🔔 STEP 3 — OneSignal Setup (Push Notifications)

### 3a. Create OneSignal Account
1. Go to https://onesignal.com → Sign up free
2. Create New App → Name: "Ren Tracker"
3. Select **Google Android (FCM)** platform

### 3b. Link Firebase with OneSignal
1. In OneSignal → Settings → Platforms → Google Android
2. Go to your Firebase project → Project Settings → Cloud Messaging
3. Copy **Server Key** (FCM key) → Paste in OneSignal
4. Click Save

### 3c. Get Your Keys
1. OneSignal Dashboard → Settings → Keys & IDs
2. Copy **App ID** → paste in `lib/services/onesignal_service.dart`:
   ```dart
   static const String oneSignalAppId = 'PASTE_YOUR_APP_ID_HERE';
   ```
3. Copy **REST API Key** → paste in same file:
   ```dart
   static const String oneSignalRestApiKey = 'PASTE_YOUR_REST_API_KEY_HERE';
   ```

### 3d. Add to AndroidManifest.xml
Add inside `<application>` tag in `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.onesignal.NotificationServiceExtension"
    android:value="com.onesignal.example.NotificationServiceExtension" />
```

---

## 📲 STEP 4 — Flutter Setup

```bash
# Install dependencies
flutter pub get

# Run app
flutter run

# Build release APK
flutter build apk --release

# APK location: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🗄️ STEP 5 — Add Employees in Firestore

**Collection:** `employees`
**Document ID:** `EMP001` (or any ID)

```
employees/EMP001
  name: "Sam"
  phone: "Emp__phno"   ← Must match their OTP login number
  department: "Electronics"
  position: "Technician"
  salary: 15000
  salaryType: "monthly"  (monthly / daily / weekly)
  role: "employee"
  fcmToken: ""
  oneSignalPlayerId: ""
```

When employee logs in via OTP → app auto-fills fcmToken & oneSignalPlayerId.

---

## 📱 How Push Notifications Work

```
Admin opens app
  → Goes to "Notify" tab
  → Types Title + Message
  → Taps "Send to All Employees"

OneSignal API is called
  → ALL employees with app installed receive push notification
  → Notification also saved in Firestore (visible in app)
```

---

## 📊 What Each Role Can Do

### Admin ✅ Full Control
- Mark attendance (present / absent / half-day)
- Add & delete employees
- Calculate salary by date range
- Send push notifications to ALL employees via OneSignal
- View all dashboards and reports

### Employee 👁️ View Only
- View their own attendance history
- View their salary estimate
- View all notifications from admin
- View team members list
- View their own profile
- Receive push notifications automatically

---

## ⚡ Built by
**© 2026 pradeesh — Made by Rpr**
Renish Electronics · Ren Tracker v2.0
