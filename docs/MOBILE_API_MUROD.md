# Mobile App API (v1)

**Baza URL:** `https://your-domain.com` (masalan: `https://nasiyapos.uz`)  
**Prefix:** `/api/v1`  
**Auth:** `Authorization: Bearer {token}`  
**Ixtiyoriy:** `X-Company-Id: {company_id}` — super admin kompaniya tanlash uchun.

Barcha endpoint'lar **Bearer token** (Sanctum) bilan himoyalangan. Login: `POST /api/v1/login` — token olinganidan keyin har so'rovda header: `Authorization: Bearer {token}`.

---

## Mobile dastur talablari (taqqoslash)

Dastur quyidagi endpoint'lardan ma'lumot oladi. Har biri uchun: **qanday so'rov yuboriladi**, **javobda qanday struktura va maydonlar bor**, **mobile qaysi kalitlarni ishlatadi** (asosiy yoki qo'shimcha).

| Endpoint | Ro'yxat / asosiy ma'lumot qayerda | Muhim eslatma |
|----------|-----------------------------------|----------------|
| **Login** | Javobda `data.token` (yoki `token`) — string. Token bo‘lmasa login ishlamaydi. | Bizda: `data.token` |
| **Products list** | Ro'yxat: `datarows` (yoki `products`, `data`). Har bir elementda: `id`/`productID`, `title`/`name`, `selling_price`/`sell_price`, `purchase_price`, `product_quantity`/`quantity`, barcode (variant ichida). | Bizda: `datarows`, elementda `productID`, `title`, `selling_price`, `purchase_price`, `product_quantity`, `variants[].bar_code` |
| **Customers list** | Ro'yxat: `customers` (yoki `datarows`, `data`). Elementda: `id`, `first_name`, `last_name`, `phone_number`, `address`. | Bizda: `customers` |
| **User** | Ism: `first_name`, `last_name` (yoki `email`, `name`). Bo‘lmasa dastur "Sotuvchi" ko‘rsatadi. | Bizda: `success` obyektida `first_name`, `last_name`, `email` |
| **Dashboard** | `basicData` (yoki `data`): `todaySales` (bugun jami savdo), `todayExpenses`, `todayPaymentTypes` (list: `id`, `payment_method`/`name`, `total_amount`/`amount`). Eng ko‘p sotilgan: `dailyProductsSold` yoki `/dashboard/top-selling-products` — `product`, `total_sold`. | Bizda: `basicData.todaySales`, `basicData.todayExpenses`, `todayPaymentTypes[]`, `dailyProductsSold` (son), top-selling: `product`, `total_sold` |
| **Categories** | Ro'yxat: `data` yoki to‘g‘ridan-to‘g‘ri massiv. Elementda `name` yoki `title`. | Bizda: to‘g‘ridan-to‘g‘ri massiv `[{id, name}, ...]` |
| **Expenses** | Ro'yxat: `expenses` yoki `data`. Elementda: `id`, `created_at`/`date`, `price`/`amount`, `name`. | Bizda: `expenses`, har biri `id`, `created_at`, `price`, `name` |
| **Sales (sotuv)** | Mahsulotlar: `POST /api/v1/sales/products`. Chek yopish: `POST /api/v1/sales/store` (cart, payments, customer). To'lov turlari: `GET /api/v1/sales/payment-types`. Filiallar: `GET /api/v1/sales/branches`. | Mahsulot to'liq boshqaruv: Create (POST /products), Edit (POST /products/{id}/edit), list, delete. |

---

## Dastur imkoniyatlari va talablar (ekran bo‘yicha)

Har bir ekran uchun: nima ko‘rsatiladi, qaysi API chaqiriladi, javob qanday bo‘lishi kerak. Backend shu formatga moslasa, ilova to‘liq ishlaydi.

### 1. Asosiy oyna (Dashboard)

**Ko‘rsatiladi:** Bugungi jami savdo (UZS), bugungi xarajat, to‘lov turlari bo‘yicha summalar, eng ko‘p sotilgan mahsulotlar (nom, sotilgan dona), sotuvchilar hisoboti.

**API chaqiruvi:**

| So‘rov | Maqsad |
|--------|--------|
| GET `/api/v1/dashboard?date=YYYY-MM-DD` | Barcha asosiy statistikalar |
| GET `/api/v1/dashboard/top-selling-products` | Oylik top mahsulotlar (dashboard da bugungi top bo‘sh bo‘lsa) |

**Kutiladigan javob (GET /dashboard):** `basicData.todaySales`, `basicData.todayExpenses`, `todayPaymentTypes` (har elementda `id`, `payment_method`, `total_amount`), `sellersReport` (har elementda `seller_id`, `seller_name`, `order_count`, `total_sales`), `dailyProductsSold` — **dastur** son (0) yoki ro‘yxat kutadi; ro‘yxatda `name`/`product_name`, `quantity`/`quantity_sold`.

**Eslatma:** Hozirgi backend da `dailyProductsSold` **bitta son** (bugungi jami sotilgan dona). Bugungi “top mahsulotlar” ro‘yxati uchun dastur `dailyProductsSold` bo‘sh/son bo‘lsa `/dashboard/top-selling-products` dan oylik ro‘yxatni ishlatadi (unda `product`, `total_sold`).

---

### 2. Mahsulotlar oynasi (Katalog)

**Ko‘rsatiladi:** Mahsulotlar ro‘yxati (nom, narx, barcode, miqdor, birlik, kategoriya), kategoriyalar tab, yangi mahsulot / tahrirlash.

**API chaqiruvi:**

| So‘rov | Maqsad |
|--------|--------|
| POST `/api/v1/products/list` | Mahsulotlar ro‘yxati |
| GET `/api/v1/products/categories` | Kategoriyalar |
| GET `/api/v1/products/supporting-data` | Birliklar (dona, kg); kategoriyalar bo‘sh bo‘lsa shu yerdan |
| POST `/api/v1/products` | Yangi mahsulot qo‘shish |
| POST `/api/v1/products/{id}/edit` | Mahsulot tahrirlash |
| DELETE `/api/v1/products/{id}` | Mahsulot o‘chirish |

**Products/list:** Body `{ "rowLimit": 5000, "rowOffset": 0 }`. Javob: ro‘yxat `datarows` (yoki `products`/`data`). Har mahsulotda: `id`/`productID`, `title`/`name`, `selling_price`/`sell_price`, `purchase_price`, `product_quantity`/`quantity`, `variants[0].bar_code`, `unit_name`/`unit`, `productImage`/`image`, `category_name`/`category`.

