# ⚡ Ren Tracker v3.0 — Full Setup Guide
### Multi-Tenant SaaS Attendance Management Platform
### Powered by Flutter · Firebase · OneSignal

---

## 🆕 What's New in v3

| Feature | v2 | v3 |
|---|---|---|
| Architecture | Single-org | **Multi-tenant SaaS** (any number of orgs) |
| Roles | Admin + Employee | **Super Admin + Admin + Employee** |
| Firestore structure | Flat root collections | **Scoped under `organizations/{orgId}/`** |
| Config | Hardcoded credentials | **`.env` file + `EnvConfig`** |
| Notifications | OneSignal (global) | **OneSignal per-tenant tags** |
| Cloud Functions | None | **Firebase Functions for provisioning** |
| Migration | N/A | **Non-destructive migration script** |

---

## 🔑 Role System

| Role | Login Method | Access Level |
|------|-------------|--------------|
| **Super Admin** | Email + Password | Full platform control — manages all orgs & users |
| **Admin** | Email + Password | Org-scoped control — manages own org's employees |
| **Employee** | Phone Number OTP | View-only — own attendance, salary & notifications |

---

## 📁 Project Structure

```
ren_tracker_v3/
├── lib/
│   ├── config/
│   │   └── env_config.dart          # Loads .env, exposes typed config
│   ├── models/
│   │   ├── app_user.dart            # AppUser (uid, role, orgId, empId)
│   │   ├── organization_model.dart  # Org settings (currency, timezone…)
│   │   └── user_role.dart           # Enum: superAdmin | admin | employee
│   ├── screens/
│   │   ├── super_admin/             # SaaS control panel
│   │   ├── admin/                   # Org-level management
│   │   └── employee/                # Employee self-service
│   ├── services/
│   │   ├── auth_service.dart        # Firebase Auth + role resolution
│   │   ├── firestore_service.dart   # Org-scoped Firestore queries
│   │   └── onesignal_service.dart   # Push notifications with tenant tags
│   └── main.dart
├── functions/
│   ├── index.js                     # Cloud Functions entry point
│   └── scripts/
│       ├── bootstrap_super_admin.js # One-time super admin setup
│       └── migrate_to_global_tenant.js
├── migration/
│   └── migrate_renish.js            # Non-destructive v2 → v3 migration
├── .env.example                     # Environment variables template
├── .env                             # Your local config (gitignored)
└── firestore.rules
```

---

## 🔥 STEP 1 — Firebase Setup

1. Go to https://console.firebase.google.com
2. Create project → Enable:
   - **Authentication** → Email/Password + Phone
   - **Firestore Database** → production mode → `asia-south1`
3. Download `google-services.json` → place in `android/app/`

---

## 🔒 STEP 2 — Apply Firestore Rules

1. Firestore → **Rules** tab
2. Paste contents of `firestore.rules`
3. Click **Publish**

---

## ⚙️ STEP 3 — Configure Environment

1. Copy `.env.example` to `.env` in the project root:
   ```bash
   copy .env.example .env
   ```

2. Fill in your values:
   ```env
   # OneSignal
   ONESIGNAL_APP_ID=your_onesignal_app_id_here
   ONESIGNAL_REST_API_KEY=your_onesignal_rest_api_key_here

   # Firebase
   FIREBASE_PROJECT_ID=your_project_id
   FIREBASE_MESSAGING_SENDER_ID=your_sender_id
   FIREBASE_STORAGE_BUCKET=your_storage_bucket
   FIREBASE_API_KEY_ANDROID=your_android_api_key
   FIREBASE_APP_ID_ANDROID=your_android_app_id
   FIREBASE_API_KEY_WEB=your_web_api_key

   # Google OAuth
   GOOGLE_WEB_CLIENT_ID=your_google_web_client_id

   # Tenant
   DEFAULT_ORG_ID=ren_tracker
   ```

> The app loads `.env` at startup via `EnvConfig.init()` — no hardcoded secrets needed.

---

## 🔔 STEP 4 — OneSignal Setup (Push Notifications)

### 4a. Create OneSignal App
1. Go to https://onesignal.com → Sign up free
2. Create New App → Name: `"Ren Tracker"`
3. Select **Google Android (FCM)** platform

### 4b. Link Firebase with OneSignal
1. OneSignal → Settings → Platforms → Google Android
2. Firebase project → Project Settings → Cloud Messaging
3. Copy **Server Key** (FCM key) → Paste in OneSignal → Save

