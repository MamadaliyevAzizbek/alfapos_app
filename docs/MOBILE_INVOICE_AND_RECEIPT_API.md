# Chek (invoice) va tranzaksiya detail — Mobile API

Bu hujjat mobil dasturchi uchun: **savdo ro'yxatini** olish, **chek batafsil** (mahsulotlar, summalar, to'lovlar) va **chekni ko'rsatish/yuklab olish** qanday API orqali amalga oshirilishi kerakligini tushuntiradi.

**Baza URL:** `https://your-domain.com`  
**Prefix:** `/api/v1`  
**Auth:** Barcha so'rovlarda `Authorization: Bearer {token}` header majburiy.

---

## Qisqacha ketma-ketlik

| Qadam | Maqsad | API |
|-------|--------|-----|
| 1 | Tranzaksiyalar (cheklar) ro'yxatini olish | **POST** `/api/v1/reports/sales` |
| 2 | Bitta chekning batafsil ma'lumotini olish (mahsulotlar, to'lovlar) | **POST** `/api/v1/reports/sales/invoice-details/{order_id}` |
| 3 | Chekni HTML/print ko'rinishida olish (ixtiyoriy) | **GET** `/api/v1/reports/sales/order/{order_id}` |

**Muhim:** Barcha joylarda `{order_id}` — bu **savdo ro'yxatidan** (1-qadam) olingan **`id`** maydoni (raqam). Bu `orders` jadvalidagi yozuvning `id` si, `invoice_id` (matnli chek raqami) emas.

---

## 1. Savdo ro'yxati (tranzaksiyalar / cheklar ro'yxati)

Cheklar ro'yxatini olish uchun savdo hisobot API ishlatiladi. Har bir qatorda **order id** (`id`) bor — shu id keyingi qadamda chek batafsil olish uchun kerak.

### So'rov

| Method | URL |
|--------|-----|
| POST | `/api/v1/reports/sales` |

**Headers:**  
`Authorization: Bearer {token}`  
`Content-Type: application/json`

**Body (JSON):**
```json
{
  "rowLimit": 50,
  "rowOffset": 0,
  "columnKey": "id",
  "columnSortedBy": "desc",
  "searchValue": "",
  "filtersData": [
    {
      "filterKey": "date_range",
      "value": [
        { "start": "2025-03-01", "end": "2025-03-11" }
      ]
    }
  ]
}
```

**Body maydonlari (qisqacha):**
- `rowLimit` — sahifadagi qatorlar soni (masalan 20, 50).
- `rowOffset` — sahifalash uchun offset (0, 20, 40 …).
- `columnKey` — qaysi ustun bo'yicha tartiblash (masalan `id`, `date`, `total`).
- `columnSortedBy` — `asc` yoki `desc`.
- `searchValue` — ixtiyoriy qidiruv (mijoz ismi, invoice_id va h.k.).
- `filtersData` — ixtiyoriy filterlar. **Sana oralig'i** uchun: `filterKey: "date_range"`, `value: [{ "start": "YYYY-MM-DD", "end": "YYYY-MM-DD" }]`.

### Javob (200)

```json
{
  "datarows": [
    {
      "id": 12345,
      "invoice_id": "INV-2025-001234",
      "date": "2025-03-11 14:30:00",
      "customer": "Jamol Mijoz",
      "customer_id": 5,
      "created_by": "Aziz Sotuvchi",
      "user_id": 10,
      "item_purchased": 3,
      "discount": "0",
      "tax": "0",
      "total": "45000",
      "due_amount": "0",
      "purchase_total": "30000",
      "title": "Non",
      "transfer_branch_name": null,
      "type": "sales"
    }
  ],
  "count": 1
}
```

