# Reports API — nima qaytadi (POST /api/v1/reports/sales)

**Dastur Backendchi bergan MOBILE_API.md ga moslashtirilgan.** So‘rov body va javob (datarows, invoice_id, customer, total va b.) shu hujjatdagi “5. Reports — Savdo hisoboti” bo‘limiga muvofiq. Haqiqiy javobni ilovada **Menu → Hisobotlar** ekranida "API javobi" tugmasi orqali ko‘rishingiz mumkin.

## So‘rov

- **Method:** POST  
- **URL:** `/api/v1/reports/sales`  
- **Body (masalan):**
```json
{
  "rowLimit": 200,
  "rowOffset": 0,
  "filtersData": [
    { "key": "start_date", "value": "2026-03-01" },
    { "key": "end_date", "value": "2026-03-10" }
  ]
}
```

Boshqa ixtiyoriy: `searchValue`, `columnKey`, `columnSortedBy`, `reqType`.

---

## Kutiladigan javob strukturasi

| Kalit       | Tavsif |
|------------|--------|
| **datarows** | Savdolar ro‘yxati (massiv). Har bir element — bitta savdo/chek. |
| **count**    | Ro‘yxatdagi yozuvlar soni (ixtiyoriy). |

Ba‘zi backendlar ro‘yxatni boshqa kalitda ham yuborishi mumkin: `data`, `sales`, `invoices`, `rows`. Ilova ularni ham qo‘llab-quvvatlaydi.

---

## datarows har bir qatorida bo‘lishi mumkin bo‘lgan maydonlar

| Maydon           | Tavsif |
|------------------|--------|
| **invoice_id** yoki **order_id** yoki **id** | Chek/buyurtma ID (majburiy — ilova shu orqali qatorni ko‘rsatadi). |
| **total** yoki **grand_total** yoki **total_amount** yoki **sum** | Chek jami summa (UZS). |
| **customer**     | Mijoz (matn yoki obyekt: `name`, `first_name`, `last_name`). |
| **created_at** yoki **date** yoki **invoice_date** yoki **order_date** | Sana/vaqt. |
| **item_purchased** | Sotilgan mahsulotlar (ixtiyoriy). |
| **tax**          | Soliq (ixtiyoriy). |
| **discount**     | Chegirma (ixtiyoriy). |
| **due_amount**   | Qarz qolgan summa (ixtiyoriy). |
| **purchase_total** | Kelish narxi jami (ixtiyoriy). |

Oxirgi qator ba‘zida **grand total** (jami) bo‘lishi mumkin — bunda `invoice_id` bo‘lmasa, ilova uni ro‘yxatda ko‘rsatmaydi.

---

## Boshqa Reports endpointlar

| Method | URL | Qisqacha |
|--------|-----|----------|
| GET | `/api/v1/reports/sales/filter` | Filter uchun: brands, categories, groups, customers, employee. |
| POST | `/api/v1/reports/sales/invoice-details/{id}` | Bitta chek batafsil (mahsulotlar, to‘lovlar). |
| GET | `/api/v1/reports/sales/order/{id}` | Chek uchun shablon (print/PDF). |
| POST | `/api/v1/reports/sales/all-details` | Barcha savdo qatorlari hisoboti. |
| POST | `/api/v1/reports/sales/summary` | Summary (filial/mijoz/xodim bo‘yicha). |

---

**Haqiqiy javobni tekshirish:** Ilovada **Menu → Hisobotlar** oching, sana tanlang va app bar dagi **"API javobi"** tugmasini bosing — serverdan kelgan to‘liq JSON ko‘rsatiladi.
