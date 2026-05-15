# API va dastur talablari — taqqoslash

**API bazasi:** `https://nasiyapos.uz`  
**Prefix:** `/api/v1`  
**Auth:** `Authorization: Bearer {token}`, ixtiyoriy `X-Company-Id: {company_id}`

Dastur quyidagi endpoint'lardan ma'lumot oladi. Har biri uchun: **qanday so'rov yuboriladi**, **javobda qanday struktura va maydonlar kutamiz**, **agar API boshqa nom bersa** qaysi variantlarni qo‘llaymiz.

---

## 1. Login

| Narsa | Qiymat |
|--------|--------|
| **So'rov** | `POST /api/v1/login` |
| **Body** | `email`, `password`, `company_id` |
| **Kutiladigan javob** | `token` (yoki `data.token`) — string |

**Dasturda yetishmayotgani:** Javobda `token` bo‘lmasa login ishlamaydi. Agar server `access_token` yoki boshqa kalit bersa, dasturda shu kalitni qo‘llash kerak.

---

## 2. Mahsulotlar ro‘yxati (Products list)

| Narsa | Qiymat |
|--------|--------|
| **So'rov** | `POST /api/v1/products/list` |
| **Body** | `{ "rowLimit": 5000, "rowOffset": 0 }` |
| **Ro‘yxat qayerda** | Javobda ro‘yxat **bitta** quyidagilardan bo‘lishi kerak: `datarows`, `products`, `data` (to‘g‘ridan-to‘g‘ri list). Yoki `data` ichida: `datarows`, `products`, `data`, `items`. |

### Har bir mahsulot ob'ektida dastur quyidagilarni ishlatadi

