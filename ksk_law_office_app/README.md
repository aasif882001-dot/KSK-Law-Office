# KSK Law Office – Advocate Task Manager

Flutter Android starter prototype with a white + blue theme, Admin/Advocate role selection, task assignment, status updates, advocate list, and basic reports.

## Current prototype behaviour

- Runs with in-memory sample data; changes reset when the app is restarted.
- Demo Admin: `admin@ksklaw.in` / `demo123`
- Demo Advocates: `advocate01@ksklaw.in`, `advocate02@ksklaw.in`, `advocate03@ksklaw.in` / `demo123`
- Admin can add advocates (up to 10), assign tasks and delete tasks.
- Advocates can view their own tasks and update task status.

**Important:** This is a UI/functional prototype, not a production-ready legal-office system. Demo credentials are hard-coded and must not be used for real client or case data. Authentication, cloud database, push notifications, daily scheduled summaries, audit logs and production security rules still need to be integrated and tested.

## Run on a computer with Flutter installed

1. Install Flutter SDK and Android Studio, including Android SDK tools.
2. From this folder run:

   ```bash
   flutter pub get
   flutter run
   ```

3. To create an APK after testing:

   ```bash
   flutter build apk --release
   ```

## Firebase integration plan

1. Create a Firebase project for KSK Law Office.
2. Register the Android app using the final Android application ID.
3. Run `flutterfire configure` in this project and add `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`, and `flutter_local_notifications` dependencies.
4. Replace demo login with Firebase Authentication and role claims / a protected user-role document.
5. Store advocates and tasks in Cloud Firestore. Enforce role-based access with Firestore Security Rules; never rely on hiding screens in the UI as security.
6. Configure Firebase Cloud Messaging for task assignment and status events. Use a trusted server (Cloud Functions or another backend) for scheduled daily summaries; do not place privileged credentials in the app.
7. Add audit history, backup/retention policy, privacy notice, and access controls before entering confidential case/client information.

A starter Firestore rules outline is provided in `firebase/firestore.rules.template`. It is intentionally restrictive and requires the role documents and schema to be finalized before deployment.
