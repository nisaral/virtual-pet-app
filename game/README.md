# Lumina Vale (Unity 6 + URP), the 2.5D game

This machine already has:
- Unity Hub: `C:\src\UnityHub\Unity Hub.exe`
- Editor 6000.0.47f1: `C:\src\Unity\6000.0.47f1\Editor\Unity.exe`
- Android installer (needs one UAC accept): `C:\src\unity-dl\UnitySetup-Android-6000.0.47f1.exe`

1. Open Unity Hub, **sign in**, and activate a **Personal** license (batchmode cannot do this).
2. Open the `game/` folder as a project. The packages in `Packages/manifest.json` install automatically.
3. Run the menu **Lumina Vale > Setup Project**. It sets up the URP asset, shaders, Android settings and the `Glen` scene. Accept the Input System restart prompt.
   After a license is active you can also run `powershell -File tools/unity_setup.ps1`.
4. Open `Assets/_Game/Scenes/Glen.unity` and press Play. Controls: WASD/arrows to move, Space/E as the A button, Esc for the menu.
5. Art: install Blender 4.2+ and run `blender --background --python tools/blender/build_kit.py`. It writes the creature and prop GLBs into `Resources/Models` and `Resources/Kit`, and the game picks them up automatically. Until then, procedural fallbacks are used.
6. To build an APK, run **Lumina Vale > Build Android APK**, which writes `Builds/LuminaVale.apk`.
   Last local success: `game/Builds/LuminaVale.apk` from Unity 6000.6.7f1. Sideload that file.

None of this has been compiled or run yet. Expect some compile fixes on the first open.
If imported models face backwards, change the yaw in `CreatureVisual.Build`.

Android CI (GameCI) is `.github/workflows/unity-android.yml`. Add repo secrets `UNITY_LICENSE`, `UNITY_EMAIL`, and `UNITY_PASSWORD`. The Flutter APK workflow is unchanged until you retire that prototype.