**Yangi mahsulot (POST /products):** Dastur yuboradi: `name` yoki `title` (majburiy), `type`/`product_type` (majburiy), `unit`/`unit_id` (majburiy), `sell_price`, `quantity`, `purchase_price`, `category_id`, `sku`, `barcode`, `description` (ixtiyoriy). Backend da hozir boshqa maydonlar ham talab qilinishi mumkin — qabul qilishda `title`, `unit_id`, `product_type` va narx/quantity ni qo‘llab-quvvatlash yetarli.

**Categories:** Javob `data`/`categories`/`datarows` yoki to‘g‘ridan massiv; har elementda `id`, `name` (yoki `title`).

**Supporting-data:** `units` — har biri `id`, `name` (yoki `shortname`); `categories` ixtiyoriy.

---

### 3. Sotuvlar oynasi (Savatcha)

**Ko‘rsatiladi:** Mahsulotlar ro‘yxati (savatchaga qo‘shish), savatcha (narx, miqdor, jami), chek yopish (to‘lov turlari, chegirma, mijoz).

**Ma’lumot manbai:** Mahsulotlar — POST `/api/v1/products/list` (yuqoridagi format). Mijozlar — GET `/api/v1/contacts/customers-list`. To‘lov turlari hozircha dastur ichida; kelajakda API dan olish mumkin.

**Eslatma:** Chekni serverga yuborish uchun **POST /api/v1/sales/store** ishlatiladi (cart, payments, customer, grandTotal va b.) — hujjatda "Sales (sotuv)" bo‘limida batafsil.

---

### 4. Tranzaksiyalar oynasi

**Ko‘rsatiladi:** Kun bo‘yicha cheklar (sana, jami, to‘lov turlari), chek batafsil (mahsulotlar, to‘lovlar, mijoz).

**Hozircha:** Faqat **lokal** (telefon xotirasi); API dan tranzaksiyalar **chaqirilmaydi**. Kelajakda: GET tranzaksiyalar ro‘yxati (sana bo‘yicha), POST yangi tranzaksiya (chek) — javobda `receiptId`, `dateTime`, `totalSum`, `payments`, `productRows`, `clientId` va h.k.

---

### 5. Menu oynasi

**Ko‘rsatiladi:** Foydalanuvchi ismi (yoki sotuvchilar ro‘yxatidan birinchi), sotuvchilar ro‘yxati (ism, savdolar soni), Logout, ichki oynalar: Mijozlar, Xarajatlar, Kirimlar, Yangi tovar va b.

**API chaqiruvi:**

| So‘rov | Maqsad |
|--------|--------|
| GET `/api/v1/dashboard` | `sellersReport` — Menu da sotuvchilar ro‘yxati |
| GET `/api/v1/user` | Sotuvchilar bo‘sh bo‘lsa — ism ko‘rsatish |
| POST `/api/v1/logout` | Chiqish |

**Kerakli:** `sellersReport`: `seller_id`, `seller_name`, `order_count`, `total_sales`. User: `first_name`, `last_name` (yoki `name`, `email`). Bizda user `success` kalitida qaytadi.

---

### 6. Mijozlar oynasi

**Ko‘rsatiladi:** Mijozlar ro‘yxati (ism, telefon, manzil), yangi mijoz / tahrirlash, mijoz qarzlari (agar API bersa).

**API chaqiruvi:**

| So‘rov | Maqsad |
|--------|--------|
| GET `/api/v1/contacts/customers-list` | Mijozlar ro‘yxati |
| POST `/api/v1/contacts/customers/store` | Yangi mijoz |
| POST `/api/v1/contacts/customers/{id}` | Tahrirlash |
| DELETE `/api/v1/contacts/customers/{id}` | O‘chirish |
| POST `/api/v1/contacts/customers/{id}/debts` | Mijoz qarzlari |

**Customers-list:** Ro‘yxat `customers`/`data`/`datarows`; har mijozda `id`, `first_name`, `last_name` (yoki `name`), `phone_number`/`phone`, `address`.

**Yangi mijoz (store):** Body: `first_name` (majburiy), `last_name`, `phone_number`, `address`, `customer_group` (majburiy — son).

**Qarzlari (debts):** Javob `customer_debts`/`data`/`debts` — ro‘yxat; har elementda `amount`, `receipt_id`, `date_time`/`created_at`.

---

### 7. Xarajatlar oynasi

**Ko‘rsatiladi:** Xarajatlar ro‘yxati (sana, nom, summa), yangi xarajat / o‘chirish.

**API chaqiruvi:**

| So‘rov | Maqsad |
|--------|--------|
| GET `/api/v1/expenses?from=YYYY-MM-DD&to=YYYY-MM-DD` | Xarajatlar |
| POST `/api/v1/expenses` | Yangi xarajat |
| DELETE `/api/v1/expenses/{id}` | O‘chirish |

**Ro‘yxat:** `expenses`/`data`; har elementda `id`, `date`/`created_at`, `name`, `price`/`amount`.

**Yangi xarajat (POST):** Body: `name`, `price` (son), ixtiyoriy `date` (YYYY-MM-DD), `payment_type_id`, `expense_category_id`, `note`. Backend da `payment_type_id` va `expense_category_id` majburiy bo‘lishi mumkin — dastur ularni yuborishi yoki default qilishi kerak.

---

### 8. Login

**API:** POST `/api/v1/login`. Body: `email`, `password`, `company_id`. Javob: **token** (yoki `data.token`) — string. Keyingi barcha so‘rovda `Authorization: Bearer {token}`.

---

### Qisqacha jadval — ekran → endpoint

