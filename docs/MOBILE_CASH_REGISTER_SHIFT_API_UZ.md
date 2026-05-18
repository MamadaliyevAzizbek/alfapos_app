# Kassa smenasi API — to‘liq qo‘llanma (Mobile / Flutter)

**Web:** Sotuv (`/sales`) → kassa tanlash, **«Kassa smenalari»** modali, tezkor kirim/chiqim, yopish, chop etish.

**Baza:** `https://your-domain.com`  
**Asosiy prefix:** `/api/v1/sales` (kassa) + `/api/v1/incomes`, `/api/v1/expenses` (tezkor pul)  
**Auth:** `Authorization: Bearer {token}`  
**Middleware:** `auth:sanctum`, `set.company.api`

---

## Mundarija

1. [Funksiyalar xaritasi (web ↔ API)](#1-funksiyalar-xaritasi-web--api)
2. [Kassalar ro‘yxati va tanlash](#2-kassalar-royxati-va-tanlash)
3. [Kassa ochish / yopish / smenaga qo‘shilish](#3-kassa-ochish--yopish--smenaga-qoshilish)
4. [Kassa smenasi ekrani (hisobot)](#4-kassa-smenasi-ekrani-hisobot)
5. [Tezkor kirim (kassaga naqd)](#5-tezkor-kirim-kassaga-naqd)
6. [Tezkor chiqim (kassadan chiqim)](#6-tezkor-chiqim-kassadan-chiqim)
7. [Kassa yopish (smenadan)](#7-kassa-yopish-smenadan)
8. [Chop etish va to‘liq hisobot](#8-chop-etish-va-toliq-hisobot)
9. [Barcha endpointlar jadvali](#9-barcha-endpointlar-jadvali)

---

## 1. Funksiyalar xaritasi (web ↔ API)

| Web funksiya | Mobil API | Holat |
|--------------|-----------|--------|
| Kassa ochish (smenani boshlash) | `POST /sales/cash-registers/open-close` `status: "open"` | ✅ |
| Kassa yopish | `POST .../open-close` `status: "closed"` yoki `POST .../cash-register-shifts/close` | ✅ |
| Smenaga qo‘shilish (birlashish) | `POST .../open-close` `status: "enroll"` | ✅ |
| Kassadan chiqish (smenadan) | `POST .../open-close` `status: "leave"` | ✅ |
| Smena hisoboti (jami savdo, to‘lov turlari, qaytarish, naqd qoldiq) | `GET .../cash-register-shifts/{logId}/analytics` + `info` | ✅ |
| Tezkor kirim | `POST /api/v1/incomes` | ✅ |
| Tezkor chiqim | `POST /api/v1/expenses` | ✅ |
| To‘liq hisobot (web sahifa) | `GET .../orders`, `expenses`, `incomes` + hisobotlar moduli | ✅ |
| Chop etish | Client: `analytics` + `info` dan HTML/PDF (web iframe print) | ✅ (ma’lumot API dan) |
| Kutilayotgan yopilish summasi | `GET .../register-amount/{cashRegisterId}` yoki `analytics.expected_amount` | ✅ |

**Eslatma:** Avval mobil hujjatda faqat `cash-registers` ro‘yxati bor edi; **smenа analitikasi** va **tezkor kirim** uchun `incomes` route yo‘q edi — endi qo‘shildi.

---

## 2. Kassalar ro‘yxati va tanlash

Filial kassa rejimida sotuv boshlanishidan oldin:

```http
GET /api/v1/sales/cash-registers
```

**Javob:** massiv (har bir kassa):

| Maydon | Tavsif |
|--------|--------|
| `id` | Kassa ID |
| `title` | Nomi (masalan: `KASSA 3`) |
| `status` | `open` \| `closed` |
| `register_log_id` | Ochiq smena ID (`status=open` bo‘lsa) |
| `opening_amount` | Ochilish summasi |
| `register_status` | Matn: kim ochgan |
| `shift_staff` | `[{ id, name, is_opener }]` |
| `shift_staff_names` | `"Begzod, Shuhrat"` |
| `userID` | Smenadagi user id lar (string[]) |
| `open_user_id` | Ochuvchi user id |
| `permision` | `1` = yopish mumkin |
| `has_password` | Parol talab qilinadimi |

**Chek shabloni:**

```http
GET /api/v1/sales/cash-registers/{id}/sales-template
```

**Javob:** `{ "template_id": 2 }`

**Sotuvda:** `cashRagisterId` = tanlangan kassa `id`, `isCashRegisterBranch: true`, `register_log_id` = `register_log_id`.

---

## 3. Kassa ochish / yopish / smenaga qo‘shilish

```http
POST /api/v1/sales/cash-registers/open-close
Content-Type: application/json
```

Web: `POST /cash-register-open-close` — **bir xil body**.

### 3.1 Kassa ochish

```json
{
  "id": 3,
  "status": "open",
  "openingAmount": 0,
  "openingTime": "2026-05-16 08:44:00",
  "access_password": ""
}
```

| Maydon | Majburiy | Izoh |
|--------|----------|------|
| `id` | Ha | Kassa ID |
| `status` | Ha | `"open"` |
| `openingAmount` | Ha | Boshlang‘ich naqd |
| `openingTime` | Ha | `YYYY-MM-DD H:mm:ss` |
| `access_password` | Shartli | Kassada parol bo‘lsa |

**Keyin:** `GET /cash-registers` qayta chaqiring — `register_log_id` va `status: open` keladi.

### 3.2 Smenaga qo‘shilish (birlashish)

```json
{
  "id": 3,
  "status": "enroll"
}
```

Boshqa hodim ochgan smenaga kirish.

### 3.3 Kassadan chiqish (smenadan, kassani yopmasdan)

```json
{
  "id": 3,
  "status": "leave"
}
```

Faqat smenaga qo‘shilgan (ochuvchi emas) hodim.

### 3.4 Kassa yopish (kartadan, eski usul)

```json
{
  "id": 3,
  "status": "closed",
  "closingAmount": 15284000,
  "closingTime": "2026-05-16 20:00:00",
  "note": ""
}
```

**Tavsiya (smenа modali):** [§7 Kassa yopish](#7-kassa-yopish-smenadan) — `register_log_id` bilan.

---

## 4. Kassa smenasi ekrani (hisobot)

Web: **Kassa smenalari** modali — `register_log_id` bilan ochiladi.

### 4.1 Smena ma’lumoti (header)

```http
GET /api/v1/sales/cash-register-shifts/{logId}/info
```

Web: `GET /cash-register-detail/{id}/info`

**Javob:**

```json
{
  "log": {
    "id": 45,
    "cash_register_id": 3,
    "status": "open",
    "opening_amount": 0,
    "opening_time": "2026-05-16T08:44:00.000000Z",
    "closing_time": null,
    "opened_by": 12
  },
  "cash_register_id": 3,
  "status": "open",
  "can_close": true,
  "opened_by_name": "Begzod Hamdamov",
  "cash_register_title": "KASSA 3",
  "shift_staff": [
    { "id": 12, "name": "Begzod Hamdamov", "is_opener": true },
    { "id": 15, "name": "Shuhrat Latipov", "is_opener": false }
  ],
  "shift_staff_names": "Begzod Hamdamov, Shuhrat Latipov"
}
```

**UI mapping:**

| Ekran | Maydon |
|-------|--------|
| Kassir tomonidan ochilgan | `opened_by_name` |
| Kassa terminali | `cash_register_title` |
| Ochilish vaqti | `log.opening_time` |
| Holat | `status` → `Ochiq` / yopilgan vaqti |
| Smenada ishlayotganlar | `shift_staff` |

### 4.2 Smena analitikasi (asosiy raqamlar)

```http
GET /api/v1/sales/cash-register-shifts/{logId}/analytics
```

Web: `GET /cash-register-detail/{id}/analytics`

**Javob (asosiy):**

```json
{
  "total_payment": 14445802.87,
  "total_sales": 14445802.87,
  "payment_types": [
    { "id": 1, "payment_method": "Naqd pul", "total_amount": 13289000 },
    { "id": 2, "payment_method": "Uzcard", "total_amount": 880000 },
    { "id": 5, "payment_method": "Qarz", "total_amount": 276802.87 }
  ],
  "total_incomes": 2020000,
  "total_expenses": 25000,
  "expenses_by_payment_type": [],
  "incomes_by_payment_type": [],
  "current_amount_by_payment_type": [
    { "payment_method": "Naqd pul", "total_amount": 15284000 }
  ],
  "total_current_amount": 15284000,
  "expected_amount": 15284000,
  "shift_orders_count": 7,
  "shift_returns_total": 769614.96,
  "shift_avg_check": 2063686.12
}
```

**UI mapping (web «Kassa smenalari»):**

| UI | API |
|----|-----|
| **JAMI SAVDO** | `total_payment` |
| Naqd / Uzcard / Humo / Qarz / … | `payment_types[]` |
| **Sotilgan cheklar soni** | `shift_orders_count` |
| **KASSA NAQD QOLDIG‘I** | `current_amount_by_payment_type` da **Naqd** qatori |
| **Qaytarishlar** | `shift_returns_total` |
| **Kassa kirim** | `total_incomes` |
| **Kassa chiqim** | `total_expenses` |
| **O‘rtacha chek** | `shift_avg_check` |
| Yopishda kutilayotgan summa | `expected_amount` |

**Yuklash tartibi:** parallel `info` + `analytics`.

---

## 5. Tezkor kirim (kassaga naqd)

Web: yashil **Tezkor kirim** → `POST /api/incomes`

### 5.1 Forma dropdownlari

```http
GET /api/v1/incomes?from=2026-05-16&to=2026-05-16
```

**Javob:** `paymentTypes`, `incomeCategories` (va `incomes` ro‘yxati).

### 5.2 Saqlash

```http
POST /api/v1/incomes
Content-Type: application/json
```

```json
{
  "price": 2020000,
  "payment_type_id": 1,
  "income_category_id": 2,
  "note": "Kassaga kirim",
  "cash_register_log_id": 45,
  "customer_id": null
}
```

| Maydon | Majburiy |
|--------|----------|
| `price` | Ha |
| `payment_type_id` | Ha |
| `cash_register_log_id` | Ha (ochiq smena) |
| `income_category_id` | Yo‘q |
| `note` / `name` | Yo‘q |
| `customer_id` | Yo‘q (mijoz balansiga bo‘linishda) |

**Keyin:** `GET .../cash-register-shifts/{logId}/analytics` yangilang.

---

## 6. Tezkor chiqim (kassadan chiqim)

Web: sariq **Tezkor chiqim** → `POST /api/expenses`

### 6.1 Forma dropdownlari

```http
GET /api/v1/expenses?from=2026-05-16&to=2026-05-16
```

**Javob:** `paymentTypes`, `expenseCategories`.

### 6.2 Saqlash

```http
POST /api/v1/expenses
Content-Type: application/json
```

```json
{
  "price": 25000,
  "payment_type_id": 1,
  "expense_category_id": 3,
  "note": "Kassadan chiqim",
  "cash_register_log_id": 45,
  "customer_id": null
}
```

**Keyin:** analytics qayta yuklang.

---

## 7. Kassa yopish (smenadan)

Web: qizil **Kassa yopish** → `POST /cash-register-close-from-detail`

```http
POST /api/v1/sales/cash-register-shifts/close
Content-Type: application/json
```

```json
{
  "register_log_id": 45,
  "closingAmount": 15284000,
  "closingTime": "2026-05-16T20:00:00.000Z",
  "note": ""
}
```

**Javob:**

```json
{
  "success": true,
  "message": "Kassa muvaffaqiyatli yopildi"
}
```

**Kutilayotgan summa** (forma ochilishida):

```http
GET /api/v1/sales/register-amount/{cashRegisterId}
```

yoki `analytics.expected_amount` dan `closingAmount` ni to‘ldiring.

**Shart:** `info.can_close === true` (ochuvchi yoki admin).

---

## 8. Chop etish va to‘liq hisobot

### 8.1 Chop etish (mobil)

Web client-side: `info` + `analytics` dan HTML yig‘adi va `print()` chaqiradi.

Mobil: xuddi shu JSON dan PDF/thermal printer — alohida backend shart emas.

### 8.2 To‘liq hisobot (web sahifa ekvivalenti)

```http
GET /api/v1/sales/cash-register-shifts/{logId}/orders
GET /api/v1/sales/cash-register-shifts/{logId}/expenses
GET /api/v1/sales/cash-register-shifts/{logId}/incomes
```

Web hisobotlar: `/reports/register-logs/{logId}` — mobil uchun yuqoridagi 3 endpoint + analytics yetarli.

---

## 9. Barcha endpointlar jadvali

| Method | URL | Web | Vazifa |
|--------|-----|-----|--------|
| GET | `/api/v1/sales/cash-registers` | `/cash-registers` | Kassalar + ochiq smena |
| GET | `/api/v1/sales/cash-registers/{id}/sales-template` | `/cash-register-sales-template-id/{id}` | Chek shablon |
| POST | `/api/v1/sales/cash-registers/open-close` | `/cash-register-open-close` | open / close / enroll / leave |
| GET | `/api/v1/sales/cash-registers/{id}/balance` | `/cash-register-total-sales-balance/{id}` | Qisqa balans |
| GET | `/api/v1/sales/register-amount/{id}` | `/get-register-amount/{id}` | Kutilayotgan yopilish |
| GET | `/api/v1/sales/cash-register-shifts/{logId}/info` | `/cash-register-detail/{id}/info` | Smena header |
| GET | `/api/v1/sales/cash-register-shifts/{logId}/analytics` | `.../analytics` | Smena hisoboti |
| GET | `/api/v1/sales/cash-register-shifts/{logId}/orders` | `.../orders` | Cheklar ro‘yxati |
| GET | `/api/v1/sales/cash-register-shifts/{logId}/expenses` | `.../expenses` | Xarajatlar |
| GET | `/api/v1/sales/cash-register-shifts/{logId}/incomes` | `.../incomes` | Kirimlar |
| POST | `/api/v1/sales/cash-register-shifts/close` | `/cash-register-close-from-detail` | Smenadan yopish |
| GET | `/api/v1/incomes?from=&to=` | `/api/incomes?from=&to=` | Tezkor kirim forma |
| POST | `/api/v1/incomes` | `POST /api/incomes` | Tezkor kirim saqlash |
| GET | `/api/v1/expenses?from=&to=` | `/api/expenses?from=&to=` | Tezkor chiqim forma |
| POST | `/api/v1/expenses` | `POST /api/expenses` | Tezkor chiqim saqlash |

---

## Flutter — oqim

```dart
// 1. Kassalar
final registers = await dio.get('/api/v1/sales/cash-registers');

// 2. Ochish
await dio.post('/api/v1/sales/cash-registers/open-close', data: {
  'id': registerId,
  'status': 'open',
  'openingAmount': 0,
  'openingTime': DateTime.now().toIso8601String(),
});

// 3. Smena ekrani
final logId = register['register_log_id'];
final info = await dio.get('/api/v1/sales/cash-register-shifts/$logId/info');
final analytics = await dio.get('/api/v1/sales/cash-register-shifts/$logId/analytics');

// 4. Tezkor kirim
await dio.post('/api/v1/incomes', data: {
  'price': 100000,
  'payment_type_id': 1,
  'cash_register_log_id': logId,
});
```

---

## Xatoliklar

| HTTP | Sabab |
|------|--------|
| 401 | Token yo‘q |
| 422 | Kassa allaqachon ochiq / parol noto‘g‘ri / smena yopiq |
| 403 | Smenaga kirim/chiqim qo‘shishga ruxsat yo‘q |
