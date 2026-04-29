# Club Connect Flutter Progress

Last updated: 2026-04-19

## Current status
- Flutter app exists at `club_connect_flutter/`
- App uses live backend API, not mock data
- Auth/session is live: login, signup, OTP, logout, session restore
- Live data wired for clubs, posts, notifications, likes, RSVP, club members
- Officer/admin dashboard has live actions for:
  - create event/announcement
  - create/update/delete tasks
  - create notifications
  - create clubs
  - assign teachers
  - assign officers

## Important files
- `lib/src/state/app_state.dart`
- `lib/src/services/api_client.dart`
- `lib/src/screens/dashboard_screen.dart`
- `lib/src/screens/profile_screen.dart`
- `lib/src/screens/root_screen.dart`

## How to run
- Start backend:
  - `cd /Users/amishprabhu/Documents/GitHub/Club-Connect/server`
  - `npm run dev`
- Run Flutter on Android emulator:
  - `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5001/api`
- Run Flutter on iOS simulator:
  - `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5001/api`

## Remaining high-value work
- Profile/account actions:
  - update profile
  - change password
  - request delete OTP / delete account
  - forgot password flow
- Cloudinary/media upload integration
- Google sign-in/sign-up integration
- richer admin screens: edit/delete clubs, officer removal, teacher managed-club assignment
- budget/report/certificate flows
- bulk import flows
- teacher report/managed club screens

## Resume prompt
Use this if the session ends:

`Continue the Club Connect Flutter app in /Users/amishprabhu/Desktop/LAB ASSIGNMENTS/Web Design/Lab9/club_connect_flutter. Read PROGRESS.md first, then continue from the current architecture and keep the app backend-connected.`