| Ekran | Asosiy so‘rovlar | Javobda kerak |
|-------|-------------------|---------------|
| **Asosiy** | GET /dashboard, GET /dashboard/top-selling-products | basicData.todaySales, todayExpenses, todayPaymentTypes, sellersReport, dailyProductsSold |
| **Mahsulotlar** | POST /products/list, GET/POST/DELETE /products/categories (list, add, edit, delete), GET /products/supporting-data, POST /products (create), POST /products/{id}/edit (edit), DELETE /products/{id} | categories: GET list, POST body name (add), POST {id} body name (edit), DELETE {id}. |
| **Sotuvlar** | POST /sales/products (sotuv mahsulotlari), GET /sales/payment-types, GET /sales/branches, POST /sales/set-branch, POST /sales/store (chek yopish), GET /contacts/customers-list | products + variants; payment-types; branches; store body: cart, payments, customer, grandTotal |
| **Receives (kirim)** | POST /receives/products (orderType: receiving), POST /receives/store (orderType: receiving, supplier), POST /receives/set-branch, GET /receives/payment-types, GET /receives/branches, POST /contacts/suppliers (yetkazib beruvchilar) | supplier o‘rniga customer; body da orderType: receiving, salesOrReceivingType: supplier |
| **Tranzaksiyalar** | — (lokal) | Kelajakda: GET/POST tranzaksiyalar |
| **Menu** | GET /dashboard (sellersReport), GET /user, POST /logout | sellersReport; user: first_name, last_name |
| **Mijozlar** | GET /contacts/customers-list, POST store, POST /{id}, POST /{id}/debts | customers; debts: amount, receipt_id, date_time |
| **Xarajatlar** | GET /expenses, POST /expenses, DELETE /expenses/{id} | expenses: id, date, name, price |
| **Login** | POST /login | token |

Backend shu formatga yaqin bo‘lsa, ilova to‘liq ishlaydi. Bitta endpoint boshqa kalit ishlatsa (masalan `access_token`, `product_title`) yoki validatsiya boshqacha bo‘lsa, dasturda xato yoki bo‘sh ko‘rinish paydo bo‘lishi mumkin — shuning uchun API ni ushbu hujjatdagi ko‘rinishga moslashtirish tavsiya etiladi.

---

## Company_id (kompaniya bo‘yicha filtrlash)

- **Oddiy foydalanuvchi** (staff/admin): token’dagi user’ning `company_id` si avtomatik session’ga yoziladi; **barcha** endpoint’lar (dashboard, contacts, products, expenses) faqat shu kompaniya ma’lumotlarini qaytaradi.
- **Super admin**: agar `X-Company-Id` header yuborilsa, ma’lumotlar shu kompaniya bo’yicha; yuborilmasa, scope qo‘yilmaydi (barcha kompaniyalar ko‘rinadi).
- Modellar (Customer, Supplier, CustomerGroup, Product, Expense va b.) `company_id` ustuni orqali avtomatik filtrlangan; controller’lar ham qo‘lda `company_id` ni ishlatadi.

---

## 0. Login (autentifikatsiya)

| Method | URL | Tavsif |
|--------|-----|--------|
| POST | `/api/v1/login` | Kirish. Body: `email`, `password`, `company_id` (oddiy user uchun majburiy). Javobda **token** `data.token` da beriladi. |

**Example — So'rov:**
```http
POST /api/v1/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "parol123",
  "company_id": 1
}
```

**Example — Javob (200):**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "token": "1|abc123...",
    "user": {
      "id": 5,
      "first_name": "Aziz",
      "last_name": "Sotuvchi",
      "email": "user@example.com",
      "is_admin": 0,
      "company_id": 1
    }
  }
}
```

**Mobile uchun:** Token ni `data.token` dan oling. Keyingi barcha so'rovlarda header: `Authorization: Bearer <data.token>`.

**Xato javoblari (422/401):** `success: false`, `message`, `errors` (validation) yoki `error_code` (masalan `INVALID_PASSWORD`, `ACCOUNT_DISABLED`).

---

## 1. Dashboard — barcha statistikalar

| Method | URL | Tavsif |
|--------|-----|--------|
| GET | `/api/v1/dashboard` | Barcha dashboard ma'lumotlari (basicData, barChartData, lineChartData, todayPaymentTypes, sellersReport, dailyProductsSold, todayIncomes, va b.) Query: `?date=Y-m-d` (ixtiyoriy). |
| GET | `/api/v1/dashboard/top-selling-products` | Oxirgi oy eng ko'p sotilgan 10 ta mahsulot. |

**Example — Dashboard so'rov:**
```http
GET /api/v1/dashboard?date=2025-03-07
Authorization: Bearer 1|abc123...
```

**Example — Dashboard javob (200):**
```json
{
  "basicData": {
    "todaySales": 1500000,
    "monthlySale": 45000000,
    "totalSale": 120000000,
    "totalReturn": 0,
    "todayProfit": 320000,
    "monthlyProfit": 9500000,
    "totalProfit": 28000000,
    "todayDebt": 200000,
    "monthlyDebt": 500000,
    "totalDebt": 1200000,
    "todayExpenses": 150000,
    "monthlyExpenses": 2100000
  },
  "todayPaymentTypes": [
    { "id": 1, "payment_method": "Naqd", "total_amount": 800000 },
    { "id": 2, "payment_method": "Terminal", "total_amount": 700000 }
  ],
  "dailyProductsSold": 42,
  "sellersReport": [
    { "seller_id": 5, "seller_name": "Aziz Sotuvchi", "order_count": 12, "total_sales": 1500000 }
  ],
  "barChartData": { "sales": [...], "expenses": [...] },
  "lineChartData": { "days": [...], "sales": [...] },
  "todayIncomes": 0,
  "totalProductsQuantity": 1250,
  "totalOrderValue": 120000000,
  "totalPurchaseValue": 85000000,
  "totalRemainingProductsCount": 380
}
```

**Example — Top selling products:**
```http
GET /api/v1/dashboard/top-selling-products
Authorization: Bearer 1|abc123...
```

**Javob (200):**
```json
[
  { "product": "Non", "total_sold": 156 },
  { "product": "Suv 1.5L", "total_sold": 89 }
]
```

---

## 2. Contacts (mijozlar, yetkazib beruvchilar, guruhlar)

### Mijozlar (add, edit, delete mavjud)
| Method | URL | Tavsif |
|--------|-----|--------|
| POST | `/api/v1/contacts/customers` | Mijozlar ro'yxati (sahifalash, qidiruv, filter). Body: `rowLimit`, `rowOffset`, `searchValue`, `columnKey`, `columnSortedBy`, `filtersData`, `debt_limit`, `debtCustomers`, `reminderWindow`, `onlyDebits` — ixtiyoriy. Javob: `datarows`, `count`, `totalDebt`. |
| GET | `/api/v1/contacts/customers-list` | Barcha mijozlar qisqa ro'yxati (dropdown va sh.k. uchun). Javob: `customers`. |
| **POST** | **`/api/v1/contacts/customers/store`** | **Mijoz qo'shish.** Body: `first_name` (majburiy), `last_name`, `email`, `company`, `tin_number`, `phone_number`, `address`, `customer_group` (majburiy). |

**Example — Mijozlar ro'yxati (customers-list):**
```http
GET /api/v1/contacts/customers-list
Authorization: Bearer 1|abc123...
```

**Javob (200):**
```json
{
  "customers": [
    {
      "id": 1,
      "first_name": "Jamol",
      "last_name": "Mijoz",
      "email": "jamol@mail.uz",
      "phone_number": "+998901234567",
      "address": "Toshkent, Chilonzor"
    }
  ]
}
```

**Mobile uchun:** Ism = `first_name` + `last_name`; telefon = `phone_number`; manzil = `address`.
| GET | `/api/v1/contacts/customers/{id}` | Bitta mijoz ma'lumotlari. Javob: `customer`. |
| **POST** | **`/api/v1/contacts/customers/{id}`** | **Mijoz tahrirlash.** Body: `first_name`, `last_name`, `customer_group`, va b. |
| **DELETE** | **`/api/v1/contacts/customers/{id}`** | **Mijoz o'chirish.** Agar buyurtmalarda ishlatilgan bo'lsa o'chirilmaydi. |
| GET | `/api/v1/contacts/customer-debt-count` | Qarzdor mijozlar soni. |
| POST | `/api/v1/contacts/customers/{id}/balance-transactions` | Mijoz balans harakatlari. |
| POST | `/api/v1/contacts/customers/{id}/debts` | Mijoz qarzlari (customer_debts). |

### Yetkazib beruvchilar
| Method | URL | Tavsif |
|--------|-----|--------|
| POST | `/api/v1/contacts/suppliers` | Yetkazib beruvchilar ro'yxati. Body: `columnKey`, `columnSortedBy`, `rowLimit`, `rowOffset`, `reqType` (ixtiyoriy). Javob: `datarows`, `count`. |
| GET | `/api/v1/contacts/suppliers/{id}` | Bitta yetkazib beruvchi. Javob: `supplierData`. |

### Mijoz guruhlari
| Method | URL | Tavsif |
|--------|-----|--------|
| GET | `/api/v1/contacts/groups` | Barcha mijoz guruhlari (qisqa). |
| POST | `/api/v1/contacts/groups-list` | Mijoz guruhlari ro'yxati (sahifalash bilan). |
| GET | `/api/v1/contacts/customer-groups` | Dropdown uchun guruhlar. Javob: `customerGroups`. |

---

## 3. Products — to'liq mahsulotlar (add, edit, delete mavjud)

| Method | URL | Tavsif |
|--------|-----|--------|
| GET | `/api/v1/products` | Mahsulotlar ro'yxati (oddiy, pagination). Query: `limit`, `offset`, `search`. |
| POST | `/api/v1/products/list` | To'liq ro'yxat (sahifadagi kabi): filter, qidiruv, sahifalash. Body: `rowLimit`, `rowOffset`, `searchValue`, `columnKey`, `columnSortedBy`, `filtersData`, `showZeroStock`, `reqType`. Javob: `datarows`, `count`, `totalQuantity`. |
| GET | `/api/v1/products/supporting-data` | Mahsulot uchun yordamchi ma'lumotlar: brands, categories, groups, taxes, branches, units. |

**Example — Mahsulotlar ro'yxati (products/list):**
```http
POST /api/v1/products/list
Authorization: Bearer 1|abc123...
Content-Type: application/json

