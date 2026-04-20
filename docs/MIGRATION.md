# Migration: Expo Go → Development Build

## Why

Expo Go is a pre-built app that cannot run custom native modules. Libraries like `@maplibre/maplibre-react-native` require native code compiled directly into the app binary. Development builds solve this by creating a custom version of the Expo runtime that includes all native dependencies.

## What Changed

| File | Change |
|------|--------|
| `package.json` | Added `expo-dev-client` dependency and `build:dev:android` / `build:dev:ios` scripts |
| `app.json` | Added `"expo-dev-client"` to the `plugins` array |
| `eas.json` | New file — EAS Build profiles for `development`, `development-simulator`, `preview`, and `production` |

## How to Run

### First-Time Setup

1. **Install dependencies** (if not already done):
   ```bash
   npm install
   ```

2. **Build a dev client** on your target platform:

   **Local build (no EAS account needed):**
   ```bash
   npx expo run:android
   # or
   npx expo run:ios
   ```

   **Cloud build via EAS:**
   ```bash
   npm install -g eas-cli   # one-time
   eas login                 # one-time
   eas init                  # one-time — links project to EAS
   npm run build:dev:android
   # or
   npm run build:dev:ios
   ```

   The first build generates `/android` and `/ios` directories locally (these are gitignored).

### Daily Development

```bash
npx expo start
```

Metro automatically detects the dev client and runs in development build mode. You no longer need the Expo Go app — install the built dev client on your device/emulator instead.

### Key Differences from Expo Go

| Expo Go | Development Build |
|---------|-------------------|
| Pre-built, downloaded from app store | Custom-built per project |
| Cannot use custom native modules | Supports all native modules |
| Instant start, no build step | Requires initial build (`expo run:*` or EAS) |
| Uses Expo Go app on device | Uses project-specific dev client app |
| `npx expo start` opens in Expo Go | `npx expo start` opens in dev client |

### Notes

- **New Architecture** is enabled (`"newArchEnabled": true` in `app.json`) — this is required for MapLibre v11 compatibility.
- **Fast refresh** works identically in dev builds.
- All existing functionality (game loop, gestures, sound, haptics, save/load) works the same in the dev build.
- You only need to rebuild when adding/removing native dependencies. JS-only changes use hot reload as before.
