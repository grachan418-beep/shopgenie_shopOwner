# INTEGRATION AUDIT — ShopGenie Owner App × Shared Django Backend
> Generated: 2026-10-26  
> Auditor: Antigravity (AI assistant)  
> Status: **PART 1 COMPLETE — no code changes made**

---

## Project Paths (corrected)

| Role | Path |
|------|------|
| Owner app (Android/Kotlin) | `R:\shopgenie-main\app\src\main\java\com\example\` |
| Shared Django backend | `R:\shopgenie backend\shopgenie_unified\` |
| Customer app (Flutter, read-only) | `R:\shopGiene customer\Shopgenie-customer-\flutter_shopgenie\` |
| Archived legacy backend | `R:\shopgenie-main\_removed_backup\shopgenie_backend_legacy\` — retained for reference; **not used** |

---

## A. BACKEND — Full Endpoint Catalogue

### A1. Authentication (`/api/auth/`)

| Method | URL | Auth | Request Fields | Response Fields |
|--------|-----|------|---------------|-----------------|
| POST | `/api/auth/login/` | None | `username`, `password` | `access`, `refresh`, `user{id, username, email, role}` |
| POST | `/api/auth/register/owner/` | None | `username`, `email`, `password`, `shop_name` | `access`, `refresh`, `user{…}`, `shop{id, name, status}` |
| POST | `/api/auth/register/customer/` | None | `username`, `email`, `password` | `access`, `refresh`, `user{…}` |
| POST | `/api/auth/refresh/` | None | `refresh` | `access`, `refresh` |

> **Note**: There is **NO** `/api/auth/me/` endpoint in the shared backend. The Owner app calls this — it must be removed or handled.  
> **Role values**: `SHOP_OWNER`, `SHOP_WORKER`, `CUSTOMER` (from `CustomUser.Role` enum).

---

### A2. Shops (`/api/shops/`) — Owner endpoints

| Method | URL | Auth/Role | Request Fields | Response Fields (ShopOwnerSerializer) |
|--------|-----|-----------|---------------|---------------------------------------|
| GET | `/api/shops/my_shop/` | `SHOP_OWNER` JWT | — | `id, name, category, description, address, phone, business_hours, status, rating` |
| PATCH | `/api/shops/my_shop/` | `SHOP_OWNER` JWT | any subset of above (partial) | same |
| GET | `/api/shops/dashboard/` | `SHOP_OWNER` JWT | — | `shop_id, shop_name, shop_status, total_products, available_products, low_stock_products, active_offers, total_invoices, total_sales, today_invoices, today_sales, active_workers, recent_invoices[]` |

### A2b. Shops — Public endpoints

| Method | URL | Auth | Response Fields (ShopPublicSerializer) |
|--------|-----|------|----------------------------------------|
| GET | `/api/shops/` | None | paginated `{count, next, previous, results[{id, name, category, description, address, phone, business_hours, hours, rating, status}]}` — only `PUBLISHED` shops |
| GET | `/api/shops/<id>/` | None | single shop (same fields) |

> `hours` is a read-only alias for `business_hours`. Both fields appear in the public response.  
> `status` valid values: `DRAFT`, `PUBLISHED`, `SUSPENDED`.

---

### A3. Products (`/api/products/`)

| Method | URL | Auth/Role | Request Fields (ProductWriteSerializer) | Response Fields |
|--------|-----|-----------|----------------------------------------|-----------------|
| GET | `/api/products/` | None (public) or JWT | `?shop=<id>`, `?category=`, `?search=` | Public: `id, shop, store_id, store_name, name, category, brand, size, description, mrp, selling_price, price, stock_quantity, unit, image_url`. Owner/Worker: adds `cost_price, status` |
| GET | `/api/products/<id>/` | None (public) or JWT | — | same as list |
| POST | `/api/products/` | `SHOP_OWNER` or active `SHOP_WORKER` | `shop, name, category, brand, size, description, mrp, selling_price, cost_price, stock_quantity, unit, image_url, status` | ProductOwnerSerializer |
| PATCH | `/api/products/<id>/` | `SHOP_OWNER` or active `SHOP_WORKER` | any subset | ProductOwnerSerializer |
| DELETE | `/api/products/<id>/` | `SHOP_OWNER` or active `SHOP_WORKER` | — | 204 |

> `unit` valid values: `PIECE`, `KG`, `LITRE`, `PACKET`, `DOZEN` (from `Product.Unit` choices).  
> `status` valid values: `PUBLISHED`, `DRAFT`, `DISCONTINUED`.  
> `mrp >= selling_price >= cost_price` is validated server-side.  
> **No** `/api/products/register/` or `/api/products/match/` endpoints exist in the shared backend.

---

### A4. Inventory / Stock Adjustments (`/api/inventory/`)

| Method | URL | Auth/Role | Request Fields | Response Fields |
|--------|-----|-----------|---------------|-----------------|
| GET | `/api/inventory/` | `SHOP_OWNER` or `SHOP_WORKER` | — | list of `{id, product, delta, reason, note, created_at}` for shop |
| POST | `/api/inventory/` | `SHOP_OWNER` or `SHOP_WORKER` | `product` (int), `delta` (nonzero decimal), `reason`, `note` | same single object |
| GET/PATCH/DELETE | `/api/inventory/<id>/` | OWNER/WORKER | — | — |

> `delta` negative = stock reduction, positive = addition. Backend atomically updates `product.stock_quantity`.  
> `reason` valid values: `PURCHASE`, `SALE`, `RETURN`, `DAMAGE`, `CORRECTION`, `OTHER`.

---

### A5. Billing / Invoices (`/api/billing/` and `/api/invoices/`)

Both URL prefixes map to the same views (both are registered in `shopgenie\urls.py`).

| Method | URL | Auth/Role | Request Fields | Response Fields |
|--------|-----|-----------|---------------|-----------------|
| GET | `/api/billing/invoices/` | OWNER/WORKER (with `can_view_invoices`) | — | list `{id, idempotency_key, total_amount, status, created_at}` |
| GET | `/api/billing/invoices/<id>/` | OWNER/WORKER | — | `{id, shop, idempotency_key, total_amount, status, created_at, items[{id, product, product_name, quantity, unit_price, line_total}]}` |
| POST | `/api/billing/invoices/` | OWNER or WORKER with `can_confirm_bills` | `idempotency_key` (str), `items: [{product (int), quantity (decimal)}]` | same detail as GET + 201 |
| POST | `/api/billing/flutter/` | same | same | same |
| POST | `/api/invoices/invoices/` | same | same | same |

> Idempotency: reusing same key with same payload → 200 (returns existing invoice). Same key, different payload → 409 CONFLICT.  
> Invoice creation atomically deducts stock from all products via `StockAdjustment`.  
> **No** `/api/checkout/accept/` endpoint exists in the shared backend.

---

### A6. Workers (`/api/workers/`)

| Method | URL | Auth/Role | Request Fields | Response Fields |
|--------|-----|-----------|---------------|-----------------|
| GET | `/api/workers/` | `SHOP_OWNER` only | — | list of workers for owner's shop |
| POST | `/api/workers/` | `SHOP_OWNER` only | `username, email, password, first_name, last_name, is_worker_active, can_view_invoices, can_confirm_bills` | WorkerSerializer |
| GET | `/api/workers/<id>/` | `SHOP_OWNER` only | — | `{id, username, email, first_name, last_name, is_worker_active, can_view_invoices, can_confirm_bills, date_joined}` |
| PATCH | `/api/workers/<id>/` | `SHOP_OWNER` only | any of: `first_name, last_name, is_worker_active, can_view_invoices, can_confirm_bills` | WorkerSerializer |
| DELETE | `/api/workers/<id>/` | `SHOP_OWNER` only | — | 204 |

---

### A7. Offers (`/api/offers/`)

| Method | URL | Auth/Role | Request Fields | Response Fields (OfferSerializer) |
|--------|-----|-----------|---------------|-----------------------------------|
| GET | `/api/offers/` | None (public) | `?shop=<id>` | Active + valid-dated offers only for public |
| GET | `/api/offers/<id>/` | None | — | single offer |
| POST | `/api/offers/` | `SHOP_OWNER` | `title, description, discount_type, discount_value, scope, applicable_product, start_date, end_date, is_active` | `{id, shop, shop_name, title, description, discount_type, discount_value, scope, applicable_product, product_name, start_date, end_date, is_active, is_valid, created_at, updated_at}` |
| PATCH | `/api/offers/<id>/` | `SHOP_OWNER` | any subset | same |
| DELETE | `/api/offers/<id>/` | `SHOP_OWNER` | — | 204 |

> `discount_type`: `PERCENTAGE` or `FLAT`.  
> `scope`: `STORE_WIDE` or `PRODUCT`.  
> Owner GET returns ALL shop offers (including inactive/expired). Public GET returns only active + date-valid ones.

---

### A8. Announcements (`/api/announcements/`)

| Method | URL | Auth/Role | Request Fields | Response Fields |
|--------|-----|-----------|---------------|-----------------|
| GET | `/api/announcements/` | None (public) | `?shop=<id>` | PUBLISHED only |
| POST | `/api/announcements/` | `SHOP_OWNER` | `title, content, status` | `{id, shop, shop_name, title, content, status, created_by, created_at, updated_at}` |
| PATCH | `/api/announcements/<id>/` | `SHOP_OWNER` | any subset | same |
| DELETE | `/api/announcements/<id>/` | `SHOP_OWNER` | — | 204 |

> `status` valid values: `DRAFT`, `PUBLISHED`.

---

### A9. Notifications (`/api/notifications/`)

| Method | URL | Auth | Response Fields |
|--------|-----|------|-----------------|
| GET | `/api/notifications/` | Authenticated | list `{id, recipient, title, message, notification_type, is_read, created_at}` |
| POST | `/api/notifications/read_all/` | Authenticated | `{status: "all_marked_read"}` |

---

## B. OWNER APP — Demo/Mock Code Inventory

File: `app/src/main/java/com/example/`

### B1. `data/api/NetworkClient.kt`
| Location | Mock/Demo Pattern | Description |
|----------|-------------------|-------------|
| L28 | `KEY_SHOP_NAME = "shop_name"` | Shop name stored locally in SharedPreferences |
| L71 | `currentShopName = "My Kirana Store"` | **Hardcoded fallback** shop name — never fetched from backend |
| L32 | `DEFAULT_ESP32_URL = "http://192.168.1.100:81/stream"` | Hardcoded hardware IP — not configurable at compile time |
| L32 | `DEFAULT_BASE_URL = "http://10.0.2.2:8000/"` | Acceptable emulator default but 127.0.0.1 used when not emulator |

### B2. `data/api/ShopGenieApiService.kt`
| Location | Mock/Demo Pattern | Description |
|----------|-------------------|-------------|
| L11 | `POST api/auth/register/` | Wrong URL — backend uses `/api/auth/register/owner/` |
| L20 | `GET api/auth/me/` | **Ghost endpoint** — does NOT exist in shared backend |
| L27 | `POST api/products/register/` | Wrong URL — backend uses `POST api/products/` |
| L33 | `PUT api/products/{id}/` | Wrong method — backend uses `PATCH` |
| L39 | `POST api/products/match/` | **Ghost endpoint** — vision matching is in internal backend, not shared |
| L43 | `POST api/vision/capture/` | **Ghost endpoint** — vision module not in shared backend |
| L47 | `POST api/vision/embed/` | **Ghost endpoint** — same |
| L50 | `POST api/checkout/accept/` | Wrong URL — shared backend uses `POST api/billing/invoices/` |
| L53 | `GET api/checkout/invoices/` | Wrong URL — should be `GET api/billing/invoices/` |
| L56 | `GET api/checkout/invoices/{id}/` | Wrong URL — should be `GET api/billing/invoices/<id>/` |

### B3. `data/models/ApiModels.kt`
| Location | Mock/Demo Pattern | Description |
|----------|-------------------|-------------|
| `ProductDto` | `sellingType` (KG/UNIT) | **MISMATCH** — backend has `unit` (PIECE/KG/LITRE/PACKET/DOZEN) + `status`, not `sellingType` |
| `ProductDto` | `price_per_unit` | **MISMATCH** — backend field is `selling_price` |
| `ProductDto` | `quantity` | **MISMATCH** — backend field is `stock_quantity` |
| `ProductDto` | `formatted_quantity` | **MISSING** — not returned by shared backend |
| `ProductDto` | `feature_vector` | **MISSING** — vision feature, not in shared backend |
| `ProductDto` | `is_loose` | **MISSING** — internal backend concept only |
| `ProductCreateRequest` | `sellingType`, `pricePerUnit`, `quantity`, `isLoose`, `featureVector` | All wrong field names for shared backend |
| `AuthResponse` | `user.shopName`, `user.phoneNumber` | Backend login returns `role`, not `shopName` or `phoneNumber` |
| `UserDto` | `shopName`, `phoneNumber` | Not in backend `/api/auth/login/` response |
| `InvoiceDto` | `items[].totalPrice` | Backend field is `line_total`, not `total_price` |
| `CheckoutAcceptRequest` | `productId`, `invoiceId`, `quantity` | Completely wrong — shared backend uses idempotency-key + items list |
| `CheckoutAcceptResponse` | `invoice`, `billedItem`, `remainingStock` | Completely wrong response shape |
| `MatchProductRequest`, `MatchResponse`, `LooseCandidateDto` | All vision/match fields | **Not applicable** — shared backend has no match endpoint |
| `EmbedResponse`, `CaptureResponse` | All vision fields | **Not applicable** — shared backend has no vision endpoints |

### B4. `ui/screens/LoginScreen.kt`
| Location | Mock/Demo Pattern | Description |
|----------|-------------------|-------------|
| L67-68 | `networkClient.currentShopName = body.user?.shopName ?: "My Kirana Store"` | `shopName` not returned by backend; falls back to hardcoded string |
| L44-45 | `lateinit var serverUrl` bound to `networkClient.baseUrl` | OK — configurable. Not mock data |

### B5. `ui/screens/HomeScreen.kt`
| Location | Mock/Demo Pattern | Description |
|----------|-------------------|-------------|
| L37 | `val shopName = networkClient.currentShopName ?: "My Kirana Store"` | Reads stale SharedPrefs value, never refreshed from API |
| L38 | `val username = networkClient.currentUsername ?: "Shopkeeper"` | Same |

### B6. `ui/screens/CheckoutScreen.kt`
| Location | Mock/Demo Pattern | Description |
|----------|-------------------|-------------|
| L32 | `val shopName = networkClient.currentShopName ?: "ShopGenie Kirana"` | Hardcoded fallback |
| L50-65 | Sequential `checkoutAccept()` loop per item | Wrong billing pattern — shared backend takes all items in one atomic POST |

### B7. `ui/screens/AddProductScreen.kt`
| Location | Mock/Demo Pattern | Description |
|----------|-------------------|-------------|
| L65-73 | `ProductCreateRequest(sellingType, costPrice, pricePerUnit, quantity, isLoose)` | Wrong field names — backend needs `mrp`, `selling_price`, `cost_price`, `stock_quantity`, `unit`, `shop` |
| L75 | `networkClient.apiService.registerProduct(req)` | Calls non-existent `POST api/products/register/` |

### B8. `ui/screens/InventoryScreen.kt`
| Location | Mock/Demo Pattern | Description |
|----------|-------------------|-------------|
| L63 | `it.quantity <= 5.0` | References `ProductDto.quantity` — wrong field, backend uses `stock_quantity` |
| L64 | `it.pricePerUnit * it.quantity` | Wrong field names for valuation calc |
| L175 | `p.formattedQuantity ?: "${p.quantity} ${p.sellingType}"` | Both fields wrong/missing in shared backend |

### B9. `ui/screens/ProfileScreen.kt`
| Location | Mock/Demo Pattern | Description |
|----------|-------------------|-------------|
| L40-46 | `getCurrentUser()` call with silent `catch {}` | Calls ghost `/api/auth/me/` endpoint; silently swallowed on failure |
| L100 | `user?.shopName ?: networkClient.currentShopName ?: "My Kirana Store"` | Layered hardcoded fallback |

### B10. `ui/cart/CartManager.kt` (inferred from usage)
| Pattern | Description |
|---------|-------------|
| Singleton in-memory cart | Client-side cart state — correct for billing UX, but does NOT validate stock against backend |

### B11. `ui/screens/CameraScanScreen.kt` (inferred)
| Pattern | Description |
|---------|-------------|
| `POST api/products/match/` | Ghost endpoint — not in shared backend |
| `POST api/vision/capture/` | Ghost endpoint — ESP32-CAM feature from internal backend |

---

## C. OWNER SCREEN → BACKEND ENDPOINT MAPPING

| Owner Screen | Expected Backend Endpoint | Status | Issue Summary |
|---|---|---|---|
| LoginScreen | `POST /api/auth/login/` | ✅ MATCHES URL/method | Field mismatch: `shopName` not in response; need `role` |
| Registration | `POST /api/auth/register/owner/` | ❌ MISMATCH | App calls `/api/auth/register/` (missing `/owner/` suffix) |
| ProfileScreen | `GET /api/auth/me/` | ❌ MISSING | Endpoint does not exist in shared backend |
| HomeScreen (shop name/username) | None — reads SharedPrefs | ❌ NO API CALL | Must call `/api/shops/my_shop/` instead |
| InventoryScreen | `GET /api/products/` | ❌ MISMATCH | Wrong field names: `quantity`→`stock_quantity`, `pricePerUnit`→`selling_price` |
| AddProductScreen | `POST /api/products/register/` | ❌ MISMATCH | Wrong URL (`/register/` suffix), wrong field names, missing `shop` field |
| ProductDetailScreen | `GET /api/products/{id}/` | ✅ URL OK | Field names mismatched in model |
| ProductListScreen | `GET /api/products/` | ✅ URL OK | Field names mismatched |
| EditProduct (PUT) | `PATCH /api/products/{id}/` | ❌ MISMATCH | App uses PUT, backend only accepts PATCH |
| CameraScanScreen | `POST /api/products/match/` | ❌ MISSING | No match endpoint in shared backend |
| ESP32 capture | `POST /api/vision/capture/` | ❌ MISSING | Vision module in internal backend only |
| CheckoutScreen (billing) | `POST /api/billing/invoices/` | ❌ MISMATCH | App calls `/api/checkout/accept/` per item; should be single POST with all items + idempotency key |
| InvoiceListScreen | `GET /api/billing/invoices/` | ❌ MISMATCH | App calls `/api/checkout/invoices/` |
| InvoiceDetailScreen | `GET /api/billing/invoices/<id>/` | ❌ MISMATCH | App calls `/api/checkout/invoices/{id}/` |
| Workers (none visible) | `GET/POST /api/workers/` | ❌ MISSING | No worker management screen in this app |
| Offers (none visible) | `GET/POST /api/offers/` | ❌ MISSING | No offers screen in this app |
| Announcements (none) | `GET/POST /api/announcements/` | ❌ MISSING | No announcements screen in this app |
| My Shop (none visible) | `GET/PATCH /api/shops/my_shop/` | ❌ MISSING | No shop settings screen in this app |
| Dashboard (none dedicated) | `GET /api/shops/dashboard/` | ❌ MISSING | HomeScreen shows static/local data only |

---

## D. CUSTOMER APP — Endpoint & Field Audit (READ-ONLY)

Customer app: `R:\shopGiene customer\Shopgenie-customer-\flutter_shopgenie\`

### D1. Shops (`ShopApiService.fetchShops` / `fetchShopById`)

| Customer reads | Backend returns | Status |
|---|---|---|
| `id` (as String) | `id` (int) | ✅ Handled — `.toString()` |
| `name` | `name` | ✅ |
| `category` | `category` | ✅ |
| `description` | `description` | ✅ |
| `address` | `address` | ✅ |
| `phone` | `phone` | ✅ |
| `hours` via `json['hours'] ?? json['business_hours']` | `business_hours` (also aliased as `hours`) | ✅ |
| `rating` | `rating` | ✅ |
| `distance` | ❌ NOT returned | ⚠️ Falls back to `''` — no real distance |
| `emoji` | ❌ NOT returned | ⚠️ Falls back to `'🛒'` — hardcoded |
| `selfCheckout` | ❌ NOT returned | ⚠️ Falls back to `false` |
| `offer` | ❌ NOT returned | ⚠️ Falls back to `null` |
| `lat`, `lng` | ❌ NOT returned | ⚠️ Falls back to Bangalore coords `(12.9250, 77.5220)` |
| `followers`, `isFollowing` | ❌ NOT returned | ⚠️ Falls back to `384`, `false` |

> Customer app reads paginated `{results:[…]}` from `/api/shops/` — handled correctly.

### D2. Products (`fetchProductsForShop` / `searchProducts`)

| Customer reads | Backend returns (public) | Status |
|---|---|---|
| `id` | `id` | ✅ |
| `store_id` or `shop` | `store_id` (alias for `shop.id`) | ✅ App handles both |
| `store_name` | `store_name` | ✅ |
| `name` | `name` | ✅ |
| `brand`, `size`, `category`, `description` | same | ✅ |
| `price` OR `selling_price` | both `selling_price` and `price` (alias) | ✅ App handles both |
| `mrp` | `mrp` | ✅ |
| `stock_quantity` | `stock_quantity` | ✅ |
| `is_available` | ❌ NOT returned | ⚠️ Falls back to `stock_quantity > 0` |
| `unit` | `unit` | Not used by customer model |
| `image_url` | `image_url` | Not mapped in `ProductItem` |
| `status` | `status` | Not used by customer model (public API filters to PUBLISHED) |

### D3. Offers (`fetchOffers`)

| Customer reads | Backend returns | Status |
|---|---|---|
| `id`, `title`, `description`, `discount_type`, `discount_value` | ✅ same | ✅ |
| `start_date`, `end_date`, `is_active`, `scope` | ✅ same | ✅ |
| `shop`, `shop_name`, `applicable_product`, `product_name` | ✅ same | ✅ |

> Customer app handles both `{results:[…]}` and bare `[…]` offer responses.

### D4. Announcements (`fetchAnnouncements`)

| Customer reads | Backend returns | Status |
|---|---|---|
| `id`, `title`, `content`, `status`, `shop`, `shop_name`, `created_at` | ✅ same | ✅ |

> Customer app handles both paginated and non-paginated responses.

---

## E. CROSS-APP MAP — Owner Edits → Customer Reads

| Owner edits | Owner endpoint | Customer reads | Customer endpoint | Cross-app compatible? |
|---|---|---|---|---|
| Shop name / description / address / phone | PATCH `/api/shops/my_shop/` | `StoreItem.name`, `.address`, `.phone`, `.description` | GET `/api/shops/` | ✅ Same fields |
| Business hours | PATCH `/api/shops/my_shop/` (`business_hours`) | `StoreItem.hours` via `json['business_hours']` | GET `/api/shops/` | ✅ Aliased correctly |
| Shop publish/visibility | PATCH `/api/shops/my_shop/` (`status`) | Only `PUBLISHED` shops appear | GET `/api/shops/` filters `status=PUBLISHED` | ✅ |
| Product name / price / unit | PATCH `/api/products/<id>/` | `ProductItem.name`, `.price`, `.mrp`, `stock_quantity` | GET `/api/products/?shop=<id>` | ✅ Same fields |
| Product photo | PATCH `/api/products/<id>/` (`image_url`) | `image_url` field | GET `/api/products/` | ⚠️ Customer model doesn't display `image_url` yet |
| Product status (published) | PATCH `/api/products/<id>/` (`status=PUBLISHED`) | Only PUBLISHED in public list | GET `/api/products/` filters | ✅ |
| Stock quantity | POST `/api/inventory/` (`delta`) | `ProductItem.stock` via `stock_quantity` | GET `/api/products/?shop=<id>` | ✅ |
| Unpublished product | `status=DRAFT` or `DISCONTINUED` | Must NOT appear | Backend filters public list | ✅ |
| Offers | POST `/api/offers/` | `OfferItem` | GET `/api/offers/?shop=<id>` | ✅ Same serializer |
| Offer validity | `start_date`, `end_date`, `is_active` | Uses `is_valid` computed field | GET `/api/offers/` filters active+date | ✅ |
| Announcements | POST `/api/announcements/` | `AnnouncementItem` | GET `/api/announcements/?shop=<id>` | ✅ Same serializer |
| Announcement publish | `status=PUBLISHED` | Only PUBLISHED appear | GET `/api/announcements/` filters | ✅ |

---

## F. DATA PRIVACY / LEAKAGE CHECK

| Private field | Backend | Public API exposes? |
|---|---|---|
| `cost_price` | ProductOwnerSerializer only | ❌ NOT in ProductPublicSerializer ✅ |
| `status=DRAFT` products | Filtered from public list | ❌ Not exposed ✅ |
| Invoice data / purchase totals | `IsShopMember` permission | ❌ Not accessible without auth ✅ |
| Worker records | `IsShopOwner` permission | ❌ Not accessible without auth ✅ |
| Owner analytics (dashboard) | `IsShopOwner` permission | ❌ Not accessible without auth ✅ |
| `stock_quantity` | Exposed in public product list | ⚠️ Exact stock visible to customers |
| Supplier / margin data | Not a backend field at all | N/A |

> ⚠️ `stock_quantity` is exposed to customers via the public product list. This is a minor privacy consideration but not a correctness bug.

---

## G. SUMMARY OF GAPS

### G1. Owner App — API URL Mismatches (all require Owner app fixes only)

| # | Screen | Current call | Correct call |
|---|--------|-------------|-------------|
| 1 | Registration | `POST api/auth/register/` | `POST api/auth/register/owner/` |
| 2 | ProfileScreen | `GET api/auth/me/` | **Remove** — backend has no `/me/` endpoint |
| 3 | AddProductScreen | `POST api/products/register/` | `POST api/products/` |
| 4 | EditProduct | `PUT api/products/{id}/` | `PATCH api/products/{id}/` |
| 5 | CheckoutScreen | `POST api/checkout/accept/` (per item) | `POST api/billing/invoices/` (all items at once + idempotency_key) |
| 6 | InvoiceListScreen | `GET api/checkout/invoices/` | `GET api/billing/invoices/` |
| 7 | InvoiceDetailScreen | `GET api/checkout/invoices/{id}/` | `GET api/billing/invoices/{id}/` |
| 8 | CameraScanScreen | `POST api/products/match/` | **No equivalent** — log in BACKEND_GAPS.md |
| 9 | CameraScanScreen | `POST api/vision/capture/` | **No equivalent** — log in BACKEND_GAPS.md |

### G2. Owner App — Field Name Mismatches (all require Owner app model fixes)

| # | Model/Screen | Wrong field | Correct field |
|---|---|---|---|
| 1 | `ProductDto.sellingType` | value "KG"/"UNIT" | → `unit` with values "KG"/"PIECE"/… |
| 2 | `ProductDto.pricePerUnit` | — | → `selling_price` |
| 3 | `ProductDto.quantity` | — | → `stock_quantity` |
| 4 | `ProductDto.formattedQuantity` | — | Not in backend; remove |
| 5 | `ProductDto.featureVector` | — | Not in shared backend; remove |
| 6 | `ProductDto.isLoose` | — | Not in shared backend; remove |
| 7 | `ProductCreateRequest` | all fields | see A3 write fields |
| 8 | `AuthResponse.user.shopName` | — | Not in login response; fetch via `GET /api/shops/my_shop/` |
| 9 | `InvoiceItemDto.totalPrice` | — | → `line_total` |
| 10 | `CheckoutAcceptRequest` entire shape | — | → `InvoiceCreateRequest` shape |

### G3. Missing Backend Endpoints (need backend changes — log to BACKEND_GAPS.md)

| # | What | Used by | Fix needed |
|---|---|---|---|
| 1 | `GET /api/auth/me/` | ProfileScreen | Owner team must call `/api/shops/my_shop/` instead or accept null profile |
| 2 | `POST /api/products/match/` | CameraScanScreen | Vision/AI feature — not in shared backend |
| 3 | `POST /api/vision/capture/`, `embed/` | CameraScanScreen | ESP32-CAM — not in shared backend |
| 4 | `shop_name` / `phone_number` in login response | LoginScreen | Not in `AuthResponse.user` — fetch separately |

### G4. Customer App — Missing Backend Fields (no code changes allowed)

| # | Customer uses | Backend status | Impact |
|---|---|---|---|
| 1 | `distance` | Not returned | Shows blank — acceptable |
| 2 | `emoji` | Not returned | Falls back to 🛒 — acceptable |
| 3 | `lat`, `lng` | Not returned | Map shows Bangalore pin for all shops |
| 4 | `is_available` | Not returned | Falls back to `stock_quantity > 0` — correct behavior |
| 5 | `selfCheckout`, `offer`, `followers` | Not returned | Non-critical display fields |

---

## H. NEXT STEPS (Part 2)

**Awaiting approval to begin Part 2.** Planned fix order:

1. Rewrite `ApiModels.kt` — align `ProductDto`, `ProductCreateRequest`, `InvoiceDto`, `AuthResponse` to shared backend fields
2. Rewrite `ShopGenieApiService.kt` — fix all URLs and HTTP methods
3. `LoginScreen.kt` — remove `shopName` from SharedPrefs after login; fetch from `/api/shops/my_shop/`
4. `AddProductScreen.kt` — fix request body fields, add `shop` field from cached shop ID
5. `InventoryScreen.kt` — fix field references (`stock_quantity`, `selling_price`)
6. `CheckoutScreen.kt` — replace sequential `checkoutAccept` loop with single idempotency-keyed `POST /api/billing/invoices/`
7. `ProfileScreen.kt` — remove ghost `/api/auth/me/` call; display from SharedPrefs or `/api/shops/my_shop/`
8. `CameraScanScreen.kt` — show "Recognition service not connected" if match endpoint unavailable
9. All screens — fix error display; no silent catches

All changes: **Owner app only**, no backend or Customer app edits.
