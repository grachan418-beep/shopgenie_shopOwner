# BACKEND_GAPS.md — ShopGenie Owner App Integration
> Last updated: 2026-10-26  
> Status: **Awaiting owner approval before any backend changes**  

All items below describe things missing or mismatched in the shared Django backend
(`R:\shopgenie backend\shopgenie_unified\`) that the Owner app (or Customer app) expects.
**No backend changes have been made.** Each row describes the smallest safe fix.

---

## GAP-001 — No `/api/auth/me/` endpoint

| Field | Detail |
|-------|--------|
| **App / Screen** | Owner — `ProfileScreen.kt` |
| **Endpoint called** | `GET /api/auth/me/` |
| **Expected response** | `{id, username, email, shopName, phoneNumber}` |
| **Actual backend** | Endpoint does not exist. Login returns `{user: {id, username, email, role}}` |
| **Impact** | Profile screen silently ignores error; shows stale SharedPrefs data |
| **Smallest safe fix** | *(Option A — no backend change)* Owner app reads user info from login response + calls `GET /api/shops/my_shop/` for shop name. Remove `getCurrentUser()` call entirely. **Preferred — no backend change.** |
| **Status** | 🔴 BLOCKED — Owner app fix required, no backend change needed |

---

## GAP-002 — Vision / AI product recognition endpoints missing

| Field | Detail |
|-------|--------|
| **App / Screen** | Owner — `CameraScanScreen.kt` |
| **Endpoints called** | `POST /api/products/match/`, `POST /api/vision/capture/`, `POST /api/vision/embed/` |
| **Expected response** | Product match candidates with similarity scores |
| **Actual backend** | These endpoints existed only in the archived legacy backend at `R:\shopgenie-main\_removed_backup\shopgenie_backend_legacy\vision\` — not in the shared backend |
| **Impact** | Camera/AI scan feature is completely non-functional against shared backend |
| **Smallest safe fix** | Owner app shows "Recognition service not connected" message when these endpoints return 404. No fake/random matches. Camera preview still works. |
| **Status** | 🔴 BLOCKED — Vision feature needs either (a) shared backend gets vision module added, or (b) owner app shows graceful "unavailable" state |

---

## GAP-003 — `shop_name` not in login response

| Field | Detail |
|-------|--------|
| **App / Screen** | Owner — `LoginScreen.kt`, `HomeScreen.kt`, `CheckoutScreen.kt` |
| **Expected** | Login response `user.shopName` |
| **Actual** | Login returns `user.role` — no `shopName`, no `phoneNumber` |
| **Impact** | App falls back to hardcoded "My Kirana Store" everywhere |
| **Smallest safe fix** | *(No backend change needed)* After login, call `GET /api/shops/my_shop/` and cache `shop.name` in SharedPreferences. |
| **Status** | 🟡 PENDING — Owner app fix only |

---

## GAP-004 — Customer app: `distance`, `lat/lng`, `emoji`, `selfCheckout`, `followers` missing from shop list

| Field | Detail |
|-------|--------|
| **App / Screen** | Customer — `home_screen.dart`, `map_screen.dart`, `shop_detail_screen.dart` |
| **Expected** | `distance`, `lat`, `lng`, `emoji`, `selfCheckout`, `followers`, `isFollowing` in `GET /api/shops/` |
| **Actual** | Backend `ShopPublicSerializer` does not include these fields |
| **Impact** | Map shows all shops at hardcoded Bangalore coords. Distance shows blank. Followers show 384 (hardcoded). |
| **Smallest safe fix** | Add `lat`, `lng` fields to `Shop` model + `ShopPublicSerializer`. `distance` would require geo query. `emoji`, `selfCheckout`, `followers` are UI-only — acceptable to leave as defaults. |
| **Status** | 🟡 PENDING owner approval — requires backend model + serializer change |

---

## GAP-005 — Customer app: `is_available` not in product public response

| Field | Detail |
|-------|--------|
| **App / Screen** | Customer — `ProductItem.fromJson()` |
| **Expected** | `is_available: bool` in product response |
| **Actual** | Backend does not return `is_available`; customer falls back to `stock_quantity > 0` |
| **Impact** | Very minor — `stock_quantity > 0` is equivalent to "in stock" for the customer view |
| **Smallest safe fix** | None required — fallback logic is correct |
| **Status** | ✅ ACCEPTABLE — no change needed |

---

## Summary Table

| Gap ID | Screen/App | Missing | Needs Backend? | Priority |
|--------|-----------|---------|---------------|---------|
| GAP-001 | Owner ProfileScreen | `/api/auth/me/` | No — owner app fix only | High |
| GAP-002 | Owner CameraScanScreen | Vision/match endpoints | Yes (or graceful degradation) | High |
| GAP-003 | Owner LoginScreen/Home | `shop_name` in login response | No — fetch via `my_shop` | High |
| GAP-004 | Customer home/map | `lat`, `lng` in shop list | Yes — model + serializer | Medium |
| GAP-005 | Customer product list | `is_available` field | No — fallback is correct | Low |
