# Dastur imkoniyatlari — qanday ma'lumotlar talab qilinadi

Ushbu hujjatda **har bir ekran** uchun yozilgan: dastur nima ko‘rsatadi, qaysi API dan ma’lumot oladi va javob **qanday ko‘rinishda** bo‘lishi kerak. Backend shu formatga moslashtirsa, ilova to‘liq ishlaydi.

**Umumiy:** Barcha so‘rovda `Authorization: Bearer {token}`. Super admin uchun `X-Company-Id: {company_id}`. Base: `https://nasiyapos.uz`, prefix: `/api/v1`.

---

## 1. ASOSIY OYNA (Dashboard)

**Ekranda ko‘rsatiladi:**
- Bugungi jami savdo (UZS)
- Bugungi xarajat (UZS)
- To‘lov turlari bo‘yicha summalar (Naqd, Karta, Payme, Qarz va h.k.)
- Eng ko‘p sotilgan mahsulotlar ro‘yxati (nom, sotilgan dona)

**Dastur qaysi API ni chaqiradi:**

| So‘rov | Maqsad |
|--------|--------|
| **GET** `/api/v1/dashboard?date=YYYY-MM-DD` | Barcha asosiy statistikalar |
| **GET** `/api/v1/dashboard/top-selling-products` | Agar dashboard da bugungi top mahsulotlar bo‘sh bo‘lsa — oylik top mahsulotlar |

**Javob qanday bo‘lishi kerak (GET /dashboard):**

```json
{
  "basicData": {
    "todaySales": 1500000,
    "todayExpenses": 200000
  },
  "todayPaymentTypes": [
    { "id": 1, "payment_method": "Naqd pul", "total_amount": 800000 },
    { "id": 2, "payment_method": "Qarz", "total_amount": 700000 }
  ],
  "sellersReport": [
    { "seller_id": 6, "seller_name": "Azizbek", "order_count": 12, "total_sales": 500000 }
  ],
  "dailyProductsSold": [
    { "name": "Non", "quantity": 25 },
    { "name": "Suv", "quantity_sold": 20 }
  ]
}
```

**Kerakli maydonlar (kalit nomlari):**

| Dasturda ko‘rsatiladi | API da kerak (bittasi bo‘lsa yetadi) |
|------------------------|--------------------------------------|
| Bugungi savdo | `basicData.todaySales`, `todayIncomes`, `basicData.total_sales` |
| Bugungi xarajat | `basicData.todayExpenses`, `basicData.today_expenses` |
| To‘lov turlari | `todayPaymentTypes` — har elementda: `id`, `payment_method` (nom), `total_amount` (son) |
| Sotuvchilar (Menu uchun ham) | `sellersReport` — har elementda: `seller_id`, `seller_name`, `order_count`, `total_sales` |
| Top mahsulotlar | `dailyProductsSold` — son (0) yoki ro‘yxat; ro‘yxatda: `name` yoki `product_name`, `quantity` yoki `quantity_sold` |
| Valyuta | `currency` yoki `currency_symbol` yoki `currencySymbol` (root yoki basicData ichida). Masalan: `"UZS"`, `"$"`, `"USD"`. Berilmasa dastur "UZS" ko‘rsatadi. |

---

## 2. MAHSULOTLAR OYNASI (Katalog)

**Ekranda ko‘rsatiladi:**
- Mahsulotlar ro‘yxati: **nom**, **narx**, **barcode**, **miqdor**, **birlik**, **kategoriya**
- Kategoriyalar tab: kategoriyalar ro‘yxati
- Yangi mahsulot qo‘shish / tahrirlash

**Dastur qaysi API ni chaqiradi:**

| So‘rov | Maqsad |
|--------|--------|
| **POST** `/api/v1/products/list` | Mahsulotlar ro‘yxati |
| **GET** `/api/v1/products/categories` | Kategoriyalar |
| **GET** `/api/v1/products/supporting-data` | Birliklar (dona, kg) va agar kategoriyalar bo‘sh bo‘lsa — kategoriyalar |
| **POST** `/api/v1/products` | Yangi mahsulot qo‘shish |
| **POST** `/api/v1/products/{id}/edit` | Mahsulot tahrirlash |
| **DELETE** `/api/v1/products/{id}` | Mahsulot o‘chirish |

**Mahsulotlar ro‘yxati (POST /products/list):**

- **Body:** `{ "rowLimit": 5000, "rowOffset": 0 }`
- **Javob:** Ro‘yxat **datarows** yoki **products** yoki **data** (to‘g‘ridan-to‘g‘ri list) da bo‘lishi kerak.

**Har bir mahsulot ob'ektida dastur quyidagilarni ishlatadi:**

