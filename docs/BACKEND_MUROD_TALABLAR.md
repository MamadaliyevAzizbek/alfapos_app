# Mobile ilova uchun API talablari (Murod uchun)

Ilova **barcha ma'lumotni API orqali** oladi. Quyida qaysi endpointlar kerak, qanday so‘rov yuboramiz va javob qanday ko‘rinishda bo‘lishi kerak — barchasi yozilgan. Agar API hozir boshqa formatda bo‘lsa, shu hujjatga qilib moslashtirilsa ilova to‘liq ishlaydi.

---

## Umumiy qoidalar

- **Base URL:** `https://nasiyapos.uz`
- **Prefix:** barcha endpointlar `/api/v1` ostida (masalan: `/api/v1/login`, `/api/v1/dashboard`)
- **Auth:** Login dan keyin har so‘rovda header: `Authorization: Bearer {token}`
- **Kompaniya:** Super admin uchun header: `X-Company-Id: {company_id}`
- **Content-Type:** `application/json`
- **Accept:** `application/json`

---

## 1. Login

| Narsa | Qiymat |
|-------|--------|
| **Method** | `POST` |
| **URL** | `/api/v1/login` |
| **Body (JSON)** | `{ "email": "...", "password": "...", "company_id": "..." }` |
| **Javob** | `{ "token": "..." }` yoki `{ "data": { "token": "..." } }` — **token** string bo‘lishi shart. |

**Yetishmasa:** Agar javobda `token` bo‘lmasa yoki boshqa kalitda (masalan `access_token`) bo‘lsa, ilovada login ishlamaydi. Ilova faqat `token` yoki `data.token` ni qidiradi.

---

## 2. Dashboard (asosiy ekran)