{
  "rowLimit": 10,
  "rowOffset": 0
}
```

**Javob (200):**
```json
{
  "datarows": [
    {
      "productID": 1,
      "title": "Non",
      "description": null,
      "category_id": 2,
      "productImage": "/uploads/products/non.jpg",
      "unit_name": "dona",
      "purchase_price": 2000,
      "selling_price": 3000,
      "product_quantity": 50,
      "variants": [
        {
          "id": 1,
          "bar_code": "4601234567890",
          "newBarcode": "4601234567890",
          "sku": "NON-001",
          "selling_price": 3000,
          "purchase_price": 2000,
          "availableQuantity": 50
        }
      ]
    } 
  ],
  "count": 1,
  "totalQuantity": 50
}
```

**Mobile uchun mapping:** `id` ← `productID`, `name` ← `title`, `sell_price` ← `selling_price`, `purchase_price` ← `purchase_price`, `quantity` ← `product_quantity`, `barcode` ← `variants[0].bar_code` yoki `variants[0].newBarcode`, `image` ← `productImage`, `unit` ← `unit_name`. **Dona / pachka:** variantda `units_per_package` (pachkadagi dona), `package_selling_price`, `package_purchase_price` — agar mavjud bo‘lsa mahsulotni dona yoki pachka sifatida sotish mumkin.
| GET | `/api/v1/products/{id}` | Bitta mahsulot (id bo'yicha). |
| GET | `/api/v1/products/{id}/edit-data` | Mahsulot tahrir uchun to'liq ma'lumot. |
| GET | `/api/v1/products/{id}/details` | Mahsulot batafsil. |
| POST | `/api/v1/products` | Yangi mahsulot qo'shish. |
| **POST** | **`/api/v1/products/{id}/edit`** | **Mahsulot tahrirlash.** Body: name, description, category, brand, group, unit, type, taxID, sallingPrice, sku, barcode, variantDetails (variant uchun). |
| **DELETE** | **`/api/v1/products/{id}`** | **Mahsulot o'chirish (soft delete).** |

#### Mahsulot yaratish (Create) — POST /api/v1/products

**Body:** `name` (majburiy), `type` (0=standard, 1=variant), `unit` (majburiy), `category`, `brand`, `group`, `taxID` (no-tax / default-tax / id), `sallingPrice`, `receivingPrice`, `sku`, `barcode`, `description`. **Pachka (ixtiyoriy):** `unitsPerPackage` (pachkada nechta dona), `packageSellingPrice`, `packagePurchasePrice`. Variant uchun: `variants` massivi (har elementda `unitsPerPackage`, `packageSellingPrice`, `packagePurchasePrice` ham bo‘lishi mumkin).

**Example:** `{"name": "Non", "type": 0, "unit": 1, "category": 2, "taxID": "no-tax", "sallingPrice": 3000, "barcode": "4601234567890"}` → Javob: `{ "success": true, "data": { ... } }`

#### Mahsulot tahrirlash (Edit) — POST /api/v1/products/{id}/edit

**Body:** `name`, `description`, `category`, `brand`, `group`, `unit`, `type`, `taxID`, `image` (yoki "DELETE"). Standard: `sallingPrice`, `sku`, `barcode`, `reorder`, **`unitsPerPackage`** (pachkada dona), **`packageSellingPrice`**, **`packagePurchasePrice`**. Variant: `variantDetails` massivi (har elementda pachka maydonlari ham).

---

### 3.1 Product Categories (kategoriyalar — olish, qo'shish, tahrirlash, o'chirish)

| Method | URL | Tavsif |
|--------|-----|--------|
| GET | `/api/v1/products/categories` | Barcha kategoriyalar ro'yxati. |
| POST | `/api/v1/products/categories` | Kategoriya qo'shish. Body: `name` (majburiy). |
| GET | `/api/v1/products/categories/{id}` | Bitta kategoriya. |
| POST | `/api/v1/products/categories/{id}` | Kategoriya tahrirlash. Body: `name`. |
| DELETE | `/api/v1/products/categories/{id}` | Kategoriya o'chirish. Mahsulotda ishlatilgan bo'lsa o'chirilmaydi. |

#### Kategoriyalar ro'yxati — GET /api/v1/products/categories

```http
GET /api/v1/products/categories
Authorization: Bearer 1|abc123...
```

**Javob (200):** to‘g‘ridan-to‘g‘ri massiv
```json
[
  { "id": 1, "name": "Oziq-ovqat", "created_at": "2025-01-01 00:00:00" },
  { "id": 2, "name": "Ichimliklar", "created_at": "2025-01-01 00:00:00" }
]
```

#### Kategoriya qo'shish — POST /api/v1/products/categories

```http
POST /api/v1/products/categories
Authorization: Bearer 1|abc123...
Content-Type: application/json

