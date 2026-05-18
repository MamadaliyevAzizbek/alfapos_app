# Mahsulotlar API — to‘liq qo‘llanma (Mobile & Desktop / Flutter)

**Bitta hujjat:** web `/products` dagi **4 tab** (Mahsulotlar, Kategoriyalar, Brendlar, O‘lchov birliklari), **qo‘shish/tahrir**, filterlar va qator amallari.

**Baza:** `https://your-domain.com`  
**Prefix:** `/api/v1/products`  
**Auth:** `Authorization: Bearer {token}`  
**Middleware:** `auth:sanctum`, `set.company.api`

---

## Mundarija

1. [Modul tuzilishi](#1-modul-tuzilishi)
2. [Tab: Mahsulotlar — ro‘yxat](#2-tab-mahsulotlar--royxat)
3. [Mahsulot qo‘shish va tahrirlash](#3-mahsulot-qoshish-va-tahrirlash)
4. [Mahsulot tafsiloti](#4-mahsulot-tafsiloti)
5. [Tab: Kategoriyalar](#5-tab-kategoriyalar)
6. [Tab: Brendlar](#6-tab-brendlar)
7. [Tab: O‘lchov birliklari](#7-tab-olchov-birliklari)
8. [Barcha endpointlar jadvali](#8-barcha-endpointlar-jadvali)

---

## 1. Modul tuzilishi

| Web tab | Flutter ekran | Birinchi yuklash |
|---------|---------------|------------------|
| Mahsulotlar | `ProductsListScreen` | `GET /filter-options` + `POST /list` |
| Kategoriyalar | `CategoriesScreen` | `POST /categories/list` |
| Brendlar | `BrandsScreen` | `POST /brands/list` |
| O‘lchov birliklari | `UnitsScreen` | `POST /units/list` |

**Web bilan bir xil controller’lar:** `ProductsController`, `ProductCategoriesController`, `ProductBrandsController`, `ProductUnitsController`, `V1\ProductApiController` (qisqa REST).

---

## 2. Tab: Mahsulotlar — ro‘yxat

### 2.1 Yuqori qism (web `AllProducts.vue`)

| UI element | Vazifa | API |
|------------|--------|-----|
| **+ Qo‘shish** | Yangi mahsulot formasi | `POST /` yoki `POST /store` |
| **Inventarlar** | Ombor/inventar sahifasi | Web route (mobilda alohida modul) |
| **⋮ → Import** | Excel import | `POST /import` (web; API hujjatda ixtiyoriy) |
| **⋮ → Bulk delete** | Tanlanganlarni o‘chirish | `POST /bulk-delete` |

### 2.2 Filter dropdown’lari

Web: `GET /products/supporting-data` → `category`, `brand`, `group` (`{text, value}`).

Mobile (bir xil format):

```http
GET /api/v1/products/filter-options
```

**Javob:**

```json
{
  "category": [{ "text": "Ichimliklar", "value": 3 }],
  "brand": [{ "text": "Coca-Cola", "value": 1 }],
  "group": [{ "text": "Guruh 1", "value": 2 }],
  "variant": []
}
```

**Forma uchun to‘liq ma’lumot** (kategoriya, brend, birlik, soliq, filial):

```http
GET /api/v1/products/supporting-data
```

**Javob kalitlari:** `brands`, `categories`, `groups`, `units`, `taxes`, `branches`.

### 2.3 Mahsulotlar jadvali (asosiy ro‘yxat)

```http
POST /api/v1/products/list
```

**Body (web datatable bilan bir xil):**

```json
{
  "rowLimit": 20,
  "rowOffset": 0,
  "searchValue": "",
  "columnKey": "id",
  "columnSortedBy": "DESC",
  "showZeroStock": "0",
  "filtersData": [
    { "key": "status", "value": "all" },
    { "key": "category", "value": "all" },
    { "key": "brand", "value": "all" }
  ]
}
```

| Filter `key` | `value` |
|--------------|---------|
| `status` | `all`, `active`, `inactive` |
| `category` | `all` yoki kategoriya `id` |
| `brand` | `all` yoki brend `id` |
| `group` | `all` yoki guruh `id` (ixtiyoriy) |

**Javob:**

```json
{
  "datarows": [
    {
      "id": 12,
      "title": "Coca-Cola 0.5",
      "imageURL": "product_xxx.jpg",
      "category_name": "Ichimliklar",
      "brand_name": "Coca-Cola",
      "purchase_price": 10000,
      "selling_price": 15000,
      "product_quantity": 25,
      "is_liked": 0,
      "variants": []
    }
  ],
  "count": 8058,
  "totalQuantity": 120500
}
```

### 2.4 Jadval ustunlari

| Ustun | Maydon | Izoh |
|-------|--------|------|
| RASM | `imageURL` | `https://domain/uploads/products/{imageURL}` |
| SARLAVHA | `title` | Bosish → tafsilot |
| KATEGORIYA | `category_name` | |
| BREND | `brand_name` | |
| XARID NARXI | `purchase_price` | USD: frontend kurs bilan |
| SOTUV NARX | `selling_price` | |
| MIQDORI | `product_quantity` | Butun son ko‘rinishi |
| AMAL | ⋮ menyu | Quyida |

**Status dropdown’dagi jami son:** `count` (masalan: `8 058 шт`).

### 2.5 Qator ⋮ menyu (AMAL)

| Tugma | API |
|-------|-----|
| **Tahrirlash** | `GET /{id}/edit-data` → forma; `POST /{id}/edit` → saqlash |
| **Yoqtirish** (sotuvda tepada) | `POST /toggle-like/{id}` |
| **O‘chirish** | `DELETE /{id}` |

**Yoqtirish javobi:**

```json
{ "status": "success", "liked": true, "product_id": 12 }
```

### 2.6 Ko‘p tanlov — o‘chirish

```http
POST /api/v1/products/bulk-delete
```

```json
{ "ids": [12, 15, 20] }
```

---

## 3. Mahsulot qo‘shish va tahrirlash

### 3.1 Tahrir formasini yuklash

```http
GET /api/v1/products/{id}/edit-data
```

**Javob (asosiy):**

- `productDetails` — `title`, `category_id`, `brand_id`, `unit_id`, `product_type`, `imageURL`, ...
- `variantDetails` — narxlar, barcode, SKU, miqdor
- `productSupportingData` — dropdown’lar
- `variantData`, `relatedProducts` — variant mahsulotda

Web: `GET /products/edit-product/{id}` — **bir xil metod**.

### 3.2 Yangi mahsulot

**Variant A (V1 — qisqa REST, ba’zi maydonlar cheklangan):**

```http
POST /api/v1/products/
```

**Variant B (web bilan 100% bir xil — `ProductAddEditModal.vue` payload):**

```http
POST /api/v1/products/store
```

Tahrir: `POST /api/v1/products/{id}/edit` — **qo‘shish bilan bir xil body** (+ `image: 'DELETE'` rasmni olib tashlash uchun).

---

#### 3.2.1 Umumiy (mahsulot darajasi) — barcha inputlar

Web forma 4 bo‘lim: **Asosiy**, **Narxlar**, **Ombor** (faqat yangi + filial bor), **Xususiyatlar** (restaurant filial).

| UI (web) | API maydoni | Turi | Majburiy | Izoh |
|----------|-------------|------|----------|------|
| Nomi | `name` | string | Ha | |
| Nakladnoy nomi | `nakladnoyTitle` / `nakladnoy_title` | string | Yo‘q | Sozlama yoqilgan bo‘lsa |
| Muqobil nom | `alternateTitle` / `alternate_title` | string | Yo‘q | |
| O‘lchov birligi | `unit` | int | Tavsiya | |
| Kategoriya | `category` | int | Yo‘q | |
| Brend | `brand` | int | Yo‘q | Sozlama yoqilgan bo‘lsa |
| Taminotchi | `supplierId` / `supplier_id` | int \| null | Yo‘q | |
| Guruh | `group` | int | Yo‘q | |
| Soliq | `taxID` | string | Yo‘q | `no-tax`, `default-tax`, yoki soliq `id` |
| Tavsif | `description` | string | Yo‘q | |
| Rasm | `image` | base64 / file | Yo‘q | Tahrirda: bo‘sh = o‘zgartirmaslik; `'DELETE'` = o‘chirish |
| Mahsulot turi | `type` | 0 \| 1 | Ha | `0` = standart, `1` = variant |
| Filiallar (ombor) | `branch`, `branchId` | int | Yangi + kirimda | Bir nechta filial bo‘lsa majburiy |

---

#### 3.2.2 Standart mahsulot (`type: 0`) — identifikator va narxlar

| UI (web) | API maydoni | Turi | Izoh |
|----------|-------------|------|------|
| Shtrix-kod | `barcode` | string | Birinchi barcode; qolganlari `additionalBarcodes` |
| Qo‘shimcha barcode | `additionalBarcodes` | string[] | Vergul bilan bir nechta kiritilsa web ajratadi |
| Artikul (SKU) | `sku` | string | Prefiks serverda qo‘shiladi |
| PLU | `plu_code` | string | Tarozi uchun (max 10) |
| Xarid narxi | `receivingPrice` | number | |
| Xarid valyutasi | `purchasePriceCurrency` | `uzs` \| `usd` | |
| Sotuv narxi | `sallingPrice` | number | **Eslatma:** web `sallingPrice` (ikki `l`) |
| Sotuv valyutasi | `sellingPriceCurrency` | `uzs` \| `usd` | |
| Ulgurji narxi | `wholesalePrice` | number \| `''` | Bo‘sh = o‘chirish (tahrir) |
| Ulgurji valyutasi | `wholesalePriceCurrency` | `uzs` \| `usd` | |
| Pachka bormi | `unitsPerPackage` | number \| null | `null` = pachka yo‘q |
| Pachka nomi | `packageLabel` | string | masalan: `Pachka`, `Quti` |
| Pachkada dona | `unitsPerPackage` | number | |
| Pachka xarid narxi | `packagePurchasePrice` | number \| null | |
| Pachka sotuv narxi | `packageSellingPrice` | number \| null | |
| Pachka xarid valyutasi | `packagePurchasePriceCurrency` | `uzs` \| `usd` | |
| Pachka sotuv valyutasi | `packageSellingPriceCurrency` | `uzs` \| `usd` | |
| Qayta buyurtma | `reorder` | number | Minimal qoldiq |
| Faol | `enabled` | bool \| 1/0 | Standartda odatda `true` |
| Boshlang‘ich miqdor | `quantity` | number | >0 bo‘lsa kirim (receiving) yaratiladi |
| Variantlar (bo‘sh) | `variantDetails` | `[]` | Standartda bo‘sh massiv yuboriladi |

---

#### 3.2.3 Variant mahsulot (`type: 1`)

| UI (web) | API maydoni | Turi | Izoh |
|----------|-------------|------|------|
| Atribut qiymatlari | `chipValues` | object | Atribut id → qiymatlar massivi |
| Variant qatorlari | `variantDetails` | array | Har bir variant (quyidagi jadval) |
| Variant rasmlari | `variantImage` | array | Ixtiyoriy |
| Eski maydon | `variant` | string | Legacy |

**`variantDetails[]` har bir element (web jadvali):**

| Maydon | Turi | Izoh |
|--------|------|------|
| `variant` | string | Variant nomi / atribut kombinatsiyasi |
| `enabled` | bool | |
| `barcode` | string | |
| `sku` | string | |
| `purchasePrice` | number | |
| `sellingPrice` | number | |
| `purchasePriceCurrency` | string | |
| `sellingPriceCurrency` | string | |
| `wholesalePrice` | number | |
| `wholesalePriceCurrency` | string | |
| `unitsPerPackage` | number \| null | |
| `packagePurchasePrice` | number \| null | |
| `packageSellingPrice` | number \| null | |
| `packagePurchasePriceCurrency` | string | |
| `packageSellingPriceCurrency` | string | |
| `packageLabel` | string | |
| `reOrder` | number | |
| `qty` | number | Boshlang‘ich miqdor (variant uchun) |
| `imageURL` | base64 | Variant rasmi |

---

#### 3.2.4 Restaurant — qo‘shimcha mahsulotlar

Faqat restaurant tipidagi filialda (`hasRestaurantBranch`).

| UI | API maydoni | Turi |
|----|-------------|------|
| Bog‘langan mahsulot | `relatedProducts[].related_product_id` | int |
| Variant | `relatedProducts[].related_variant_id` | int \| null |
| Miqdor | `relatedProducts[].quantity` | number |

---

#### 3.2.5 To‘liq misol — standart mahsulot (web payload)

```json
{
  "name": "Coca-Cola 0.5",
  "alternateTitle": "",
  "nakladnoyTitle": "",
  "description": "Sovuq ichimlik",
  "taxID": "no-tax",
  "category": 3,
  "brand": 1,
  "supplierId": null,
  "group": null,
  "unit": 2,
  "branch": 1,
  "type": 0,
  "receivingPrice": 10000,
  "sallingPrice": 15000,
  "purchasePriceCurrency": "uzs",
  "sellingPriceCurrency": "uzs",
  "wholesalePrice": 14000,
  "wholesalePriceCurrency": "uzs",
  "unitsPerPackage": 12,
  "packagePurchasePrice": 110000,
  "packageSellingPrice": 165000,
  "packagePurchasePriceCurrency": "uzs",
  "packageSellingPriceCurrency": "uzs",
  "packageLabel": "Pachka",
  "sku": "ART-001",
  "barcode": "4601234567890",
  "additionalBarcodes": ["4601234567891"],
  "plu_code": "1001",
  "reorder": 5,
  "quantity": 100,
  "enabled": true,
  "variantDetails": [],
  "chipValues": [],
  "image": "data:image/jpeg;base64,...",
  "relatedProducts": []
}
```

**Javob (store):**

```json
{
  "success": true,
  "message": "...",
  "data": { "id": 12345 }
}
```

---

#### 3.2.6 V1 `POST /products/` farqi

V1 controller qisqaroq: `name`, `type`, `category`, `brand`, `group`, `unit`, `taxID`, `image` / `image_base64`, `quantity`, `branch`, `receivingPrice`, `sellingPrice`, `barcode`, `sku`, `additionalBarcodes`, `variants[]`.

**V1 da hozir to‘liq qo‘llab-quvvatlanmaydi (web store ga murojaat qiling):** `nakladnoyTitle`, `wholesalePrice`, pachka maydonlari (`unitsPerPackage`, `packageLabel`, ...), `plu_code`, `supplierId`, `chipValues`, `relatedProducts`, variant ichidagi valyuta/pachka detallari.

**Tavsiya:** mobil ilova mahsulot qo‘shish/tahrir uchun **`POST /store`** va **`POST /{id}/edit`** ishlatsin — web bilan bir xil.

### 3.3 Tahrirlash

```http
POST /api/v1/products/{id}/edit
```

Web: `POST /products/edit/{id}` — **bir xil `editProduct` metodi**.

Body: qo‘shish bilan bir xil (`name`, `category`, `brand`, `group`, `unit`, `taxID`, `type`, `variantDetails`, `quantity`, `image`, ...).

---

## 4. Mahsulot tafsiloti

```http
GET /api/v1/products/{id}/details
```

Web: `GET /products/getDetails/{id}`.

Qisqa ko‘rinish: `GET /api/v1/products/{id}` (V1 `show` — JSON mahsulot + relations).

---

## 5. Tab: Kategoriyalar

Web manba: `POST /products/categories` (jadval), `POST /products/category/store`, `GET/POST /products/category/{id}`, `POST /products/category/delete/{id}`.

| Amal | API |
|------|-----|
| Ro‘yxat | `POST /categories/list` |
| Dropdown (barcha) | `GET /categories` |
| Qo‘shish | `POST /categories/store` yoki `POST /categories` (legacy) |
| Bitta olish | `GET /categories/{id}` |
| Tahrirlash | `POST /categories/{id}` body: `{ "name": "..." }` |
| O‘chirish | `DELETE /categories/{id}` |

**Ro‘yxat body:**

```json
{
  "rowLimit": 20,
  "rowOffset": 0,
  "columnKey": "name",
  "columnSortedBy": "asc"
}
```

**Javob:** `{ "datarows": [{ "id": 1, "name": "Ichimliklar" }], "count": 10 }`

---

## 6. Tab: Brendlar

Web manba: `POST /products/brands`, `POST /products/brand/store`, `GET/POST /products/brand/{id}`, `POST /products/brand/delete/{id}`.

| Amal | API |
|------|-----|
| Ro‘yxat | `POST /brands/list` |
| Dropdown (barcha) | `GET /brands` |
| Qo‘shish | `POST /brands/store` body: `{ "name": "Coca-Cola" }` |
| Bitta olish | `GET /brands/{id}` |
| Tahrirlash | `POST /brands/{id}` body: `{ "name": "..." }` |
| O‘chirish | `DELETE /brands/{id}` |

Mahsulotda ishlatilgan brendni o‘chirib bo‘lmaydi — `200` + xabar (`in_use`).

---

## 7. Tab: O‘lchov birliklari

Web manba: `POST /products/units`, `POST /products/unit/store`, `GET/POST /products/unit/{id}`, delete.

| Amal | API |
|------|-----|
| Ro‘yxat | `POST /units/list` |
| Qo‘shish | `POST /units/store` yoki `POST /units` (legacy) |
| Bitta olish | `GET /units/{id}` |
| Tahrirlash | `POST /units/{id}` body: `{ "name": "Dona", "shortname": "dona" }` |
| O‘chirish | `DELETE /units/{id}` |

**Jadval ustunlari:** `name`, `short_name` (API da `shortname` yuboriladi).

---

## 8. Barcha endpointlar jadvali

| Method | Endpoint | Web ekvivalenti | Vazifa |
|--------|----------|-----------------|--------|
| GET | `/products/filter-options` | `GET /products/supporting-data` | Filter dropdown |
| GET | `/products/supporting-data` | `GET /products/all-supporting-data` | Forma dropdown’lari |
| POST | `/products/list` | `POST /products/products` | Mahsulotlar ro‘yxati |
| POST | `/products/` | `POST /products/store` | Yangi mahsulot (V1) |
| POST | `/products/store` | `POST /products/store` | Yangi mahsulot (web) |
| GET | `/products/{id}/edit-data` | `GET /products/edit-product/{id}` | Tahrir formasi |
| POST | `/products/{id}/edit` | `POST /products/edit/{id}` | Saqlash |
| GET | `/products/{id}/details` | `GET /products/getDetails/{id}` | Tafsilot |
| GET | `/products/{id}` | — | Qisqa JSON (V1) |
| DELETE | `/products/{id}` | `POST /products/delete/{id}` | O‘chirish |
| POST | `/products/bulk-delete` | `POST /products/bulk-delete` | Ko‘p o‘chirish |
| POST | `/products/toggle-like/{id}` | `POST /products/toggle-like/{id}` | Yoqtirish |
| GET | `/products/categories` | `GET /products/category` | Barcha kategoriyalar |
| POST | `/products/categories/list` | `POST /products/categories` | Kategoriya jadvali |
| POST | `/products/categories/store` | `POST /products/category/store` | Qo‘shish |
| GET/POST/DELETE | `/products/categories/{id}` | `category/{id}`, delete | CRUD |
| GET | `/products/brands` | `GET /products/brand` | Barcha brendlar |
| POST | `/products/brands/list` | `POST /products/brands` | Brend jadvali |
| POST | `/products/brands/store` | `POST /products/brand/store` | Qo‘shish |
| GET/POST/DELETE | `/products/brands/{id}` | `brand/{id}`, delete | CRUD |
| POST | `/products/units/list` | `POST /products/units` | Birlik jadvali |
| POST | `/products/units/store` | `POST /products/unit/store` | Qo‘shish |
| GET/POST/DELETE | `/products/units/{id}` | `unit/{id}`, delete | CRUD |

---

## Flutter — tez integratsiya

```dart
// 1. Filterlar
final filters = await dio.get('/api/v1/products/filter-options');

// 2. Ro'yxat
final list = await dio.post('/api/v1/products/list', data: {
  'rowLimit': 20,
  'rowOffset': 0,
  'searchValue': search,
  'filtersData': [
    {'key': 'status', 'value': 'all'},
    {'key': 'category', 'value': categoryId ?? 'all'},
    {'key': 'brand', 'value': brandId ?? 'all'},
  ],
});

// 3. Tahrir
final edit = await dio.get('/api/v1/products/$id/edit-data');
await dio.post('/api/v1/products/$id/edit', data: formMap);
```

---

## Xatoliklar

| HTTP | Sabab |
|------|--------|
| 401 | Token yo‘q yoki muddati tugagan |
| 404 | Mahsulot/kategoriya/brend topilmadi |
| 422 | Validatsiya (V1 `store`) |
| 200 + xabar | Kategoriya/brend/birlik mahsulotda ishlatilgan — o‘chirib bo‘lmaydi |

**Rasm URL:** `{APP_URL}/uploads/products/{imageURL}`