| Ekranda ko‘rinishi | API kalitlari (bittasi bo‘lsa yetadi) |
|--------------------|----------------------------------------|
| ID | `id` |
| Nom | `title`, `name`, `product_name` |
| Sotish narxi | `selling_price`, `sell_price`, `price` |
| Kirim narxi | `purchase_price`, `cost_price` |
| Miqdor | `product_quantity`, `quantity`; yoki `variants[0].availableQuantity` |
| Barcode | `barcode`; yoki `variants[0].bar_code` |
| SKU | `sku`; yoki `variants[0].sku` |
| Birlik | `unit`, `unit_name`, `measure` (dona, kg) |
| Kategoriya | `category_name` yoki `category` (ob'ektda `name`) |
| Rasm | `imageURL`, `image`, `image_url` |

**Yangi mahsulot qo‘shish (POST /products) — backend talablari:**

- **name** yoki **title** (string) — majburiy  
- **type** yoki **product_type** (string, masalan `"standard"`) — majburiy  
- **unit** yoki **unit_id** (integer) — majburiy, birlik id (1 = dona, 2 = kg)  
- **sell_price**, **quantity** (son)  
- **purchase_price**, **category_id**, **sku**, **barcode**, **description** — ixtiyoriy  

**Kategoriyalar (GET /products/categories):**

- Javob: ro‘yxat **data** yoki **categories** yoki **datarows** da.
- Har bir elementda: **id** (son), **name** (yoki **title**, **category_name**).

**Supporting data (GET /products/supporting-data):**

- **units** — birliklar ro‘yxati: har birida **id**, **name** (yoki **shortname**).
- **categories** — ixtiyoriy; kategoriyalar bo‘sh bo‘lsa dastur shu yerdan oladi.

---

## 3. SOTUVLAR OYNASI (Savatcha)

**Ekranda ko‘rsatiladi:**
- Mahsulotlar ro‘yxati (savatchaga qo‘shish uchun)
- Savatchadagi mahsulotlar, narx, miqdor, jami
- Chek yopish (to‘lov turlari, chegirma, mijoz tanlash)

**Dastur qanday ma’lumot oladi:**
- **Mahsulotlar** — xuddi Katalog kabi: **POST** `/api/v1/products/list` (yuqoridagi format).
- To‘lov turlari — hozircha dastur ichida aniq (Naqd, Karta, Payme, Qarz). Kelajakda API dan ham olish mumkin.
- **Mijozlar** — Mijozlar ekranidagi API (sotuvda mijoz tanlash uchun).

Chek yopilganda tranzaksiya **hozircha faqat telefonda** (lokal) saqlanadi. Agar kelajakda serverga yuborish kerak bo‘lsa, backend da **sotuv/chek yaratish** endpoint i kerak bo‘ladi (POST body: mahsulotlar, to‘lovlar, mijoz_id, chegirma va h.k.).

---

## 4. TRANZAKSIYALAR OYNASI

**Ekranda ko‘rsatiladi:**
- Kun bo‘yicha cheklar ro‘yxati (sana, jami summa, to‘lov turlari)
- Chek batafsil: mahsulotlar, narxlar, to‘lovlar, mijoz

**Dastur qanday ma’lumot oladi:**
- **Hozircha** — faqat **lokal** (telefon xotirasida). API dan tranzaksiyalar ro‘yxati **chaqirilmaydi**.
- Agar kelajakda serverda saqlash kerak bo‘lsa, backend dan quyidagilar kerak bo‘ladi:
  - **GET** tranzaksiyalar ro‘yxati (sana bo‘yicha filtrlash)
  - **POST** yangi tranzaksiya (chek) yuborish
  - Javobda: `receiptId`, `dateTime`, `totalSum`, `payments`, `productRows`, `clientId` va h.k.

---

## 5. MENU OYNASI

**Ekranda ko‘rsatiladi:**
- Foydalanuvchi ismi (yoki sotuvchilar ro‘yxatidan birinchi)
- Sotuvchilar ro‘yxati (ism, savdolar soni)
- Logout tugmasi
- Ichki oynalar: Mijozlar, Xarajatlar, Kirimlar, Yangi tovar va b.

**Dastur qaysi API ni chaqiradi:**

| So‘rov | Maqsad |
|--------|--------|
| **GET** `/api/v1/dashboard` | **sellersReport** — sotuvchilar ro‘yxati (Menu da ko‘rsatiladi) |
| **GET** `/api/v1/user` | Sotuvchilar bo‘sh bo‘lsa — ism ko‘rsatish uchun |
| **POST** `/api/v1/logout` | Chiqish |

**Kerakli ma’lumotlar:**
- **sellersReport** — Dashboard javobida (yuqorida yozilgan): `seller_id`, `seller_name`, `order_count`, `total_sales`.
- **GET /user** javobida: `first_name`, `last_name` (yoki `name`, `email`) — Menu da ism uchun.

---

## 6. MIJOZLAR OYNASI (Menu orqali)

**Ekranda ko‘rsatiladi:**
- Mijozlar ro‘yxati: ism, telefon, manzil
- Yangi mijoz qo‘shish / tahrirlash
- Mijoz qarzlari (agar API bersa)

**Dastur qaysi API ni chaqiradi:**

| So‘rov | Maqsad |
|--------|--------|
| **GET** `/api/v1/contacts/customers-list` | Mijozlar ro‘yxati |
| **POST** `/api/v1/contacts/customers/store` | Yangi mijoz |
| **POST** `/api/v1/contacts/customers/{id}` | Mijoz tahrirlash |
| **DELETE** `/api/v1/contacts/customers/{id}` | Mijoz o‘chirish |
| **POST** `/api/v1/contacts/customers/{id}/debts` | Mijoz qarzlari ro‘yxati |

**Mijozlar ro‘yxati (GET /contacts/customers-list):**
- Javob: ro‘yxat **customers** yoki **data** yoki **datarows** da.
- Har bir mijozda: **id**, **first_name**, **last_name** (yoki **name**), **phone_number** (yoki **phone**), **address**.

**Yangi mijoz (POST /contacts/customers/store):**
- Body: **first_name** (majburiy), **last_name**, **phone_number**, **address**, **customer_group** (majburiy — son, masalan 1).

**Qarzlari (POST /contacts/customers/{id}/debts):**
- Javob: **customer_debts** yoki **data** yoki **debts** — ro‘yxat; har elementda **amount**, **receipt_id**, **date_time** (yoki **created_at**).

---

## 7. XARAJATLAR OYNASI (Menu orqali)

**Ekranda ko‘rsatiladi:**
- Xarajatlar ro‘yxati: sana, nom, summa
- Yangi xarajat qo‘shish / o‘chirish

**Dastur qaysi API ni chaqiradi:**

| So‘rov | Maqsad |
|--------|--------|
| **GET** `/api/v1/expenses?from=YYYY-MM-DD&to=YYYY-MM-DD` | Xarajatlar ro‘yxati |
| **POST** `/api/v1/expenses` | Yangi xarajat |
| **DELETE** `/api/v1/expenses/{id}` | Xarajat o‘chirish |

**Xarajatlar ro‘yxati:**
- Javob: **expenses** yoki **data** — list.
- Har bir elementda: **id**, **date** (yoki **created_at**), **name**, **price** (yoki **amount**, **amountUzs**).

**Yangi xarajat (POST /expenses):**
- Body: **name**, **price** (son), **date** (YYYY-MM-DD). Ixtiyoriy: **payment_type_id**, **expense_category_id**, **note**.

---

## 8. LOGIN

**Dastur qaysi API ni chaqiradi:**
- **POST** `/api/v1/login`
- Body: `email`, `password`, `company_id`
- Javob: **token** (yoki **data.token**) — string. Shundan keyin barcha so‘rovda `Authorization: Bearer {token}` yuboriladi.

---

## Qisqacha jadval — qaysi ekran qaysi endpoint ni so‘raydi

| Ekran | Asosiy so‘rovlar | Javobda kerak bo‘lgan asosiy narsalar |
|-------|-------------------|---------------------------------------|
| **Asosiy** | GET /dashboard, GET /dashboard/top-selling-products | basicData.todaySales, todayExpenses, todayPaymentTypes, sellersReport, dailyProductsSold |
| **Mahsulotlar** | POST /products/list, GET /products/categories, GET /products/supporting-data, POST /products | datarows/products/data, har mahsulotda id, title, selling_price, product_quantity, category_name, variants[0].bar_code; categories: id, name; units: id, name |
| **Sotuvlar** | POST /products/list (mahsulotlar), GET /contacts/customers-list (mijoz tanlash) | Mahsulotlar va mijozlar yuqoridagi formatda |
| **Tranzaksiyalar** | — (lokal) | Kelajakda: GET tranzaksiyalar, POST tranzaksiya |
| **Menu** | GET /dashboard (sellersReport), GET /user, POST /logout | sellersReport: seller_id, seller_name, order_count, total_sales; user: first_name, last_name |
| **Mijozlar** | GET /contacts/customers-list, POST /contacts/customers/store, POST /contacts/customers/{id}/debts | customers: id, first_name, last_name, phone_number, address; debts: amount, receipt_id, date_time |
| **Xarajatlar** | GET /expenses, POST /expenses, DELETE /expenses/{id} | expenses: id, date, name, price |
| **Login** | POST /login | token |

Backend shu ekranlar va jadvaldagi formatlarga moslashtirsa, dastur to‘liq ishlaydi. Biror endpoint boshqa kalit ishlatsa (masalan `access_token`, `product_title`), yoki validatsiya boshqacha bo‘lsa (masalan **unit** integer emas deb xato bersa), ilovada xato yoki bo‘sh ko‘rinish paydo bo‘ladi — shuning uchun API ni ushbu hujjatdagi ko‘rinishga yaqinlashtirish kerak.
