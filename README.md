# Amimir — Sleep Tracking & Daily Activity App

<p align="center">
  <img src="assets/icon/icon_app.png" width="120" alt="Amimir Logo" />
</p>

<p align="center">
  <strong>Track your sleep, improve your life.</strong>
</p>

<p align="center">
  Aplikasi Android untuk melacak kualitas tidur dan aktivitas harian,
  dilengkapi analisis AI dan komunitas antar pengguna.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-blue?logo=dart" />
  <img src="https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-orange?logo=firebase" />
  <img src="https://img.shields.io/badge/Platform-Android-green?logo=android" />
  <img src="https://img.shields.io/badge/License-MIT-lightgrey" />
</p>

---

## Tentang Aplikasi

Amimir adalah aplikasi *sleep tracker* dan *daily activity tracker* yang
dikembangkan sebagai project kampus semester 4. Aplikasi ini membantu pengguna
memahami pola tidur mereka, mencatat aktivitas harian, dan mendapatkan
rekomendasi personal dari AI berdasarkan data yang dikumpulkan.

---

## About

**Wonderful Dream Production** kelompok yang dibentuk pada mata kuliah **Rekayasa Perangkat Lunak (RPL)** di **Institut Teknologi Indonesia (ITI)** tahun **2026**.

### Team Members
- Ramdhany Sunarto
- Muhammad Andi Rizky Maulana Ibrahim
- Gilang Putra Wardana
- Muhammad Arik Hadi Sucahyo

**Institution:** Institut Teknologi Indonesia (ITI)  
**Year:** 2026  
**Course:** Rekayasa Perangkat Lunak (RPL)

---

## Fitur Utama

### Tidur
- **Sleep Timer** — catat waktu mulai dan bangun tidur dengan satu tap
- **Manual Input** — input sleep time dan wake time secara manual dengan
  validasi waktu
- **Sleep Score** — skor kualitas tidur otomatis berdasarkan durasi
- **Sleep Log History** — riwayat lengkap catatan tidur per tanggal

### Aktivitas Harian
- **Mood Tracker** — catat suasana hati harian
- **Caffeine Log** — catat konsumsi kafein beserta waktu minum
- **Meal Photo** — foto makanan terakhir sebagai konteks analisis
- **Activity Log** — catat jenis dan durasi aktivitas fisik
- **Condition Tracker** — catat kondisi tubuh (sehat, sakit, stress, dll)
- **Sleep Helpers** — catat kebiasaan sebelum tidur

### Analisis AI
- **Daily, Weekly, Monthly Analysis** — analisis pola tidur berbasis periode
- **Gemini AI Integration** — insight dan rekomendasi dari Google Gemini
- **Meal Image Recognition** — AI membaca foto makanan untuk konteks analisis
- **Disease History Context** — riwayat penyakit user digunakan sebagai
  konteks rekomendasi AI
- **Analysis Cache** — hasil analisis tersimpan lokal untuk diakses offline

### Laporan
- **Reports Screen** — visualisasi data tidur mingguan dan bulanan
- **Line Chart** — grafik durasi tidur dari waktu ke waktu
- **Pagination** — navigasi halaman data dengan filter tanggal custom

### Profil & Akun
- **Edit Display Name** — ubah nama tampilan langsung dari Profile screen
- **Sleep Goal** — atur target jam tidur dengan slider (4–12 jam)
- **Disease History** — kelola riwayat penyakit (CRUD, disinkronkan ke Firestore)
- **Email Verification** — verifikasi email wajib setelah register untuk
  mencegah email squatting
- **Cloud Backup & Restore** — backup dan restore data lokal ke Firestore
  secara manual

### Achievement System
- **20+ Achievement** — berbagai pencapaian berdasarkan konsistensi tidur,
  analisis, dan penggunaan fitur
- **Rarity Tier** — Common, Rare, Epic, Legendary
- **Equipped Badge** — tampilkan achievement di profil dan forum
- **In-app Banner** — notifikasi unlock achievement muncul di atas layar
  dari mana saja tanpa perlu membuka halaman achievement

