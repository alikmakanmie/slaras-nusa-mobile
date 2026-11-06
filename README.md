# SLARAS NUSA FOODLAB — Aplikasi Mobile (Flutter)

Aplikasi mobile kuliner & F&B **SLARAS NUSA FOODLAB** — tema Neobrutalism
BoldKit (hitam pekat dominan, border tegas, hard shadow, font tebal
uppercase, Dark/Light mode), terintegrasi penuh ke API produksi
`https://api.alikmakanmie.my.id/api/v1`.

## Fitur

- **Splash + Onboarding** 3 halaman. Aplikasi langsung membuka **Katalog**
  tanpa paksa login — login member/admin/kasir tersedia di tab Profil.
- **Guest Checkout (tanpa login)**: keranjang lokal tersimpan di perangkat
  (SharedPreferences), tombol "+ Tambah Pesanan" di katalog. Saat login,
  isi keranjang lokal otomatis didorong ke API `/cart`.
  - Jenis pesanan: **Dine-In** (nama + nomor meja, tombol cepat Meja 1–20 +
    catatan), **Takeaway** (nama + No. WhatsApp), **Delivery** (nama + WA +
    alamat lengkap). Tombol "Bayar Sekarang" menembak endpoint publik
    `POST /orders/guest-checkout` (tanpa JWT) → QRIS/VA, lalu halaman
    pembayaran (QR + simulasi bayar + polling) → struk digital.
  - **Lacak Pesanan** publik `GET /orders/track/:order_number` (tanpa
    login): timeline status + struk digital. Nomor order tamu disimpan
    di perangkat → menu "Pesanan Saya" tanpa login.
- **Floating Cart Bar** (katalog): begitu keranjang berisi minimal 1 item
  (tamu maupun member), bar hitam mengambang persisten muncul di bawah
  layar katalog — badge `[ N ITEM ]`, nama menu singkat, total harga,
  tombol "LIHAT / EDIT" (sheet edit keranjang: ubah qty +/-, hapus item,
  tanpa pindah halaman) dan tombol utama "CHECKOUT SEKARANG →" yang
  langsung membuka alur checkout (tamu → Guest Checkout, member →
  Checkout) dalam 1 klik.
- **Auth**: Login, Register, auto-refresh JWT (access 15 menit), Edit Profil,
  Logout. Akun demo di layar login (customer / admin).
- **Katalog**: daftar produk, pencarian real-time (debounce), filter kategori,
  filter rentang harga, halaman detail produk, paginasi.
- **Keranjang**: tambah, ubah kuantitas (+/-), hapus, subtotal sinkron API.
- **Checkout**: pilih alamat pengiriman, metode bayar QRIS / Virtual Account,
  buat order.
- **Pembayaran (Mock Gateway)**: tampilkan QRIS + payment URL, tombol
  *Simulasikan Pembayaran Sukses* (membuka halaman mock-pay lalu mem-poll
  status order sampai `paid`), tombol cek status manual.
- **Pesanan**: riwayat order, detail + tracking timeline, batalkan order.
- **Gambar produk & kategori**: setiap produk/kategori menampilkan
  `image_url` (foto Unsplash CDN) di katalog, detail produk, keranjang,
  dan tabel produk admin; chip kategori menampilkan thumbnail. Bila gambar
  gagal dimuat, `ProductImage` (errorBuilder) menampilkan placeholder
  BoldKit hitam-putih bertuliskan nama menu.
- **Audit trail**: order & transaksi terbaru membawa `processed_by_name`
  (nama staf yang memproses, mis. "Barista Slaras") — ditampilkan sebagai
  "Diproses oleh: [Nama]" di kartu pesanan (Admin → Kelola Pesanan) dan di
  transaksi terbaru Dashboard Profit; disembunyikan bila kosong.
- **Admin** (`role == admin` atau `superadmin`): CRUD produk (termasuk **Harga Modal**
  `cost_price` per produk), CRUD kategori, kelola semua
  pesanan + ubah status (`processing`, `shipped`, `completed`). Badge profil
  menampilkan `SUPERADMIN` / `ADMIN` / `CUSTOMER`.
- **Dashboard Profit** (admin, Profil → DASHBOARD PROFIT):
  `GET /admin/analytics/profit?period=today|7d|30d|all` — kartu KPI
  (Omzet, Laba Bersih, Margin %, Pesanan Lunas, AOV), grafik batang
  Omzet vs Laba per hari, breakdown per jenis pesanan & metode bayar,
  menu paling menguntungkan (top 5), 10 transaksi terbaru.

## Arsitektur

```
lib/
  main.dart            # Entry point + Provider
  config.dart          # Base URL API (dart-define API_BASE_URL)
  api.dart             # ApiClient: JWT + auto-refresh saat 401
  models.dart          # Model domain (User, Product, Cart, Order, ...)
  state.dart           # ThemeState, AuthState, CartState, AddressState
  theme.dart           # Design system Neobrutalism (light/dark)
  widgets.dart         # BrutalButton, BrutalCard, BrutalTextField, ...
  screens/             # Splash, Onboarding, Login, Register, Home, ...
test/
  api_client_test.dart # Tes integrasi ke API lokal (login → checkout)
  guest_checkout_test.dart # Tes guest: katalog tanpa login, dine-in/
                           # takeaway/delivery + track, keranjang lokal
  profit_analytics_test.dart # Tes profit admin (parsing + live) &
                           # FloatingCartBar (widget test)
  catalog_images_test.dart # Tes gambar (katalog kopi baru 18 menu,
                           # ProductImage fallback) + audit trail live
```

## Menjalankan

```bash
flutter pub get
# Produksi (default):
flutter run
# API lokal:
flutter run --dart-define API_BASE_URL=http://localhost:8080/api/v1
# Emulator Android (API lokal di host):
flutter run --dart-define API_BASE_URL=http://10.0.2.2:8080/api/v1
```

## Build APK

```bash
flutter analyze            # harus 0 issue
flutter test               # tes integrasi (butuh API lokal jalan)
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

Build APK otomatis juga tersedia lewat GitHub Actions
(`.github/workflows/build-apk.yml`) — artifact `app-release.apk`.

## Catatan pembayaran (penting)

Backend hanya menyediakan simulasi bayar lewat **webhook HMAC**
(`POST /api/v1/payments/webhook`, butuh `WEBHOOK_SECRET`) dan halaman
**MockPay** (`GET /api/v1/mock-pay/:transaction_id`) yang tidak punya tombol
konfirmasi. Karena itu aplikasi **tidak pernah** memanggil webhook langsung
(secret tidak boleh ada di klien). Tombol simulasi di aplikasi membuka
halaman mock-pay lalu mem-poll `GET /orders/:id` sampai status `paid`;
order baru benar-benar berubah ke `paid` bila webhook dipicu dari sisi
server. Bila backend kelak menambah endpoint simulasi aman untuk klien,
cukup arahkan tombol simulasi ke endpoint itu.
