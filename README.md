\# ShopGenie AI



ShopGenie AI is a smart inventory and billing application designed to help shopkeepers manage products, track stock, record customer bills, and monitor sales.







\- \*\*Frontend:\*\* Flutter and Dart

\- \*\*Backend:\*\* Django REST Framework

\- \*\*Database:\*\* PostgreSQL

\- \*\*Computer Vision:\*\* OpenCV and PyTorch with MobileNetV3

\- \*\*Camera:\*\* Android mobile phone's built-in camera



\## Features



\- User registration and login

\- Product and inventory management

\- Manual product selection

\- Mobile camera-based product scanning

\- Computer vision-assisted product recognition

\- Smart billing and invoice management

\- Automatic stock updates during checkout

\- Sales analytics and reporting



\*\*Billing scope:\*\* ShopGenie AI records customer bills and tracks sales. UPI payment processing is not included in the current scope.



\## Project Architecture



The Flutter mobile application communicates with the Django REST Framework backend. The backend manages authentication, products, inventory, billing, analytics, and supported computer vision operations.



The PostgreSQL database stores application data. The computer vision components are maintained in the `cv\_engine/` directory.



The Android phone's built-in camera is intended to capture product images. The captured images can be sent to the backend or passed to the computer vision workflow, depending on the implemented integration.



\## Project Structure



```text

ShopGenie-AI/

├── app/

│   └── applet/             # Flutter mobile application

│       ├── lib/

│       │   ├── models/

│       │   ├── screens/

│       │   ├── services/

│       │   └── widgets/

│       ├── test/

│       ├── android/

│       └── pubspec.yaml

├── shopgenie/

│   └── backend/            # Django REST Framework backend

├── cv\_engine/              # Computer vision components

├── .env.example            # Example environment configuration

├── .gitignore

└── README.md

```



\## Prerequisites



Install the following tools:



\- Flutter SDK and Dart

\- Android Studio and Android SDK

\- Python compatible with the backend dependencies

\- PostgreSQL

\- Git



An Android emulator or physical Android phone can be used to run the Flutter application. For physical-device testing, grant camera permission when prompted.



\## Running the Flutter Application



1\. Open Android Studio.

2\. Open the Flutter project directory: `app/applet`.

3\. Wait for the project and Flutter dependencies to finish syncing.

4\. Ensure the Flutter SDK path is configured.

5\. Select an Android emulator or connected Android phone.

6\. Run the application.



Alternatively, use PowerShell from the repository root:



```powershell

cd app/applet

flutter pub get

flutter analyze

flutter test

flutter run

```



\## Running the Django Backend

The shared Django backend lives outside this Flutter project at
`R:\shopgenie backend\shopgenie_unified`. The older embedded backend has been
archived under `_removed_backup\shopgenie_backend_legacy` and is not used by
either app.

1. Navigate to the shared backend directory:

2\. Activate the existing Python virtual environment.

3\. Configure the required environment variables in the local `.env` file.

4\. Ensure PostgreSQL is running and the database configuration is correct.

5\. Apply migrations if required.

6\. Start the Django development server.



Example PowerShell commands:



```powershell

cd "R:\shopgenie backend\shopgenie_unified"
.\\.venv\\Scripts\\Activate.ps1
python manage.py check
python manage.py migrate
python manage.py runserver 0.0.0.0:8000

```



Use the environment variables required by the existing backend configuration. Keep the actual `.env` file private and out of version control.


## Dev test accounts

The backend includes a development-only seed command that creates an active owner account, shop inventory, completed sample bills, and a shopkeeper worker using the real Django models and password/code hashing. It does not create simulated tokens or bypass the normal login endpoints.

1. In `R:\shopgenie backend\shopgenie_unified`, create `.env` from `.env.example` only if you do not already have a private `.env`; configure the database and development-only `DEV_OWNER_LOGIN`, `DEV_OWNER_PASSWORD`, `DEV_WORKER_NAME`, and `DEV_WORKER_CODE` values. Never use the development defaults in production.
2. From the backend directory, run:

   ```powershell
   cd "R:\shopgenie backend\shopgenie_unified"
   python manage.py migrate
   python manage.py seed_dev
   ```

3. Sign in through the normal owner login using the printed owner username/password. Select Shopkeeper and use the printed worker name/code for worker login.
4. To reset the seed data, run `python manage.py seed_dev --reset`. This refreshes the seeded worker, sample invoices, and marked sample products (a sample product linked to another invoice is preserved); the marked owner and shop are updated in place. Unrelated users, shops, products, invoices, and workers are preserved. Add `--owner-only` to omit the worker account.