### Forum Komunitas
- **Post & Diskusi** — bagikan tips dan pengalaman tidur
- **Kategori** — Umum, Pertanyaan, Sleep Tips, Achievement, Pengalaman
- **Like & Dislike** — vote konten yang berguna
- **Admin Moderation** — admin dapat menghapus post yang tidak pantas
- **Author Badge** — badge achievement ditampilkan di samping nama penulis

### Notifikasi
- **Sleep Active Notification** — notifikasi OS ongoing saat timer tidur berjalan
- **Daily Log Reminder** — pengingat harian terjadwal via WorkManager
  (tahan terhadap battery optimization Samsung)
- **In-app Notification Bell** — dropdown riwayat notifikasi achievement
  dan pengingat harian di top bar

---

## Arsitektur

```
lib/
├── main.dart                    # Entry point, inisialisasi Firebase/Hive/WorkManager
├── app.dart                     # MaterialApp + achievement overlay
├── core/
│   ├── constants/               # AppColors, AppStrings
│   ├── services/                # NotificationService, UserSessionService
│   ├── theme/                   # AppTheme, AppTextStyles
│   └── widgets/                 # AppScaffold, AppCard, SessionGate, SplashScreen
├── data/
│   ├── local/                   # Hive services (sleep, daily, achievement, notification)
│   ├── models/                  # Data models (SleepLog, DailyLog, AnalysisCache, ...)
│   ├── remote/                  # AI services (Gemini, Meal Image Recognition)
│   └── repositories/            # Auth, Analysis, Backup, Disease History, Profile
├── features/
│   ├── auth/                    # Login, Register, Email Verification
│   ├── home/                    # Sleep Timer
│   ├── dashboard/               # Daily Log Input
│   ├── analysis/                # AI Analysis
│   ├── reports/                 # Sleep Reports
│   ├── profile/                 # Profile, Disease History, Cloud Backup
│   ├── achievements/            # Achievement system + banner
│   ├── forum/                   # Community forum
│   ├── notifications/           # In-app notification provider
│   └── shared/                  # Shared providers (selectedDailyDateProvider)
└── routes/                      # GoRouter configuration
```

### State Management
- **Riverpod 3.x** — `AsyncNotifierProvider`, `NotifierProvider`, `StreamProvider`
- `StateProvider` via `flutter_riverpod/legacy.dart`

### Data Storage
| Data | Storage |
|------|---------|
| Sleep Log | Hive (local, per-akun) |
| Daily Log | Hive (local, per-akun) |
| Analysis Cache | Hive (local, per-akun) |
| Achievement | Hive (local, per-akun) |
| App Notifications | Hive (local, per-akun) |
| User Profile | Firestore |
| Disease History | Firestore subcollection |
| Backup | Firestore |
| Forum Posts | Firestore |
| App Settings | Hive (global) |

---

## Teknologi

| Package | Kegunaan |
|---------|---------|
| `firebase_core` | Firebase initialization |
| `firebase_auth` | Authentication (Email/Password) |
| `cloud_firestore` | Database cloud (profile, forum, disease history) |
| `hive` / `hive_flutter` | Local database (sleep log, daily log, dll) |
| `flutter_riverpod` | State management |
| `go_router` | Navigation & routing |
| `http` | REST API call ke Gemini |
| `fl_chart` | Chart & grafik |
| `image_picker` | Ambil foto makanan |
| `flutter_local_notifications` | Notifikasi OS |
| `workmanager` | Background task (daily reminder) |
| `flutter_timezone` | Timezone detection device |
| `timezone` | Timezone handling untuk notifikasi |
| `flutter_native_splash` | Native splash screen |
| `flutter_launcher_icons` | App icon generation |
| `intl` | Formatting tanggal & locale |

---

## Pengaturan & Instalasi