{ "name": "Yangi kategoriya" }
```

**Javob (201):** `{ "message": "Category successfully saved" }`  
**Xato (422):** `name` bo'sh bo'lsa validatsiya xatosi.

#### Bitta kategoriya — GET /api/v1/products/categories/{id}

**Javob (200):** `{ "id": 1, "name": "Oziq-ovqat", ... }`

#### Kategoriya tahrirlash — POST /api/v1/products/categories/{id}

```http
POST /api/v1/products/categories/2
Authorization: Bearer 1|abc123...
Content-Type: application/json

{ "name": "Ichimliklar (tahrirlangan)" }
```

**Javob (201):** `{ "message": "Category successfully updated" }`

#### Kategoriya o'chirish — DELETE /api/v1/products/categories/{id}

```http
DELETE /api/v1/products/categories/3
Authorization: Bearer 1|abc123...
```

**Javob (201):** `{ "message": "Category successfully deleted" }`  
**Agar kategoriya mahsulotda ishlatilgan bo'lsa (200):** `{ "message": "Category in use, you cannot delete..." }`

### 3.2 Product Units (o'lchov birliklari — add, edit, delete mavjud)

| Method | URL | Tavsif |
|--------|-----|--------|
| POST | `/api/v1/products/units/list` | Birliklar ro'yxati (sahifalash). Body: `columnKey`, `columnSortedBy`, `rowLimit`, `rowOffset`, `reqType`. Javob: `datarows`, `count`. |
| **POST** | **`/api/v1/products/units`** | **Birlik qo'shish.** Body: `name`, `shortname`. |
| GET | `/api/v1/products/units/{id}` | Bitta birlik. |
| **POST** | **`/api/v1/products/units/{id}`** | **Birlik tahrirlash.** Body: `name`, `shortname`. |
| **DELETE** | **`/api/v1/products/units/{id}`** | **Birlik o'chirish.** Mahsulotda ishlatilgan bo'lsa o'chirilmaydi. |

---

## 3.3 Sales (sotuv) — /sales dagi barcha imkoniyatlar

Web sahifadagi **/sales** (sotuv, savatcha, chek yopish) bilan bir xil: mahsulotlar ro'yxati (barcode qidiruv bilan), to'lov turlari, filial tanlash, chek/buyurtma yuborish.

| Method | URL | Tavsif |
|--------|-----|--------|
| POST | `/api/v1/sales/products` | Sotuv uchun mahsulotlar (savatchaga qo'shish): qidiruv, barcode, variantlar, filial bo'yicha qoldiq. Web /sales dagi mahsulot ro'yxati bilan bir xil. |
| POST | `/api/v1/sales/store` | **Chek/buyurtma yaratish (sotuvni yopish).** Body: cart, payments, customer, orderType, status, subTotal, tax, discount, grandTotal va b. |
| POST | `/api/v1/sales/set-branch` | Joriy filialni o'rnatish (keyingi sotuvlar shu filialda). Body: `branchID`, `orderType`. |
| GET | `/api/v1/sales/payment-types` | To'lov turlari ro'yxati (Naqd, Karta, Payme, Qarz va h.k.) — chek yopishda tanlash uchun. |
| GET | `/api/v1/sales/branches` | Filiallar ro'yxati (dropdown: `text`, `value`). |

### Sotuv uchun mahsulotlar — POST /api/v1/sales/products

**Body (JSON):**
- `rowLimit` — sahifadagi mahsulotlar soni (ixtiyoriy)
- `offset` — offset (ixtiyoriy)
- `searchValue` — qidiruv (nom, barcode, SKU)
- `currentBranch` — filial id (majburiy emas; bo‘lmasa user sozlamasidagi filial ishlatiladi)
- `orderType` — `"sales"` (sotuv uchun)

**Example — So'rov:**
```http
POST /api/v1/sales/products
Authorization: Bearer 1|abc123...
Content-Type: application/json

