# Firebase Setup Guide — Smart Farm

## 1. Create a Firebase Project

1. Go to https://console.firebase.google.com
2. Click **Add project** → name it (e.g. `smart-farm`)
3. Disable Google Analytics if not needed → **Create project**

---

## 2. Enable Realtime Database

1. In the left sidebar: **Build → Realtime Database**
2. Click **Create database**
3. Choose a region (e.g. US)
4. Start in **Test mode** (you can add security rules later)
5. Note the database URL — it looks like:
   ```
   https://your-project-default-rtdb.firebaseio.com
   ```

## 3. Set Initial Database Values

In the Realtime Database console, click the **+** icon on the root node and add:

```json
{
  "farm": {
    "mode": "manual",
    "pump": false,
    "threshold": 1800,
    "soilMoisture": 0,
    "pumpStatus": false
  }
}
```

Or import it via the three-dot menu → **Import JSON**.

---

## 4. Add Android App

1. In Firebase console: **Project Overview → Add app → Android**
2. Android package name: `com.smartfarm.smart_farm`
3. Register the app
4. **Download `google-services.json`**
5. Place it in: `android/app/google-services.json`

---

## 5. Add iOS App (optional)

1. **Project Overview → Add app → iOS**
2. iOS bundle ID: `com.smartfarm.smartFarm`
3. Register the app
4. **Download `GoogleService-Info.plist`**
5. Open `ios/Runner.xcworkspace` in Xcode
6. Drag `GoogleService-Info.plist` into the Runner target (copy items checked)

---

## 6. Fill in firebase_options.dart

Open `lib/firebase_options.dart` and replace each `YOUR_*` placeholder.

### Finding the values

**Android** — open `android/app/google-services.json`:
```json
{
  "project_info": {
    "project_id": "your-project-id",           → projectId
    "firebase_url": "https://...",              → databaseURL
    "storage_bucket": "your-project.appspot.com" → storageBucket
  },
  "client": [{
    "client_info": {
      "mobilesdk_app_id": "1:...:android:..."  → appId
    },
    "api_key": [{ "current_key": "AIza..." }]  → apiKey
  }]
}
```

`messagingSenderId` is the number between `1:` and `:android` in the `mobilesdk_app_id`.

**iOS** — open `ios/Runner/GoogleService-Info.plist` and find:
- `API_KEY` → apiKey
- `GOOGLE_APP_ID` → appId
- `GCM_SENDER_ID` → messagingSenderId
- `PROJECT_ID` → projectId
- `DATABASE_URL` → databaseURL
- `STORAGE_BUCKET` → storageBucket

---

## 7. Security Rules (production)

Replace the test-mode rules with proper rules once development is done:

```json
{
  "rules": {
    "farm": {
      ".read": true,
      ".write": true
    }
  }
}
```

For a real deployment, add authentication and restrict reads/writes accordingly.

---

## 8. Run the App

```bash
flutter run
```

The app will connect to Firebase and begin listening for real-time updates from the ESP32.