### Prasyarat
- Flutter SDK `^3.11.5`
- Dart SDK `^3.x`
- Android Studio / VS Code
- Akun Firebase
- API Key Google Gemini (AI Studio)

### Clone & Setup

```bash
git clone https://github.com/username/amimir.git
cd amimir
flutter pub get
```

### Konfigurasi Firebase

1. Buat project di [Firebase Console](https://console.firebase.google.com/)
2. Tambahkan Android app dengan package name `com.example.amimir`
3. Download `google-services.json` dan taruh di `android/app/`
4. Aktifkan **Authentication** (Email/Password)
5. Buat **Firestore Database** (test mode)
6. Update Firestore Rules (lihat bagian [Security Rules](#security-rules))

### Konfigurasi Gemini API

Jalankan app dengan API key via `--dart-define`:

```bash
flutter run --dart-define=GEMINI_API_KEY=ISI_API_KEY_KAMU

# Build release
flutter build apk --release --dart-define=GEMINI_API_KEY=ISI_API_KEY_KAMU
```

Dapatkan API key gratis di [Google AI Studio](https://aistudio.google.com/).

### Generate Assets

```bash
# App icon
dart run flutter_launcher_icons

# Native splash screen
dart run flutter_native_splash:create
```

---

## Security Rules

### Firestore

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;

      match /disease_history/{docId} {
        allow read, write: if request.auth != null
                           && request.auth.uid == userId;
      }

      match /backups/{document} {
        allow read, write: if request.auth != null
                           && request.auth.uid == userId;
      }
    }

    match /forum_posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
                    && request.resource.data.author_uid == request.auth.uid;
      allow update: if request.auth != null;
      allow delete: if request.auth != null
                    && (resource.data.author_uid == request.auth.uid
                        || request.auth.uid == 'ADMIN_UID_KAMU');
    }
  }
}
```

---

## Struktur Data Firestore

```
users/{uid}
  ├── email
  ├── username
  ├── equippedAchievementId
  ├── created_at
  ├── updated_at
  ├── profile/
  │   ├── display_name
  │   ├── photo_url
  │   └── sleep_goal
  ├── disease_history/{docId}
  │   ├── id
  │   ├── name
  │   ├── diagnosed_at
  │   ├── note
  │   ├── created_at
  │   └── updated_at
  └── backups/latest
      ├── sleepLogs[]
      ├── dailyLogs[]
      ├── analysisCaches[]
      ├── unlockedAchievements{}
      ├── backedUpAt
      └── counts{}

forum_posts/{postId}
  ├── author_uid
  ├── author_username
  ├── author_badge
  ├── title
  ├── content
  ├── category
  ├── created_at
  ├── likes[]
  └── dislikes[]
```

---

## Catatan Pengembangan

### Data Lokal vs Cloud

Aplikasi ini menggunakan pendekatan **local-first** untuk data tracking:
- Sleep log, daily log, analysis cache, dan achievement disimpan di Hive
  (lokal, per-akun) untuk performa optimal dan kemampuan offline
- Cloud Backup tersedia sebagai fitur opsional (on-demand, bukan auto-sync)
- Foto makanan tidak ikut di-backup karena membutuhkan Firebase Storage
  (Blaze plan)

### Notifikasi di Samsung

Samsung One UI secara agresif mematikan `BroadcastReceiver` dari `AlarmManager`.
Daily Log Reminder menggunakan **WorkManager** (JobScheduler) sebagai solusi,
bukan `flutter_local_notifications` `zonedSchedule`. Pastikan battery restriction
dinonaktifkan di `Settings → Battery → Background usage limits → Amimir`.

### Firebase Storage

Foto profil tidak diimplementasikan karena Firebase Storage membutuhkan
upgrade ke Blaze plan. Avatar menggunakan initial huruf pertama nama.
Alternatif: Cloudinary (free tier 25 GB, tanpa kartu kredit).


---


> "Sleep is the best meditation." — Dalai Lama