{
  "rowLimit": 50,
  "offset": 0,
  "currentBranch": 1,
  "orderType": "sales"
}
```

**Javob (200):**
```json
{
  "products": [ { "productID": 1, "title": "Non", "productImage": "...", "unit_name": "dona", "taxPercentage": 0, ... } ],
  "variants": [
    {
      "id": 1,
      "product_id": 1,
      "bar_code": "4601234567890",
      "selling_price": 3000,
      "purchase_price": 2000,
      "availableQuantity": 50,
      "units_per_package": 10,
      "package_selling_price": 28000,
      "package_purchase_price": 19000
    }
  ],
  "count": 1,
  "barcodeResultValue": null,
  "shortcutSettings": { ... },
  "total_products": 1
}
```

**Dona va pachka:** Har bir variantda **dona** (bitta dona) va ixtiyoriy **pachka** maydonlari mavjud:
- `selling_price`, `purchase_price` — dona narxi.
- `units_per_package` — pachkada nechta dona (masalan 10). Null yoki 1 bo‘lsa faqat dona.
- `package_selling_price`, `package_purchase_price` — pachka sotish/kirim narxi (ixtiyoriy). Bo‘lmasa dona narx × `units_per_package` hisoblanadi.

Sotuvda mijoz **dona** yoki **pachka** tanlashi mumkin. Chek yuborishda (sales/store) savat qatorida `isPackage` (true/false) va `unitsPerPackage` (son) yuboriladi — qismi pastda.

**Eslatma:** Barcode qidiruv uchun `searchValue` ga barcode yozing; aniq mos mahsulot bo‘lsa `barcodeResultValue` to‘ldiriladi (savatga bir martada qo‘shish uchun).

### To'lov turlari — GET /api/v1/sales/payment-types

**So'rov:** `GET /api/v1/sales/payment-types` + `Authorization: Bearer {token}`

**Javob (200):** To‘g‘ridan-to‘g‘ri massiv yoki ob'ekt ichida: `[{ "id": 1, "name": "Naqd", "type": "cash", "status": "...", "is_default": 0 }, ...]`

### Filiallar — GET /api/v1/sales/branches

**Javob (200):** `[{ "text": "Filial 1", "value": 1 }, ...]` — dropdown uchun.

### Filialni o'rnatish — POST /api/v1/sales/set-branch

**Body:** `{ "branchID": 1, "orderType": "sales" }` — keyingi sotuvlar shu filialda bo‘ladi.

### Chek/buyurtma yaratish (sotuv) — POST /api/v1/sales/store

**Body (JSON)** — web /sales da yuboriladigan format bilan mos:

| Maydon | Tavsif |
|--------|--------|
| `cart` | Savatdagi mahsulotlar massivi. Har bir element: `productID`, `variantID`, `quantity`, `price`, `productTitle`, `variantTitle`, `orderType` ("sales"), `discount`, `taxID`, `calculatedPrice`, `cartItemNote` (ixtiyoriy). **Pachka:** `isPackage` (true/false), `unitsPerPackage` (pachkadagi dona soni). Pachka bo‘lsa: `quantity` — pachka soni, `price` — pachka narxi (yoki dona narxi; backend pachka uchun `package_selling_price` ni ham qabul qiladi). Chegirma qatori uchun `orderType`: "discount". |
| `payments` | To'lovlar massivi. Har biri: `paymentID` (to'lov turi id), `paid` (summa), `paymentType` (ixtiyoriy: "cash", "credit", "customer_balance" va h.k.). |
| `customer` | Mijoz (ixtiyoriy). `{ "id": 1 }` yoki to‘liq ob'ekt (yangi mijoz bo‘lsa backend yozadi). |
| `orderType` | `"sales"` |
| `salesOrReceivingType` | `"customer"` (oddiy sotuv) |
| `status` | `"done"` (chek yopilgan) yoki `"hold"` (vaqtincha saqlash) |
| `subTotal` | Savat jami (soliqsiz) |
| `tax` | Jami soliq |
| `discount` | Umumiy chegirma (foiz yoki summa) |
| `grandTotal` | Jami to‘lov summa |
| `dueAmount` | Qarz qoldiq (credit to‘lov bo‘lsa) |
| `duePaymentDate` | Qarz to‘lash muddati (YYYY-MM-DD, ixtiyoriy) |
| `profit` | Foyda (ixtiyoriy) |
| `time` | Vaqt (ixtiyoriy; default: hozir) |
| `salesNote` | Izoh (ixtiyoriy) |
| `cashRagisterId` | Kassa id (ixtiyoriy; kassa yoqilgan bo‘lsa) |

**Example — So'rov (minimal):**
```http
POST /api/v1/sales/store
Authorization: Bearer 1|abc123...
Content-Type: application/json

{
  "orderType": "sales",
  "salesOrReceivingType": "customer",
  "status": "done",
  "subTotal": 30000,
  "tax": 0,
  "discount": 0,
  "grandTotal": 30000,
  "dueAmount": 0,
  "profit": 5000,
  "cart": [
    {
      "productID": 1,
      "variantID": 1,
      "quantity": 2,
      "price": 15000,
      "productTitle": "Non",
      "variantTitle": "default_variant",
      "orderType": "sales",
      "discount": 0,
      "taxID": null,
      "calculatedPrice": 30000
    }
  ],
  "payments": [
    { "paymentID": 1, "paid": 30000 }
  ],
  "customer": null
}
```

**Javob (200):** Web kabi — muvaffaqiyatda buyurtma yaratiladi; javobda xabar yoki `orderID`, `invoice_id` va h.k. (backend qaytaradigan strukturaga qarab mobile moslashtiradi).

**Xato (400):** Ombor yetarli bo‘lmasa `checkAvailableQuantity`, `message`; boshqa validatsiya xatolari.

---

## 3.4 Receives (kirim) — /receives dagi barcha imkoniyatlar

Web sahifadagi **/receives** (yetkazib beruvchidan mahsulot kirimi) bilan bir xil: mahsulotlar ro'yxati, yetkazib beruvchi tanlash, kirim cheki yaratish.

| Method | URL | Tavsif |
|--------|-----|--------|
| POST | `/api/v1/receives/products` | Kirim uchun mahsulotlar (savatchaga qo'shish). Body da **`orderType`: `"receiving"`** yuboriladi. |
| POST | `/api/v1/receives/store` | Kirim cheki/buyurtma yaratish. Body: sales/store ga o‘xshash, lekin `orderType`: `"receiving"`, `salesOrReceivingType`: `"supplier"`, `supplier` (customer o‘rniga). |
| POST | `/api/v1/receives/set-branch` | Joriy filialni o'rnatish. Body: `branchID`, `orderType`: `"receiving"`. |
| GET | `/api/v1/receives/payment-types` | To'lov turlari. |
| GET | `/api/v1/receives/branches` | Filiallar ro'yxati. |

**Yetkazib beruvchilar ro'yxati:** Kirimda yetkazib beruvchi tanlash uchun **POST /api/v1/contacts/suppliers** ishlatiladi (Contacts bo‘limida). Body: `{ "rowLimit": 5000, "rowOffset": 0 }`. Javob: `datarows`, `count`. Har bir elementda `id`, `name` (first_name + last_name), `email`, `company`, `phone_number`, `address`, `tin_number`.

### Kirim uchun mahsulotlar — POST /api/v1/receives/products

**Body:** Sales/products bilan bir xil, lekin **`orderType`: `"receiving"`** majburiy. `currentBranch`, `searchValue`, `rowLimit`, `offset` ixtiyoriy.

```http
POST /api/v1/receives/products
Authorization: Bearer 1|abc123...
Content-Type: application/json