| Dasturda ko‘rinishi | **Asosiy kalit (API qaytarsa)** | Qo‘shimcha qabul qilinadigan kalitlar |
|---------------------|----------------------------------|---------------------------------------|
| **ID** | `id` | — |
| **Nom** | `name` | `product_name`, `title`, `product_title` |
| **Sotish narxi** | `sell_price` | `selling_price`, `price`, `sale_price`, `price_uzs`, `priceUzs` |
| **Kirim narxi** | `purchase_price` | `cost_price`, `buying_price`, `costPriceUzs`, `cost_uzs` |
| **Miqdor** | `quantity` | `stock_quantity`, `qty`, `stock`, `initial_quantity`, `initialQuantity` |
| **Barcode** | `barcode` | `barcode_number` |
| **SKU** | `sku` | `sku_code` |
| **Birlik (dona/kg)** | `unit` | `unit_name`, `measure`, `unit_type` |
| **Kategoriya** | `category` (ob'ektda `name`) yoki string | `category_name`, `category_id` |
| **Rasm** | `image` / `image_url` | `imageUrl`, `photo` |
| **Pachka miqdori** | `quantity_per_pack` | `quantityPerPack`, `pack_quantity`, `quantity_in_pack` |
| **Pachka sotish narxi** | `sell_price_per_pack` | `sellPricePerPack`, `price_per_pack` |
| **Pachka kirim narxi** | `cost_price_per_pack` | `costPricePerPack`, `purchase_price_per_pack` |
| **Tavsif** | `description` | — |

**Dasturimizga yetishmayotgan ma'lumotlar (agar API bermasa):**

- **`id`** — bo‘lmasa mahsulot ro‘yxatga kirmaydi.
- **Nom** — hech biri bo‘lmasa "—" ko‘rsatiladi.
- **Sotish narxi** — bo‘lmasa 0 ko‘rsatiladi.
- **Miqdor** — bo‘lmasa 0, barcode bo‘lmasa "—" ko‘rinadi.

API javobida mahsulotlar **`product`** ichida bo‘lsa (masalan `{ "product": { "id": 1, "name": "..." } }`) — dastur buni avtomatik qo‘llaydi.

---

## 3. Mijozlar ro‘yxati (Customers list)

| Narsa | Qiymat |
|--------|--------|
| **So'rov** | `GET /api/v1/contacts/customers-list` |
| **Ro‘yxat qayerda** | `customers`, `datarows`, yoki `data` (list). Yoki `data` ichida: `customers`, `datarows`, `data`, `items`. |

### Har bir mijoz ob'ektida

| Dasturda ko‘rinishi | **Asosiy kalit** | Qo‘shimcha kalitlar |
|---------------------|------------------|----------------------|
| **ID** | `id` | — |
| **Ism** | `first_name` + `last_name` | `firstName`, `lastName`; ikkalasi bo‘sh bo‘lsa `name` |
| **Telefon** | `phone_number` | `phone` |
| **Manzil** | `address` | — |

**Yetishmayotgani:** `id` bo‘lmasa mijoz ro‘yxatga kirmaydi.

---

## 4. Foydalanuvchi (User) — Menu’dagi ism

| Narsa | Qiymat |
|--------|--------|
| **So'rov** | `GET /api/v1/user` |
| **Kutiladigan** | Javobda yoki `data` ichida: **ism-familiya** yoki login. |

| Ko‘rsatilishi kerak | **Asosiy kalitlar** | Qo‘shimcha |
|---------------------|---------------------|------------|
| Sotuvchi ismi (Menu) | `first_name`, `last_name` | `firstName`, `lastName`; bo‘sh bo‘lsa `email` yoki `name` |

**Yetishmayotgani:** Hech biri bo‘lmasa dastur lokal "Sotuvchi" yozuvini ko‘rsatadi.

---

## 5. Dashboard (Asosiy ekran)

| Narsa | Qiymat |
|--------|--------|
| **So'rov** | `GET /api/v1/dashboard?date=Y-m-d` |
| **Ma'lumot qayerda** | `basicData` yoki `data` (Map). |

### basicData (yoki data) ichida

| Dasturda ishlatiladi | **Kalit** | Qo‘shimcha |
|----------------------|-----------|------------|
| Bugun jami savdo | `total_sales` | `today_total` |
| Bugun xarajatlar | `today_expenses` | `expensesUzs` |
| Savdolar soni | `transaction_count` | `sales_count` |
| To‘lov turlari ro‘yxati | `todayPaymentTypes` (list) yoki `res['todayPaymentTypes']` | — |

**todayPaymentTypes** har bir elementida: `type_id` / `typeId` / `id` / `payment_type`, `label` / `name`, `amount` / `amountUzs`.

**Eng ko‘p sotilgan mahsulotlar:**  
`GET /api/v1/dashboard/top-selling-products` — javobda `dailyProductsSold`, `data` yoki `top_products` (list). Har bir elementda: `name` / `product_name`, `quantity` / `quantity_sold` / `total_quantity`.

---

## 6. Kategoriyalar

| Narsa | Qiymat |
|--------|--------|
| **So'rov** | `GET /api/v1/products/categories` |
| **Ro‘yxat** | `data` yoki `categories` (list). Element string yoki ob'ekt; ob'ektda `name` yoki `title`. |

**Yetishmayotgani:** Kategoriya nomi bo‘lmasa u element o‘tkazib yuboriladi.

---

## 7. Xarajatlar

| Narsa | Qiymat |
|--------|--------|
| **So'rov** | `GET /api/v1/expenses?from=Y-m-d&to=Y-m-d` |
| **Ro‘yxat** | `expenses` yoki `data` (list). |

### Har bir xarajat ob'ektida

| Dasturda | **Kalit** | Qo‘shimcha |
|----------|-----------|------------|
| ID | `id` | — |
| Sana | `date` | `created_at` |
| Summa | `price` | `amountUzs`, `amount` |
| Nom (izoh) | `name` | — |

---

## 8. Qisqacha: API qanday ma'lumot bermasa dasturda yetishmaydi

| Endpoint | Yetishmasa nima bo‘ladi |
|----------|--------------------------|
| **Login** | `token` bo‘lmasa kirish ishlamaydi. |
| **Products list** | Ro‘yxat `datarows` / `products` / `data` da bo‘lmasa yoki har bir elementda `id` bo‘lmasa — mahsulotlar ko‘rinmaydi. Nom/narx/miqdor/barcode boshqa kalitda bo‘lsa, yuqoridagi “Qo‘shimcha kalitlar”ga qo‘shilsa dastur ishlaydi. |
| **Customers list** | Ro‘yxat `customers` / `data` / `datarows` da bo‘lmasa yoki elementda `id` bo‘lmasa — mijozlar ko‘rinmaydi. |
| **User** | `first_name`/`last_name` (yoki `email`/`name`) bo‘lmasa — Menu’da “Sotuvchi” ko‘rinadi. |
| **Dashboard** | `basicData`/`data` yoki ichidagi `total_sales`, `todayPaymentTypes` bo‘lmasa — asosiy ekran statistikasi 0 yoki bo‘sh. |
| **Categories** | `data`/`categories` bo‘lmasa yoki elementda `name`/`title` bo‘lmasa — kategoriyalar bo‘sh. |
| **Expenses** | `expenses`/`data` bo‘lmasa — xarajatlar ro‘yxati bo‘sh. |

---

## API javobini tekshirish

Backend’da yoki Postman/curl orqali:

1. **Login** qiling, `token` ni oling.
2. Header: `Authorization: Bearer {token}`, `X-Company-Id: {company_id}` (agar kerak bo‘lsa).
3. `POST /api/v1/products/list` body: `{"rowLimit": 10, "rowOffset": 0}` — javobning **birinchi darajadagi** kalitlarini va **bitta mahsulot** ob'ektidagi barcha kalitlarni yozing.
4. Xuddi shunday `GET /api/v1/contacts/customers-list` va `GET /api/v1/user` javoblarini ko‘ring.

Agar kalitlar ushbu hujjatdagi “Asosiy” yoki “Qo‘shimcha” ro‘yxatda bo‘lsa — dastur ularni ishlatadi. Ro‘yxatda yo‘q kalit (masalan `product_title`, `selling_price`) bo‘lsa — bu hujjatni backendga ko‘rsating va kerakli kalitlarni qo‘shing yoki dasturda yangi variant sifatida qo‘shamiz.