The seed command refuses to run unless `DEBUG=True`, and it also refuses when `ENVIRONMENT=production`. It uses this backend's real `CustomUser`, `Shop`, `Product`, `Invoice`, and worker fields. Customer profile rows are not seeded because the backend has no customer profile model.

To open the seeded dashboard in Flutter debug mode, first start Django with `python manage.py runserver 0.0.0.0:8000`. Then run from `app/applet`:

```powershell
# Android emulator:
flutter run --dart-define=BASE_URL=http://10.0.2.2:8000

# USB-connected Android phone (recommended; keeps working across Wi-Fi changes):
.\app\applet\run_usb_debug.ps1 -DeviceId <device-id>

# Physical Android device on the same Wi-Fi; replace with the computer's current LAN IP:
flutter run -d <device-id> --dart-define=BASE_URL=http://<PC-LAN-IP>:8000
```

The USB runner sets up `adb reverse`, checks that Django answers `/api/shops/`, and launches Flutter with the forwarded URL. When `BASE_URL` is passed as a Dart define, it takes precedence over any older URL saved by the app. In the owner app's **Backend API URL** dialog, use **USB debugging (127.0.0.1:8000)** only after running `adb reverse tcp:8000 tcp:8000`. Use `10.0.2.2` only on an Android emulator.

### Debug auto-login (owner and shopkeeper)

To skip the login screens during local debug sessions, pass credentials as build defines. The app still calls the real backend login endpoint and stores the returned token normally. Choose one role per run, or use `DEV_ROLE=both` to show debug-only Owner/Shopkeeper dashboard launch buttons. In `both` mode, pass separate credentials for both accounts.

```powershell
# Owner, on a physical Android device (replace the LAN address as needed):
flutter run --dart-define=BASE_URL=http://192.168.1.20:8000 --dart-define=DEV_AUTO_LOGIN=true --dart-define=DEV_ROLE=owner --dart-define=DEV_OWNER_USER=your-owner-username --dart-define=DEV_OWNER_PASS=your-owner-password

# Shopkeeper, on a physical Android device:
flutter run --dart-define=BASE_URL=http://192.168.1.20:8000 --dart-define=DEV_AUTO_LOGIN=true --dart-define=DEV_ROLE=worker --dart-define=DEV_WORKER_NAME=your-worker-name --dart-define=DEV_WORKER_CODE=your-worker-access-code

# Either dashboard, selected from the debug launcher:
flutter run --dart-define=BASE_URL=http://192.168.1.20:8000 --dart-define=DEV_AUTO_LOGIN=true --dart-define=DEV_ROLE=both --dart-define=DEV_OWNER_USER=your-owner-username --dart-define=DEV_OWNER_PASS=your-owner-password --dart-define=DEV_WORKER_NAME=your-worker-name --dart-define=DEV_WORKER_CODE=your-worker-access-code
```

For an Android emulator, use `http://10.0.2.2:8000` as `BASE_URL`. Auto-login is disabled unless `DEV_AUTO_LOGIN=true` is explicitly supplied and only runs in Flutter debug mode; release builds continue to use the normal login flow. Do not put real account credentials into source files or commit command histories containing them.

These are development credentials and sample records only. Never use them in production or publish a database containing seeded credentials.


\## Mobile Camera Integration



ShopGenie AI is intended to use the Android phone's built-in camera rather than an external camera module.



The camera workflow should:



1\. Request camera permission.

2\. Capture an image of a product.

3\. Handle permission denial and camera errors.

4\. Pass the image to the configured recognition workflow.

5\. Use the recognition result in the product or inventory workflow.



The actual implementation depends on the Flutter camera integration and the existing backend and computer vision APIs. These steps describe the intended workflow; they do not guarantee that every step is already implemented.



\## Computer Vision



The `cv\_engine/` directory contains the computer vision components for product image processing and recognition. The planned technology stack includes OpenCV, PyTorch, and MobileNetV3.



The image-processing and recognition workflow should be verified against the current implementation before deployment.



\## Security



\- Never commit `.env` files containing real credentials.

\- Keep database passwords, API keys, and other secrets private.

\- Use authentication for protected backend endpoints.

\- Use HTTPS for production deployments.

\- Keep development settings separate from production settings.



\## Project Status



ShopGenie AI is under active development. The Flutter application, Django backend, PostgreSQL database, mobile camera integration, and computer vision workflow should be tested together as development progresses.
