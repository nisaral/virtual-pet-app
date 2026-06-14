# How to Build & Share the APK (for your girlfriend's phone)

This project is currently **just the Dart code** (lib/ + pubspec). It is missing the native Android folder (`android/`) that is required to produce an APK file.

Follow these steps exactly on your Windows PC.

---

## Step 1: Install Flutter (one-time)

1. Go to: https://docs.flutter.dev/get-started/install/windows
2. Download the latest Flutter SDK zip.
3. Extract it to `C:\src\flutter` (create the folders if they don't exist).
4. Add `C:\src\flutter\bin` to your **User PATH**:
   - Search Windows for "Environment Variables"
   - Edit the "Path" variable for your user account
   - Add a new entry: `C:\src\flutter\bin`
5. **Close and reopen PowerShell completely**.
6. Test:
   ```powershell
   flutter --version
   flutter doctor
   ```

`flutter doctor` will probably show some red items (Android toolchain). That's normal on first install.

---

## Step 2: Complete the Project (add Android support)

In PowerShell, go to the project and run:

```powershell
cd C:\Users\nisar\virtual-pet-app

# This is the important command — it adds the android/ folder
# without deleting any of our custom code in lib/
flutter create .

flutter pub get
```

After this you will see new folders: `android/`, `ios/`, etc.

---

## Step 3: Build the Release APK

```powershell
flutter build apk --release
```

This can take 1-5 minutes the first time (it downloads Gradle + Android tools).

When it finishes, it will print the location. The file is usually here:

`build\app\outputs\flutter-apk\app-release.apk`

---

## Step 4: Send the APK to your girlfriend

1. Copy `app-release.apk` to somewhere easy (Desktop).
2. Rename it to something cute, e.g. `Bubbles-The-Virtual-Pet.apk`
3. Send it via:
   - WhatsApp
   - Telegram
   - Google Drive link
   - Email

---

## Step 5: How she installs it on her Android phone

1. She downloads the file.
2. On her phone: Settings → Security (or "Apps & notifications" → Special app access) → "Install unknown apps"
3. Allow it for Chrome, Files, or the app she used to download.
4. Tap the APK file → Install.
5. Open the app.

**Note:** First launch it will create "Bubbles" the whale. She can switch pets using the menu in the top right.

The app has full working RAG memory — when she uses the Talk tab, the pet can recall things she did earlier.

---

## Troubleshooting

- `flutter doctor` complains about Android license? Run:
  ```powershell
  flutter doctor --android-licenses
  ```
  and accept the prompts.

- Build fails with Gradle errors? Delete the `android/` folder and run `flutter create .` again, then `flutter clean` before building.

- APK is too big? For now it's a prototype. Later we can optimize.

---

## Alternative (No heavy install on your PC): GitHub Actions

If you don't want to install 1-2 GB of Android tools locally, reply with "help me use github actions" and I will:
- Help you push this folder to a free GitHub repo
- Add a workflow file that builds the APK in the cloud for free every time you push
- You just download the finished APK from the "Actions" tab

This is often easier for one-off sharing.

---

Enjoy surprising her with a pet that actually remembers her! 🐳

(Once she has it running, ask her to try the Talk tab and tell you what the pet "remembers".)