**Mobile uchun:**
- Ro'yxat = `datarows`.
- **Chek batafsilini ochish uchun** shu qatordagi **`id`** ni ishlating (masalan `12345`). Bu — **order id**.
- `invoice_id` — foydalanuvchiga ko'rinadigan chek raqami (matn).
- `date` — buyurtma sanasi/vaqti.
- `customer` — mijoz ismi; bo'sh bo'lsa "Walk-in" ko'rsatishingiz mumkin.
- `total` — jami summa (string, formatlangan bo'lishi mumkin).

**Eslatma:** Oxirgi qator `invoice_id: "Grand Total"` (yoki tilga qarab boshqa) — bu jami qator, uning `id` si yo'q. Faqat `datarows` ichida `id` bo'lgan qatorlarni chek detail uchun ishlating.

---

## 2. Chek batafsil (invoice detail) — mahsulotlar, summalar, to'lovlar

Bitta chekning to'liq tarkibi: qatorlar (mahsulot nomi, narx, miqdor, chegirma), subtotal, soliq, jami, to'lov turlari va summalari.

### So'rov

| Method | URL |
|--------|-----|
| POST | `/api/v1/reports/sales/invoice-details/{order_id}` |

**{order_id}** — 1-qadamda olingan `datarows[].id` (butun son).

**Headers:**  
`Authorization: Bearer {token}`  
`Content-Type: application/json`

**Body:** Bo'sh ob'ekt yoki ixtiyoriy `{}` — backend body ni talab qilmaydi, lekin POST bo'lgani uchun `{}` yuborish mumkin.

**Misol:**
```http
POST /api/v1/reports/sales/invoice-details/12345
Authorization: Bearer 1|abc123...
Content-Type: application/json

{}
```

### Javob (200)

```json
{
  "datarows": [
    {
      "title": "Non (default_variant)",
      "price": "15 000",
      "total": "30 000",
      "quantity": 2,
      "discount": "0"
    },
    {
      "title": "Suv 1.5L",
      "price": "5 000",
      "total": "5 000",
      "quantity": 1,
      "discount": "0"
    },
    {
      "title": "Sub total",
      "total": "35 000"
    },
    {
      "title": "Tax",
      "total": "0"
    },
    {
      "title": "Total",
      "total": "35 000"
    },
    {
      "title": "Naqd",
      "total": "35 000"
    }
  ],
  "count": 0
}
```

**Struktura:**
- **Birinchi qatorlar** — mahsulotlar: `title` (mahsulot nomi, variant qavs ichida), `price` (birlik narxi), `total` (qator jami), `quantity`, `discount`. Ba'zi qatorlarda `title: "Discount"` bo'lsa — bu chegirma qatori; `price`/`quantity` null bo'lishi mumkin.
- **Keyingi qatorlar** — jamilar: `title` = "Sub total" | "Tax" | "Total", `total` = summa.
- **Oxirgi qatorlar** — to'lov turlari: `title` = to'lov turi nomi (masalan "Naqd", "Terminal"), `total` = shu turdagi to'langan summa.

**Miqdor formati:** Agar mahsulot **pachka** bilan sotilgan bo'lsa, `quantity` "2 pachka" kabi string bo'lishi mumkin; aks holda oddiy son.

**Mobile uchun:** `datarows` ni ketma-ket o'qib, `title` ga qarab "mahsulot", "sub total", "tax", "total", "to'lov turi" qismlarini ajratib, ekranda chek detail sahifasini yig'ing.

---

## 3. Chekni HTML/print ko'rinishida olish (ixtiyoriy)

Agar ilova chekni "dokument" yoki "print" ko'rinishida (HTML blok yoki keyinroq PDF) ko'rsatmoqchi bo'lsa, shu endpoint dan foydalaniladi.

### So'rov

| Method | URL |
|--------|-----|
| GET | `/api/v1/reports/sales/order/{order_id}` |

**{order_id}** — yana 1-qadamdagi `id` (order id).

**Headers:**  
`Authorization: Bearer {token}`

**Misol:**
```http
GET /api/v1/reports/sales/order/12345
Authorization: Bearer 1|abc123...
```

### Javob (200)

```json
{
  "templateData": {
    "content": "<html>...</html>",
    "invoice_size": "thermal"
  },
  "invoiceId": "INV-2025-001234",
  "largeInvoiceView": "<html>...</html>"
}
```

- **templateData.content** — termal (80mm va h.k.) chek uchun HTML.
- **largeInvoiceView** — katta formatdagi chek HTML (A4/print uchun).
- **invoiceId** — chek raqami (foydalanuvchiga ko'rsatish uchun).

**Mobile uchun:** `largeInvoiceView` yoki `templateData.content` ni WebView ichida ko'rsatish yoki serverda PDF ga aylantirib yuborish mumkin (agar keyinchalik bunday API qo'shilsa).

---

## Xato javoblari

| Kod | Ma'no |
|-----|--------|
| 404 | `order_id` topilmadi yoki joriy user/comany uchun bu buyurtmaga ruxsat yo'q. |
| 500 | Server xatosi. |

**invoice-details** yoki **order** uchun 404:
- Javobda `error` matni bo'ladi (masalan "Order not found", "Order details not found").
- Tekshiring: `order_id` to'g'ri (savdo ro'yxatidagi `id`), token va company scope to'g'ri.

---

## Qisqa jadval — mobil ekran uchun

| Ekran / harakat | API | Kerakli maydon |
|-----------------|-----|-----------------|
| Tranzaksiyalar ro'yxati | POST `/api/v1/reports/sales` | `datarows`, har qatorda `id`, `invoice_id`, `date`, `customer`, `total` |
| Chek batafsil (mahsulotlar + to'lovlar) | POST `/api/v1/reports/sales/invoice-details/{id}` | `id` = `datarows[].id`; javobda `datarows` |
| Chek HTML / print | GET `/api/v1/reports/sales/order/{id}` | `id` = order id; javobda `invoiceId`, `templateData`, `largeInvoiceView` |

Barcha `{id}` lar **order id** (raqam), **invoice_id** (matn) emas.