### 4c. Get Your Keys
1. OneSignal Dashboard → Settings → Keys & IDs
2. Copy **App ID** → set `ONESIGNAL_APP_ID` in `.env`
3. Copy **REST API Key** → set `ONESIGNAL_REST_API_KEY` in `.env`

### 4d. Tenant-Aware Tags (v3)
Each employee's OneSignal subscription is tagged with their `orgId`, `empId`, and `role`. Notifications are sent to a **segment filter** so admins only reach employees in their own org.

---

## 🚀 STEP 5 — Bootstrap Super Admin

Run once after deploying Cloud Functions:

```bash
cd functions
node scripts/bootstrap_super_admin.js
```

This provisions the root `super_admin` user with Firebase Custom Claims. Set `GOOGLE_APPLICATION_CREDENTIALS` or run inside the Firebase emulator.

---

## 📲 STEP 6 — Flutter Setup

```bash
# Install dependencies
flutter pub get

# Run app (debug)
flutter run

# Build release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🗄️ STEP 7 — Firestore Data Structure (v3)

All data is scoped under the organization document:

```
organizations/
  {orgId}/                          ← e.g. "ren_tracker"
    name: "Renish Electronics"
    status: "active"
    adminEmail: "admin@example.com"
    currency: "INR"
    currencySymbol: "₹"
    timeZone: "Asia/Kolkata"
    workingDays: [1,2,3,4,5,6]
    standardWorkHours: 8.0
    salaryBasis: "monthly_26"
    overtimeMultiplier: 1.5

    employees/
      {empId}/
        name: "Sam"
        phone: "+919XXXXXXXXX"   ← Must match OTP login number
        department: "Electronics"
        position: "Technician"
        salary: 15000
        salaryType: "monthly"    (monthly / daily / weekly)
        role: "employee"
        oneSignalPlayerId: ""    ← Auto-filled on first login

    attendance/
      {YYYY-MM-DD}/
        {empId}: { status: "present" | "absent" | "half_day", … }

    notifications/
      {notifId}/
        title: "…"
        message: "…"
        sentAt: Timestamp

users/
  {uid}/                           ← Global user registry
    role: "super_admin" | "admin" | "employee"
    orgId: "ren_tracker"
    empId: "EMP001"
    status: "active" | "suspended"
```

> **Note:** The `employees`, `attendance`, and `notifications` collections now live **inside** each org, not at the root. v2 root collections (`/employees`, `/attendance`) are kept during migration.

---

## 🔄 STEP 8 — Migrating from v2

If you have existing Renish Electronics data in the v2 flat root collections, run the **non-destructive** migration script:

```bash
cd migration
node migrate_renish.js
```

This copies all data into `organizations/ren_tracker/employees` and `organizations/ren_tracker/attendance` **without deleting** any legacy records. You can verify with `functions/scripts/verify_migration.js`.

---

## 📱 How Push Notifications Work (v3)

```
Admin → "Notify" tab → Types Title + Message → "Send to All Employees"
  │
  └─► OneSignal REST API called with segment filter:
        orgId = {admin's orgId} AND role = "employee"
      → ALL employees of that org receive push notification
      → Notification saved in organizations/{orgId}/notifications/
```

---

## 📊 What Each Role Can Do

### 🛡️ Super Admin — SaaS Platform Control
- View platform-wide metrics (orgs, users, admins, employees)
- **Provision** new organizations + their first admin account
- **Suspend / reactivate** any organization or user
- Browse all users across all orgs
- Monitor platform health (Firestore, auth, push service)

### ✅ Admin — Org-Level Management
- Mark employee attendance (present / absent / half-day)
- Add & delete employees within their org
- Calculate salary by date range
- Send push notifications to their org's employees via OneSignal
- View org dashboards and reports
- Export attendance/salary data as CSV

### 👁️ Employee — Self-Service View
- View own attendance history
- View own salary estimate
- View notifications from admin
- View team members list
- View own profile
- Receive push notifications automatically

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter 3 (Dart ≥ 3.2) |
| Auth | Firebase Authentication (Email/Password + Phone OTP) |
| Database | Cloud Firestore (asia-south1) |
| Push Notifications | OneSignal v5 (`onesignal_flutter: ^5.2.8`) |
| Cloud Functions | Firebase Functions (Node 18) |
| Charts | fl_chart |
| Config | `.env` asset loaded via `EnvConfig` |

---

## ⚡ Built with
**© 2026 Ren Tracker**
Ren Tracker v3.0
