# Shopkeeper Login and Worker Dashboard

## Plan and files

1. Keep the existing owner login, registration, dashboard, and theme; route the signed-out entry screen through role selection.
2. Add a worker model and owner-only worker-management API, then revalidate worker tokens and permissions on every authenticated request.
3. Replace the sample worker roster with API-backed worker management; add shopkeeper login, a permission-limited dashboard and stock editor, and secure token storage.
4. Cover code creation, login, tenant scoping, revocation, lockout, and owner-only authorization with backend tests; document setup.

The active backend is maintained separately at `R:\shopgenie backend\shopgenie_unified`; the old repository-local Django backend is archived at `_removed_backup\shopgenie_backend_legacy` and is not used by the apps.

Changed files:

- Flutter: `app/applet/pubspec.yaml`, `app/applet/pubspec.lock`, `app/applet/lib/main.dart`, `app/applet/lib/models/user.dart`, `app/applet/lib/services/api_service.dart`, `app/applet/lib/services/auth_service.dart`, `app/applet/lib/services/product_service.dart`, `app/applet/lib/screens/splash_screen.dart`, `app/applet/lib/screens/dashboard_screen.dart`, `app/applet/lib/screens/profile_screen.dart`, and `app/applet/lib/screens/worker_management_screen.dart`.
- Django: the shared backend at `R:\shopgenie backend\shopgenie_unified` contains the current auth, worker, product, inventory, and billing implementation.

New files:

- Flutter: `app/applet/lib/models/worker.dart`, `app/applet/lib/services/worker_service.dart`, `app/applet/lib/screens/role_selection_screen.dart`, `app/applet/lib/screens/worker_login_screen.dart`, `app/applet/lib/screens/worker_dashboard_screen.dart`, `app/applet/lib/screens/worker_inventory_screen.dart`, and `app/applet/test/worker_flow_widget_test.dart`.
- Django: current backend worker implementation and migrations are in `R:\shopgenie backend\shopgenie_unified\accounts`, `workers`, and `shopgenie` modules.

The existing owner login widget and owner dashboard design are unchanged. Owner registration now sends the password confirmation field that the existing Django registration serializer requires.

## How it works

- The first signed-out screen offers **Shop Owner** and **Shopkeeper**. Owner selection opens the existing owner login/registration flow; shopkeeper selection opens a name-and-access-code login with no registration option.
- Owners manage real worker records in **Workers**: create with an optional phone and permissions, inspect active status and last login, edit, activate/deactivate, delete, or replace a code. A generated code is returned only by create/regenerate and shown once in the app with Copy and Share actions. The database stores a Django password hash, never the plain code.
- Codes contain 14 random letters/digits. Worker names are unique case-insensitively within one owner’s shop. The login resolves a worker by both supplied name and code, so equal names in separate shops do not collide.
- Worker tokens carry the worker ID, owner/shop ID, role, and code version. The custom JWT authenticator checks active status, owner, and current code version on every authenticated request. Deactivation, deletion, or code replacement invalidates the next worker request. The worker app also checks its session on resume and periodically while open.
- The shared backend has a `Shop` model linked one-to-one to its owner. Products and invoices belong to that shop, and workers are linked through `assigned_shop`. Worker endpoints scope worker records to the authenticated owner's shop; products and billing use the shared backend's shop-scoped APIs.
- Worker permissions are `view_products`, `manage_inventory`, `create_bills`, and `view_invoices`. Newly created workers receive only the permissions explicitly requested by the owner (omitted permissions default to false). The shared backend requires worker role and permission checks for restricted operations; worker tokens are checked against active state and code version on each request.
- Access and refresh tokens are stored with `flutter_secure_storage`; existing tokens in `SharedPreferences` are migrated on startup. The saved role selects the correct dashboard after restart. A revoked-token 401 clears the session and returns to role selection.
- Worker login allows 10 requests/minute per client IP and temporarily locks a worker for five minutes after five incorrect code attempts.

## API endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| `POST` | `/api/auth/worker-login/` | Sign in with `name` and `code`; returns role, shop ID, permissions, and JWTs |
| `GET`, `POST` | `/api/workers/` | Owner lists workers or creates one; creation returns the code once |
| `GET`, `PATCH`, `DELETE` | `/api/workers/{id}/` | Owner reads, edits/activates/deactivates, or deletes a worker |
| `POST` | `/api/workers/{id}/regenerate-code/` | Replace the code and invalidate all existing sessions |
| `GET` | `/api/auth/me/` | Returns the current owner or worker profile |

Worker product and checkout access uses the existing `/api/products/` and `/api/checkout/` endpoints, with worker-role permission checks and the owner’s shop scope.

## Setup and verification

1. In `R:\shopgenie backend\shopgenie_unified`, keep `.env` private and configure the local PostgreSQL connection values. Do not commit `.env`.
2. Apply the worker migration and start Django:

   ```powershell
   cd "R:\shopgenie backend\shopgenie_unified"
   py manage.py migrate
   py manage.py runserver 0.0.0.0:8000
   ```

   For a local smoke run without PostgreSQL, set `SHOPGENIE_SQLITE_PATH` to a writable SQLite file before running `migrate` and `runserver`. Do not use the test-only in-memory database for the server because it does not persist across processes.

3. In `app/applet`, fetch packages and run the Android app. For a USB-connected Android phone, forward the backend port and use the forwarded loopback URL:

   ```powershell
   adb reverse tcp:8000 tcp:8000
   cd app/applet
   flutter pub get
   flutter run -d <device-id> --dart-define=BASE_URL=http://127.0.0.1:8000
   ```

   If the app already has a saved API URL, set it to `http://127.0.0.1:8000` in the owner login server settings.

4. Register or sign in as an owner, open **Workers**, create a shopkeeper, and copy/share the one-time code. Log out, select **Shopkeeper**, and sign in with that name and code. To verify revocation, deactivate or replace the worker from the owner session; the worker session is rejected on its next request and is signed out.
5. Run backend checks from `R:\shopgenie backend\shopgenie_unified`. Use the test scripts available in that backend; its worker API and auth tests are tied to the unified backend models.
6. Run Flutter validation from `app/applet` with `flutter analyze` and `flutter test`. The role-selection widget test verifies that Shop Owner still opens the existing owner login and Shopkeeper opens the code-only login.

## Assumptions and limitations

- The shared backend `R:\shopgenie backend\shopgenie_unified` is the source of truth for both apps; the older embedded backend is retained only as an archive.
- This backend has no separate Shop model, so the owner user ID is the stable shop ID and the existing user-owned product/invoice records are the shop’s data.
- Worker sessions are checked on each server request and every 30 seconds in the open worker dashboard (also on app resume). An idle device cannot learn about a remote deactivation until its next check.