| Narsa | Qiymat |
|-------|--------|
| **Method** | `GET` |
| **URL** | `/api/v1/dashboard?date=2025-03-06` (sana ixtiyoriy, format `Y-m-d`) |
| **Javob (root yoki basicData ichida)** | Quyidagi kalitlar bo‘lishi kerak (nomlar aynan shunday yoki backendda shunday qilib berilsa ma'qul): |

**Kutiladigan struktura (haqiqiy API dan olingan):**

```json
{
  "basicData": {
    "todaySales": 0,
    "todayExpenses": 0,
    "monthlySale": "...",
    "totalSale": "..."
  },
  "todayPaymentTypes": [
    { "id": 1, "payment_method": "Naqd pul", "total_amount": 0 },
    { "id": 2, "payment_method": "Qarz", "total_amount": 0 }
  ],
  "sellersReport": [
    { "seller_id": 6, "seller_name": "Azizbek Mamadaliyev", "order_count": 0, "total_sales": 0 },
    { "seller_id": 2, "seller_name": "Murod Qodirov", "order_count": 0, "total_sales": 0 }
  ],
  "dailyProductsSold": 0,
  "todayIncomes": 0
}
```

- **todaySales** yoki **todayIncomes** — bugungi jami savdo (son).
- **todayExpenses** — bugungi xarajat (son).
- **todayPaymentTypes** — to‘lov turlari ro‘yxati; har birida: **id**, **payment_method** (nom), **total_amount** (summa, son).
- **sellersReport** — sotuvchilar ro‘yxati; Menu ekranida ko‘rsatiladi. Har birida: **seller_id**, **seller_name**, **order_count**, **total_sales**.
- **dailyProductsSold** — son (0) yoki bugungi eng ko‘p sotilgan mahsulotlar ro‘yxati (list). Agar list bo‘lmasa, ilova alohida `/api/v1/dashboard/top-selling-products` ni chaqiradi.

**Eng ko‘p sotilgan mahsulotlar (alohida):**

| Method | URL | Javob |
|--------|-----|--------|
| GET | `/api/v1/dashboard/top-selling-products` | Ro‘yxat: `dailyProductsSold`, `data` yoki `top_products`. Har bir elementda: **name** yoki **product_name**, **quantity** yoki **quantity_sold** yoki **total_quantity**. |

---

## 3. Mahsulotlar ro‘yxati

| Narsa | Qiymat |
|-------|--------|
| **Method** | `POST` |
| **URL** | `/api/v1/products/list` |
| **Body (JSON)** | `{ "rowLimit": 5000, "rowOffset": 0 }` |
| **Javob** | Ro‘yxat quyidagilardan **bittasida** bo‘lishi kerak: **datarows**, **products**, **data** (to‘g‘ridan-to‘g‘ri list). Yoki **data** obyekti ichida: **datarows**, **products**, **data**, **items**. |

**Har bir mahsulot ob'ektida ilova quyidagilarni ishlatadi:**

| Maydon (ilovada) | API da kerak bo‘lgan kalitlar (bittasi bo‘lsa yetadi) |
|------------------|-------------------------------------------------------|
| ID | **id** |
| Nom | **title** yoki **name**, **product_name** |
| Sotish narxi | **selling_price**, **sell_price**, **price** |
| Kirim narxi | **purchase_price**, **cost_price** |
| Miqdor | **product_quantity**, **quantity**; yoki **variants[0].availableQuantity** |
| Barcode | **barcode**; yoki **variants[0].bar_code** |
| SKU | **sku**; yoki **variants[0].sku** |
| Kategoriya | **category_name** yoki **category** (ob'ekt yoki string) |
| Rasm | **imageURL**, **image**, **image_url** |

Agar mahsulotda **variants** massivi bo‘lsa, ilova barcode va miqdorni **variants[0]** dan oladi.

---

## 4. Yangi mahsulot qo‘shish (muhim)

| Narsa | Qiymat |
|-------|--------|
| **Method** | `POST` |
| **URL** | `/api/v1/products` |
| **Body (JSON)** | Quyidagilar **majburiy** yoki ilova yuboradi, backend ularni qabul qilishi kerak: |

**Backend da talab qilinadigan format:**

- **name** yoki **title** (string) — mahsulot nomi, **majburiy**.
- **type** (string yoki son) — mahsulot turi, **majburiy**. Ilova `"standard"` yoki `"type": "standard"` yuboradi. Agar backend boshqa qiymat (yoki son id) kutsa, shuni qabul qilishi kerak.
- **unit** yoki **unit_id** (integer) — birlik id (1 = dona, 2 = kg, va h.k.), **integer** bo‘lishi kerak. Ilova matn "dona" emas, **son** (1, 2, 3) yuboradi. Backend **"The unit must be an integer"** xatosini bermasligi kerak.
- **sell_price** (son)
- **quantity** (son)
- **purchase_price** (son, ixtiyoriy)
- **category_id** (son, ixtiyoriy)
- **sku**, **barcode**, **description** (string, ixtiyoriy; bo‘sh qator bo‘lishi mumkin)

**Xulosa:** Backend **name** (yoki **title**), **type**, **unit** (integer) ni **majburiy** qilishi va boshqa maydonlarni yuqoridagidek qabul qilishi kerak. Validatsiyada **unit** uchun **integer** rule ishlatilsin, **type** bo‘yicha ham qoida aniq bo‘lsin.

---

## 5. Kategoriyalar

| Narsa | Qiymat |
|-------|--------|
| **Method** | `GET` |
| **URL** | `/api/v1/products/categories` |
| **Javob** | Kategoriyalar ro‘yxati quyidagilardan **bittasida** bo‘lishi kerak: **data**, **categories**, **datarows** (to‘g‘ridan-to‘g‘ri list). Yoki **data** ichida: **data**, **categories**, **items**. |

**Har bir kategoriya ob'ektida:**

- **id** (son) — majburiy (mahsulot qo‘shishda category_id uchun).
- **name** yoki **title** yoki **category_name** — kategoriya nomi.

Agar bu endpoint bo‘sh yoki boshqa struktura qaytarsa, ilova **GET /api/v1/products/supporting-data** dan ham **categories** ni oladi. Shuning uchun **supporting-data** javobida ham **categories** massivi bo‘lsa ma'qul.

---

## 6. Supporting data (birliklar, kategoriyalar)

| Narsa | Qiymat |
|-------|--------|
| **Method** | `GET` |
| **URL** | `/api/v1/products/supporting-data` |
| **Javob** | Kamida **units** (birliklar ro‘yxati) bo‘lishi kerak. Har bir birlikda: **id**, **name** (yoki **shortname**). Ilova mahsulot qo‘shishda **unit_id** ni shu ro‘yxatdan oladi. **categories** ham bo‘lsa, kategoriyalar bo‘sh bo‘lsa ilova shu yerdan to‘ldiradi. |

---

## 7. Mijozlar ro‘yxati

| Narsa | Qiymat |
|-------|--------|
| **Method** | `GET` |
| **URL** | `/api/v1/contacts/customers-list` |
| **Javob** | Ro‘yxat: **customers**, **data** yoki **datarows** (list). Har bir mijozda: **id**, **first_name**, **last_name** (yoki **name**), **phone_number** (yoki **phone**), **address**. |

---

## 8. Yangi mijoz qo‘shish

| Narsa | Qiymat |
|-------|--------|
| **Method** | `POST` |
| **URL** | `/api/v1/contacts/customers/store` |
| **Body (JSON)** | **first_name** (majburiy), **last_name**, **phone_number**, **address**, **customer_group** (majburiy — son, masalan 1). |

---

## 9. Foydalanuvchi (Menu / profil)

| Narsa | Qiymat |
|-------|--------|
| **Method** | `GET` |
| **URL** | `/api/v1/user` |
| **Javob** | **first_name**, **last_name** (yoki **firstName**, **lastName**), **email**. Menu da sotuvchilar **sellersReport** dan keladi; agar u bo‘sh bo‘lsa, shu **user** dan ism ko‘rsatiladi. |

---

## 10. Xarajatlar

| Narsa | Qiymat |
|-------|--------|
| **Method** | `GET` |
| **URL** | `/api/v1/expenses?from=2025-03-01&to=2025-03-06` |
| **Javob** | Ro‘yxat: **expenses** yoki **data**. Har bir xarajatda: **id**, **date** (yoki **created_at**), **price** (yoki **amount**), **name**. |

---

## 11. Logout

| Narsa | Qiymat |
|-------|--------|
| **Method** | `POST` |
| **URL** | `/api/v1/logout` |
| **Header** | `Authorization: Bearer {token}` |

---

## Qisqacha: Nima yetishmayapti / nima kerak

1. **Login** — javobda **token** (yoki **data.token**) string bo‘lishi kerak.
2. **Dashboard** — **todayPaymentTypes** (id, payment_method, total_amount), **sellersReport** (seller_id, seller_name, order_count, total_sales), **basicData.todaySales**, **basicData.todayExpenses**; **dailyProductsSold** son yoki list.
3. **Mahsulotlar ro‘yxati** — ro‘yxat **datarows** (yoki **products** / **data**) da; har bir mahsulotda **id**, **title** (yoki name), **selling_price**, **purchase_price**, **product_quantity** yoki **variants[0].bar_code**, **availableQuantity**; **category_name**; **imageURL**.
4. **Yangi mahsulot qo‘shish** — **name** (yoki **title**) va **type** majburiy; **unit** (yoki **unit_id**) **integer** bo‘lishi kerak. Validatsiyada shu talablar qo‘yilsin.
5. **Kategoriyalar** — **GET /products/categories** javobida **data** yoki **categories** da list; har bir elementda **id**, **name** (yoki **title**). Yoki **supporting-data** da **categories** va **units** bo‘lsin.
6. **Mijozlar** — **customers-list** da **customers** (yoki **data**) list; har birida **id**, **first_name**, **last_name**, **phone_number**, **address**. **customers/store** da **customer_group** integer (masalan 1) qabul qilinsin.

Agar biron endpoint boshqa nom (masalan **access_token**, **product_title**) ishlatadigan bo‘lsa, backend ni shu hujjatdagi formatga yaqinlashtirish yoki ilovaga yangi kalitlarni qo‘shish kerak. Hujjatni Murodga yuborib, API ni shu ko‘rinishga keltirish mumkin.
