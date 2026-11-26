# PG Connect Flutter starter

## Local development

Run the backend with the `dev` profile and PostgreSQL first. For the backend
currently listening on port 8081, start an Android emulator and run:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081/api/v1 --dart-define=DEVELOPMENT_OTP=true
```

The iOS runner targets iOS 15 or later. Building and running it requires Xcode,
an iOS simulator or device, and CocoaPods or Flutter's Swift Package Manager
support. Select your own bundle identifier and signing team in Xcode before
running on a physical device. The generated `com.example.pgConnect` bundle ID
is a placeholder.

For an iOS simulator set `API_BASE_URL=http://localhost:8081/api/v1`. The backend
currently binds to localhost; a physical device needs a backend address it can
reach and an appropriately secured development network. Android debug builds
allow HTTP for local development; iOS allows local networking for simulator
development. Use HTTPS for deployed systems. The iOS runner and Stripe
checkout have not yet been built or tested on an iOS device or simulator.

Enter a phone number including the country code. The backend returns a
development OTP displayed in the app; no SMS is sent. The code expires after
five minutes. This login is available only in Flutter debug builds with the
explicit `DEVELOPMENT_OTP` flag and must never be enabled on an exposed server.
The session is stored in secure storage and `/me` determines owner access.

## Connected screens

The app loads properties and available beds, submits booking requests, lists and
cancels pending customer bookings, and shows invoices. Approved owners can see
their dashboard, property list and bookings, and approve or reject requests.
Owners can add and edit properties, rooms and beds, and create invoices for
approved bookings. From a property, use **Manage photos** to upload JPEG or
PNG images (up to 10 photos, 5 MiB and 16 megapixels each), choose the cover,
change their order or delete them. Photos on active properties are public;
remove sensitive image metadata such as location before uploading. The invoice
list is available from the bookings screen.
Owners can select standard amenities using **Manage amenities**. Residents can
search by property, city or area, filter by maximum rent, available beds and
amenities, load more results, and save properties from their detail pages.
Use **Search** to apply changed filters; saved properties are account-specific.
The account screen allows owner applications and role switching for approved
owners. An administrator must approve owner applications via the backend; see
the backend README.

## Still to build

- Production SMS authentication, token refresh and production error handling.
- Invoice editing, cancellation and automated recurring billing.
- End-to-end Stripe sandbox testing, refunds, disputes and production readiness.
  Do not enable live payments.
- Production photo storage, notifications, receipts, subscriptions
  and broader tests.

Never put Stripe secret keys in the app. A client callback is not proof of
payment; the backend must verify and record payment state.

## Stripe test checkout

Enable Stripe test checkout and configure webhook forwarding on the backend as
described in its README.
Restart the backend after configuring the sandbox key and webhook secret. Then
rebuild and run the app with your sandbox **publishable** key:

```bash
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=http://10.0.2.2:8081/api/v1 \
  --dart-define=DEVELOPMENT_OTP=true \
  --dart-define=STRIPE_TEST_CHECKOUT=true \
  --dart-define=STRIPE_PUBLISHABLE_KEY=<your-test-publishable-key>
```

Replace the placeholder with your own `pk_test_` key. Do not supply a Stripe
secret key to Flutter. Open an unpaid invoice to start test checkout. Payments
go to the platform account; there are no owner payouts. The app displays
pending until the server confirms the payment and can resume or cancel an open
payment. Never use live cards in this test flow.

Native plugin changes require a full rebuild; hot reload is insufficient.
For an iOS simulator, select its device ID and replace the Android API URL with
`http://localhost:8081/api/v1`. The iOS URL scheme is configured for Stripe
redirects, but iOS checkout still needs end-to-end testing.
