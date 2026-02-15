# 📄 DocScanner

**DocScanner** adalah aplikasi pemindai dokumen pintar berbasis **Flutter** yang terintegrasi dengan **Native Android (Kotlin)** menggunakan **Google ML Kit**.

Aplikasi ini menawarkan pengalaman memindai dokumen yang cepat, akurat, dan ringan, dengan kemampuan deteksi tepi otomatis dan pemrosesan gambar tingkat lanjut.

---

## ✨ Fitur Utama

✅ **Smart Scan (Native ML Kit)**
Menggunakan teknologi *On-Device Machine Learning* dari Google untuk:
- Deteksi tepi dokumen otomatis.
- Pemotongan (Auto-Crop) presisi.
- Koreksi perspektif (meluruskan dokumen miring).
- Pembersihan noda dan bayangan.

✅ **Image Editor**
Fitur pengeditan gambar bawaan:
- **Filter:** Original, Grayscale, Black & White, dan Magic Color.
- **Rotate:** Putar dokumen agar orientasinya pas.

✅ **Manajemen Dokumen**
- Simpan hasil scan dalam galeri aplikasi.
- Ganti nama (Rename) dan Hapus dokumen.
- Pencarian (Search) cepat.

✅ **Performa Tinggi**
- UI/UX modern dan responsif (Flutter).
- Pemrosesan gambar di level Native (Kotlin) untuk kecepatan maksimal.
- Ukuran aplikasi optimal (~20MB release).

---

## 🛠️ Teknologi yang Digunakan

| Komponen | Teknologi | Deskripsi |
| :--- | :--- | :--- |
| **Framework UI** | ![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white) | Membangun antarmuka yang indah dan cross-platform. |
| **Bahasa Utama** | ![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white) | Logika aplikasi dan manajemen state. |
| **Native Integration** | ![Kotlin](https://img.shields.io/badge/Kotlin-7F52FF?style=flat&logo=kotlin&logoColor=white) | Jembatan ke fitur sistem Android & ML Kit. |
| **Scanner Engine** | ![ML Kit](https://img.shields.io/badge/Google_ML_Kit-4285F4?style=flat&logo=google&logoColor=white) | Otak cerdas di balik fitur scanning. |

---

## 🚀 Cara Menjalankan

### Prasyarat
- Flutter SDK terinstall.
- Android Studio / VS Code.
- Perangkat Android (Fisik atau Emulator).

### Langkah-langkah
1. **Clone Repository**
   ```bash
   git clone https://github.com/username/docscanner.git
   cd docscanner
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Jalankan Aplikasi**
   Pastikan HP terhubung via USB, lalu:
   ```bash
   flutter run
   ```

4. **Build APK (Release)**
   Untuk membuat file mentahan siap install:
   ```bash
   flutter build apk --release
   ```
   File APK akan muncul di: `build/app/outputs/flutter-apk/app-release.apk`

---

## 📂 Struktur Project
- `lib/`: Kode utama Flutter (UI, Logic).
- `android/`: Kode Native Android (Kotlin & Gradle).
- `assets/`: Gambar dan ikon (jika ada).

---

## 📝 Catatan Penting
Aplikasi ini menggunakan **MethodChannel** untuk berkomunikasi antara Flutter dan Kotlin.
- **Flutter** meminta scan -> **Kotlin** membuka Google Scanner -> **Kotlin** mengembalikan hasil foto ke **Flutter**.

---

Made with ❤️ by Muhamad Alwan Suryadi
