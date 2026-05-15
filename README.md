# Alfapos – POS tizimi (Flutter)

Rasmlardan ilhomlangan mobil POS (Point of Sale) ilovasi. O‘zbek tilida.

## Xususiyatlar

- **Asosiy** – ALFAPOS brendi, ko‘rgazma videolar bloki, do‘kon filtri, bo‘sh sotuvlar holati, sana oralig‘i
- **Katalog** – Tovarlar ro‘yxati, qidiruv, filtrlash (Barchasi / Faol / Faol emas), yangi tovar qo‘shish, tezkor qidiruv (skaner)
- **Sotuvlar (Savatcha)** – Bo‘sh savatcha, qidiruv orqali tovar qo‘shish, skaner modal, miqdorni o‘zgartirish, Keyingisi → tranzaksiya
- **Tranzaksiyalar** – Ro‘yxat, qidiruv, sana tanlash, bo‘sh holat
- **Menu** – Barcha modullar: Tovarlar (Katalog, Buyurtmalar, Inventarizatsiya, …), Sotuvlar, Mijozlar
- **Yangi tovar** – Fotosurat, asosiy parametrlar, narxlar, tovarlar soni, xususiyatlar, Tez qo‘shish
- **Tranzaksiya #…** – Tafsilotlar / To‘lov tablari, Mijoz, Sotuvchi, Chegirma, Tavsif, Kechiktirish / To‘lovga o‘tish
- **Skaner** – Shtrix-kod/QR modal (kamera integratsiyasi keyin qo‘shilishi mumkin)

## Ishga tushirish

### Android Studio da emulyator (simulator) da tekshirish

1. **Android Studio ni oching** va loyihani oching:
   - **File → Open** → `alfapos_app` papkasini tanlang (masalan: `Desktop/alfapos_app`).
   - Loyiha yuklanganidan keyin **flutter pub get** avtomatik ishlashi yoki pastdagi buyruqlarni terminalda bajarishingiz mumkin.

2. **Android emulyator yaratish** (agar yo‘q bo‘lsa):
   - **Tools → Device Manager** (yoki o‘ng ustki telefon ikonkasi).
   - **Create Device** → telefon modelini tanlang (masalan Pixel 6) → **Next**.
   - System Image tanlang (masalan API 34, **Download** kerak bo‘lsa yuklab oling) → **Next** → **Finish**.
   - Ro‘yxatdan kerakli qurilmani **▶ (Play)** bilan ishga tushiring — emulyator ochiladi.

3. **Loyihani emulyatorda ishga tushirish:**
   - Emulyator ishlab turgan bo‘lishi kerak.
   - Android Studio da ustki **device** ro‘yxatidan ochiq emulyatorni tanlang.
   - **▶ Run** (yoki `Shift+F10`) bosing — ilova emulyatorda yuklanadi.

   Yoki **terminal** orqali (loyiha papkasida):
   ```bash
   cd /Users/azizbeksmac/Desktop/alfapos_app
   flutter pub get
   flutter run
   ```
   Bir nechta qurilma bo‘lsa: `flutter devices` — keyin `flutter run -d <device_id>`.

4. **Kirish:** Emulyatorda ilova ochilgach, **Kompaniya ID: 1**, **Login: admin**, **Parol: 123** bilan kiring (lokal). Serverni ulash: **email** va **parol**ni nasiyapos.uz hisobi bilan kiriting.

---

## nasiyapos.uz API ulanishi

Ilova **https://nasiyapos.uz** API bilan ishlashi uchun sozlangan. Kirishda avval API orqali login sinanadi (`POST /api/v1/login`); token saqlanadi va barcha himoyalangan so'rovlarda `Authorization: Bearer {token}` yuboriladi. Tarmoq xatosi yoki noto'g'ri ma'lumot bo'lsa, lokal tekshiruv (admin / 123) ishlatiladi.

- **API konfiguratsiya:** `lib/core/api_config.dart` — `baseUrl`, `apiPrefix`.
- **Auth:** `lib/core/auth_storage.dart` — token va company_id saqlash.
- **So'rovlar:** `lib/core/api_client.dart` — get/post/delete, Bearer va X-Company-Id.
- **Servislar:** `lib/services/api_service.dart` — DashboardApi, AuthApi, ContactsApi, ProductsApi, CategoriesApi, ExpensesApi, ReportsApi, UserApi.

To'liq endpoint ro'yxati: `docs/MOBILE_API.md`.

---

### Umumiy (terminal orqali)

1. Loyiha papkasida:
   ```bash
   cd /Users/azizbeksmac/Desktop/alfapos_app
   ```
2. Agar loyiha yangi bo‘lsa va platforma fayllari yo‘q bo‘lsa, Flutter platformalarini yaratish:
   ```bash
   flutter create . --project-name alfapos_app
   ```
   (mavjud fayllarni overwrite qilmaslik uchun kerak bo‘lsa, avval nusxa oling.)
3. Bog‘liqliklar:
   ```bash
   flutter pub get
   ```
4. Ilovani ishga tushirish:
   ```bash
   flutter run
   ```

## Loyiha tuzilishi

- `lib/main.dart` – kirish nuqtasi
- `lib/app.dart` – MaterialApp va mavzu
- `lib/core/` – theme, constants
- `lib/models/` – Product, CartItem
- `lib/providers/` – CartProvider (savatcha)
- `lib/data/` – sample_data (namuna tovarlar)
- `lib/screens/` – barcha ekranlar
- `lib/widgets/` – AppHeader, ProductTile

Skaner uchun haqiqiy kamera/shtrix-kod kutubxonasi (masalan, `mobile_scanner`) keyingi qadamda qo‘shilishi mumkin.