{
  "rowLimit": 50,
  "offset": 0,
  "currentBranch": 1,
  "orderType": "receiving"
}
```

**Javob:** Sales/products kabi — `products`, `variants`, `count`, `barcodeResultValue`, `shortcutSettings`. Variantlarda `purchase_price` (kirim narxi) ishlatiladi.

### Kirim cheki yaratish — POST /api/v1/receives/store

**Body:** Sales/store ga o‘xshash. Farqi:
- `orderType`: **`"receiving"`**
- `salesOrReceivingType`: **`"supplier"`**
- **`supplier`** (customer o‘rniga): `{ "id": 1 }` yoki yangi yetkazib beruvchi ob'ekti.

Boshqa maydonlar: `cart`, `payments`, `subTotal`, `tax`, `discount`, `grandTotal`, `status` ("done"), `profit`, `time`, `cashRagisterId` va h.k. — sales/store bilan bir xil.

**Example (minimal):**
```http
POST /api/v1/receives/store
Authorization: Bearer 1|abc123...
Content-Type: application/json

{
  "orderType": "receiving",
  "salesOrReceivingType": "supplier",
  "status": "done",
  "subTotal": 100000,
  "tax": 0,
  "discount": 0,
  "grandTotal": 100000,
  "dueAmount": 0,
  "profit": 0,
  "cart": [
    {
      "productID": 1,
      "variantID": 1,
      "quantity": 10,
      "price": 10000,
      "productTitle": "Non",
      "variantTitle": "default_variant",
      "orderType": "receiving",
      "discount": 0,
      "taxID": null,
      "calculatedPrice": 100000
    }
  ],
  "payments": [ { "paymentID": 1, "paid": 100000 } ],
  "supplier": { "id": 1 }
}
```

---

## 4. Expenses — xarajatlar

| Method | URL | Tavsif |
|--------|-----|--------|
| GET | `/api/v1/expenses` | Xarajatlar ro'yxati. Query: `from`, `to` (sana), `category_id`, `payment_type_id`. Javob: `expenses`, `total`, `paymentTypes`, `expenseCategories`. |
| POST | `/api/v1/expenses` | Yangi xarajat. Body: `name`, `price`, `payment_type_id`, `expense_category_id`, `note`. |
| DELETE | `/api/v1/expenses/{id}` | Xarajatni o'chirish. |

**Example — Xarajatlar ro'yxati:**
```http
GET /api/v1/expenses?from=2025-03-01&to=2025-03-07
Authorization: Bearer 1|abc123...
```

**Javob (200):**
```json
{
  "expenses": [
    {
      "id": 10,
      "name": "Ofis materiallari",
      "price": 150000,
      "created_at": "2025-03-07 10:30:00",
      "payment_type_name": "Naqd",
      "expense_category_name": "Maishiy"
    }
  ],
  "total": 150000,
  "paymentTypes": [{ "id": 1, "name": "Naqd" }],
  "expenseCategories": [{ "id": 1, "name": "Maishiy" }]
}
```

**Mobile uchun:** Ro'yxat = `expenses`. Har bir elementda: `id`, `date` ← `created_at`, `price` (yoki `amount`), `name` (izoh).

---

## 5. Reports — Savdo hisoboti (/reports/sales)

Filter va invoice detail ham API orqali olish mumkin.

| Method | URL | Tavsif |
|--------|-----|--------|
| POST | `/api/v1/reports/sales` | Savdo ro'yxati (filter, qidiruv, sahifalash). Body: `filtersData`, `searchValue`, `columnKey`, `columnSortedBy`, `rowLimit`, `rowOffset`, `reqType`. Javob: `datarows`, `count` (har qatorda invoice_id, customer, item_purchased, tax, discount, total, due_amount, purchase_total; oxirgi qator grand total). |
| GET | `/api/v1/reports/sales/filter` | Filter uchun yordamchi ma'lumotlar. Javob: `brands`, `categories`, `groups`, `customers`, `employee` (har biri `[{text, value}]`). |
| POST | `/api/v1/reports/sales/invoice-details/{id}` | **Invoice detail** — buyurtma/id bo‘yicha batafsil: mahsulotlar (title, price, quantity, discount), sub_total, tax, total, to‘lovlar (payment name + paid). `{id}` — order id. Javob: `datarows`, `count`. |
| **POST** | **`/api/v1/reports/sales/return/{id}`** | **Chekni qaytarish** — web sahifadagi "AMAL → Chekni qaytarish" bilan bir xil. `{id}` — order id (raqam). Body: bo‘sh `{}` yoki backend talab qiladigan maydonlar. Javob: success/message. |
| GET | `/api/v1/reports/sales/order/{id}` | Buyurtma uchun invoice template (print/PDF). Javob: `templateData`, `invoiceId`, `largeInvoiceView`. |
| POST | `/api/v1/reports/sales/all-details` | Savdo batafsil hisobot (har bir order item). Body: `filtersData`, `searchValue`, `columnKey`, `columnSortedBy`, `rowLimit`, `rowOffset`, `reqType`. |
| POST | `/api/v1/reports/sales/summary` | Savdo summary (filial/mijoz/xodim bo‘yicha jamilar). Body: `filterType`, `filterKey`, `groupBy`, `rowLimit`, `rowOffset`, va b. |

**filtersData** — massiv, masalan: `[{"key": "branch", "value": "1"}, {"key": "customer", "value": "5"}, {"key": "start_date", "value": "2025-01-01"}, {"key": "end_date", "value": "2025-01-31"}]`. Filter kalitlari: branch, customer, employee (xodim), start_date, end_date va b. (web sahifadagi filter bilan bir xil).

---

### Chek batafsil va qaytarish — Mobile chaqiruvi va Postman tekshiruvi

**1. Chek batafsil (chekda nimalar sotilgani)**

| Nomi | Qiymat |
|------|--------|
| **Method** | `POST` |
| **URL** | `{baseUrl}/reports/sales/invoice-details/{id}` |
| **Masalan** | `POST /api/v1/reports/sales/invoice-details/10094` |
| **Body** | `{}` (bo'sh JSON) |
| **Headers** | `Authorization: Bearer {token}`, `Content-Type: application/json`, `Accept: application/json`, kerak bo'lsa `X-Company-Id` |

**Javob (200) — Mobile qanday o'qiydi:**

- Mahsulotlar ro'yxati quyidagi kalitlardan **birinchi topilgan**da olinadi: `datarows` → `data` → `items` → `products` → `invoice_items` → `rows`.
- Agar `data` ob'ekt bo'lsa, uning ichidan: `data.datarows`, `data.items`, `data.products`.
- Har bir mahsulot qatori (Map) da Mobile quyidagi kalitlarni qidiradi:
  - **Nom:** `title` / `product_title` / `productTitle` / `name`
  - **Miqdor:** `quantity` / `qty`
  - **Narx:** `price` / `unit_price`
  - **Summa:** `calculatedPrice` / `sum` / `total` (yoki narx × miqdor)

**Backend talabi:** Javob **JSON** bo'lishi kerak. Agar server HTML (xato sahifasi) qaytarsa, ilovada "Server HTML javob qaytardi…" xabari chiqadi.

**Postman tekshiruv:** Login qiling → `POST .../reports/sales/invoice-details/10094`, body `{}` → javobda mahsulotlar qaysi kalitda (masalan `datarows`) va har bir elementda `title`, `quantity`, `price` bor-yo'qligini tekshiring.

---

**2. Chekni qaytarish**

Mobile avval quyidagini, 404 bo'lsa ikkinchi variantni chaqiradi.

| Nomi | Qiymat |
|------|--------|
| **Method** | `POST` |
| **URL (birinchi urinish)** | `{baseUrl}/sales/return` |
| **Masalan** | `POST /api/v1/sales/return` |
| **Body** | `{"order_id": 10094}` |
| **Headers** | `Authorization: Bearer {token}`, `Content-Type: application/json`, `Accept: application/json` |

Agar **404** qaytsa, Mobile ikkinchi marta:

| Nomi | Qiymat |
|------|--------|
| **URL (fallback)** | `{baseUrl}/reports/sales/return/{id}` |
| **Masalan** | `POST /api/v1/reports/sales/return/10094` |
| **Body** | `{}` (bo'sh JSON) |

**Javob (200):** JSON, masalan `{"success": true, "message": "..."}`. Mobile faqat status 2xx va JSON kutiladi.

**Muhim:** Agar server xato bersa (500, 404 va b.), javob **JSON** bo'lishi kerak (masalan `{"message": "..."}`). Agar HTML qaytsa, ilovada "Server HTML javob qaytardi (xato sahifasi). Kod: 500. Serverni yoki API manzilini tekshiring." chiqadi.

**Postman tekshiruv:** `POST .../reports/sales/return/10094`, body `{}` → 200 va JSON kelinganini tekshiring. Xato bersa, javob Content-Type `application/json` va tana JSON ekanligini tekshiring.

---

## User — profil (ism, familiya, login, parol) edit mavjud

| Method | URL | Tavsif |
|--------|-----|--------|
| GET | `/api/v1/user` | Joriy foydalanuvchi ma'lumotlari (id, first_name, last_name, email, va b.). |
| GET | `/api/v1/user/profile` | Profil to'liq (profile obyekti + dateformat). |
| **POST** | **`/api/v1/user/profile`** | **Profil tahrirlash (ism, familiya, login/email).** Body: `first_name`, `last_name`, `email`, `phone_number`, `date_of_birth`, `avatar` (ixtiyoriy). Faqat joriy user o'zini tahrir qiladi. |
| **POST** | **`/api/v1/user/password`** | **Parol o'zgartirish.** Body: `password`, `password_confirmation` (majburiy). |

**Example — Joriy foydalanuvchi (user):**
```http
GET /api/v1/user
Authorization: Bearer 1|abc123...
```

**Javob (200):**
```json
{
  "success": {
    "id": 5,
    "first_name": "Aziz",
    "last_name": "Sotuvchi",
    "email": "user@example.com",
    "company_id": 1,
    "user_type": "staff",
    "enabled": 1,
    "verified": 1
  }
}
```

**Mobile uchun:** Menu’dagi ism = `success.first_name` + `success.last_name`; bo‘sh bo‘lsa `success.email` yoki "Sotuvchi".

---

## Autentifikatsiya

- **Login:** `POST /api/v1/login` — body: `email`, `password`, `company_id` (oddiy user uchun majburiy). Javobda token **`data.token`** da beriladi.
- **Logout:** `POST /api/v1/logout` — header: `Authorization: Bearer {token}`.
- **Foydalanuvchi:** `GET /api/v1/user` — joriy user ma'lumotlari (`success` obyektida).
- **Profil tahrir:** `POST /api/v1/user/profile` (ism, familiya, email). **Parol:** `POST /api/v1/user/password` (`password`, `password_confirmation`).

Har bir himoyalangan so'rovda: `Authorization: Bearer {token}` header yuboriladi.

---

## API javobini tekshirish (Postman / curl)

1. **Login** qiling, javobdan `data.token` ni oling.
2. Header: `Authorization: Bearer {token}`, kerak bo‘lsa `X-Company-Id: {company_id}`.
3. **Mahsulotlar:** `POST /api/v1/products/list`, body: `{"rowLimit": 10, "rowOffset": 0}` — javobda `datarows` va har bir elementda `productID`, `title`, `selling_price`, `variants` va b.
4. **Mijozlar:** `GET /api/v1/contacts/customers-list` — javobda `customers` massivi.
5. **User:** `GET /api/v1/user` — javobda `success` ichida `first_name`, `last_name`, `email`.
6. **Dashboard:** `GET /api/v1/dashboard?date=Y-m-d` — javobda `basicData`, `todayPaymentTypes`, `dailyProductsSold` va b.
7. **Kategoriyalar:** `GET /api/v1/products/categories` — massiv `[{id, name}, ...]`.
8. **Xarajatlar:** `GET /api/v1/expenses?from=Y-m-d&to=Y-m-d` — javobda `expenses`, har biri `id`, `price`, `name`, `created_at`.
