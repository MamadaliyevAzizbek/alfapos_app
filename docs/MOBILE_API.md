# Mobile App API (v1)

Barcha endpoint'lar **Bearer token** (Sanctum) bilan himoyalangan. Login: `POST /api/v1/login` — token olinganidan keyin har so'rovda header: `Authorization: Bearer {token}`.

Super admin uchun kompaniya tanlash: `X-Company-Id: {company_id}` header yuborish mumkin.

## Company_id (kompaniya bo'yicha filtrlash)

- **Oddiy foydalanuvchi** (staff/admin): token'dagi user'ning `company_id` si avtomatik session'ga yoziladi; **barcha** endpoint'lar (dashboard, contacts, products, expenses) faqat shu kompaniya ma'lumotlarini qaytaradi.
- **Super admin**: agar `X-Company-Id` header yuborilsa, ma'lumotlar shu kompaniya bo'yicha; yuborilmasa, scope qo'yilmaydi (barcha kompaniyalar ko'rinadi).
- Modellar (Customer, Supplier, CustomerGroup, Product, Expense va b.) `company_id` ustuni orqali avtomatik filtrlangan; controller'lar ham qo'lda `company_id` ni ishlatadi.

---

## 1. Dashboard — barcha statistikalar

| Method | URL | Tavsif |
|--------|-----|--------|
| GET | `/api/v1/dashboard` | Barcha dashboard ma'lumotlari (basicData, barChartData, lineChartData, todayPaymentTypes, sellersReport, dailyProductsSold, todayIncomes, va b.) Query: `?date=Y-m-d` (ixtiyoriy). |
| GET | `/api/v1/dashboard/top-selling-products` | Oxirgi oy eng ko'p sotilgan 10 ta mahsulot. |

**Dasturda ishlatiladigan kalitlar (GET /dashboard haqiqiy javob):**
- **todayIncomes** (root) yoki **basicData.todaySales** — bugungi jami savdo
- **basicData.todayExpenses** — bugungi xarajatlar
- **todayPaymentTypes** (root): har birida **id**, **payment_method** (nom), **total_amount** (summa)
- **dailyProductsSold** (root): son (0) yoki list; list bo‘lmasa dastur GET /dashboard/top-selling-products ni chaqiradi
- **sellersReport** (root): order_count larni yig‘ib savdolar soni olinadi (agar transaction_count bo‘lmasa)

---

## 2. Contacts (mijozlar, yetkazib beruvchilar, guruhlar)

### Mijozlar (add, edit, delete mavjud)
| Method | URL | Tavsif |
|--------|-----|--------|
| POST | `/api/v1/contacts/customers` | Mijozlar ro'yxati. Javob: `datarows`, `count`, `totalDebt`. |
| GET | `/api/v1/contacts/customers-list` | Barcha mijozlar qisqa ro'yxati. Javob: `customers`. |
| POST | `/api/v1/contacts/customers/store` | Mijoz qo'shish. Body: `first_name` (majburiy), `last_name`, `phone_number`, `address`, `customer_group` (majburiy). |
| GET | `/api/v1/contacts/customers/{id}` | Bitta mijoz. Javob: `customer`. |
| POST | `/api/v1/contacts/customers/{id}` | Mijoz tahrirlash. |
| DELETE | `/api/v1/contacts/customers/{id}` | Mijoz o'chirish. |
| POST | `/api/v1/contacts/customers/{id}/debts` | Mijoz qarzlari (customer_debts). |

---

## 3. Products

| Method | URL | Tavsif |
|--------|-----|--------|
| POST | `/api/v1/products/list` | To'liq ro'yxat. Body: `rowLimit`, `rowOffset`. Javob: `datarows`, `count`, `totalQuantity`. |
| GET | `/api/v1/products/categories` | Barcha kategoriyalar. |
| POST | `/api/v1/products` | Yangi mahsulot qo'shish. |
| POST | `/api/v1/products/{id}/edit` | Mahsulot tahrirlash. |
| DELETE | `/api/v1/products/{id}` | Mahsulot o'chirish. |

---

## 4. Expenses

| Method | URL | Tavsif |
|--------|-----|--------|
| GET | `/api/v1/expenses` | Xarajatlar. Query: `from`, `to`. Javob: `expenses`, `total`, `paymentTypes`, `expenseCategories`. |
| POST | `/api/v1/expenses` | Yangi xarajat. Body: `name`, `price`, `payment_type_id`, `expense_category_id`, `note`. |
| DELETE | `/api/v1/expenses/{id}` | Xarajatni o'chirish. |

---

## 5. User

| Method | URL | Tavsif |
|--------|-----|--------|
| GET | `/api/v1/user` | Joriy foydalanuvchi (id, first_name, last_name, email). |
| POST | `/api/v1/user/profile` | Profil tahrir. |
| POST | `/api/v1/user/password` | Parol o'zgartirish. |

---

## Autentifikatsiya

- **Login:** `POST /api/v1/login` — body: `email`, `password`, `company_id`. Javobda `token`.
- **Logout:** `POST /api/v1/logout` — header: `Authorization: Bearer {token}`.
