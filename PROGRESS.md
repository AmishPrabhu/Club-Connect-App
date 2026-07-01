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
  - Copy `server/.env.example` to `server/.env` and fill in your connection credentials and API keys.
  - Run `cd server && npm install` (to install dependencies)
  - Run `npm run dev` (to start the local development server)
- Run Flutter:
  - Simply run `flutter run`. The app will automatically connect to your local server on port 5001 (`http://10.0.2.2:5001/api` for Android Emulator, and `http://localhost:5001/api` for iOS/Web) in debug mode.
  - To override the API URL manually:
    `flutter run --dart-define=API_BASE_URL=https://your-custom-api-url/api`

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
