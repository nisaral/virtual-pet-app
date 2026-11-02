using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace LuminaVale.EditorTools
{
    /// One-click project setup and Android build. Run "Lumina Vale > Setup Project"
    /// once after opening the project, then press Play.
    public static class LuminaSetup
    {
        const string SettingsDir = "Assets/_Game/Settings";
        const string ScenePath = "Assets/_Game/Scenes/Glen.unity";
        static readonly string[] Shaders = { "LuminaVale/Toon", "LuminaVale/ToonWater", "LuminaVale/SoftParticle" };

        [MenuItem("Lumina Vale/Setup Project", priority = 0)]
        public static void Setup()
        {
            SetupPipeline();
            IncludeShaders();
            SetupPlayer();
            SetupScene();
            AssetDatabase.SaveAssets();
            Debug.Log("[Lumina Vale] Setup complete. Open Assets/_Game/Scenes/Glen.unity and press Play. " +
                      "If Unity asks to enable the new Input System backend, click Yes (it restarts the editor).");
        }

        static void SetupPipeline()
        {
            Directory.CreateDirectory(SettingsDir);
            var asset = GraphicsSettings.defaultRenderPipeline as UniversalRenderPipelineAsset;
            if (asset == null)
            {
                var renderer = ScriptableObject.CreateInstance<UniversalRendererData>();
                AssetDatabase.CreateAsset(renderer, $"{SettingsDir}/LuminaRenderer.asset");
                asset = UniversalRenderPipelineAsset.Create(renderer);
                AssetDatabase.CreateAsset(asset, $"{SettingsDir}/LuminaURP.asset");
                GraphicsSettings.defaultRenderPipeline = asset;
            }
            asset.supportsCameraDepthTexture = true;   // water foam and depth colour
            asset.supportsHDR = true;                  // bloom on lanterns and evolution light
            asset.shadowDistance = 18f;
            asset.shadowCascadeCount = 1;
            asset.msaaSampleCount = 2;
            asset.renderScale = 1f;
            EditorUtility.SetDirty(asset);
            for (int i = 0; i < QualitySettings.names.Length; i++)
            {
                QualitySettings.SetQualityLevel(i, false);
                QualitySettings.renderPipeline = asset;
            }
            PlayerSettings.colorSpace = ColorSpace.Linear;
        }

        static void IncludeShaders()
        {
            var gs = AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/GraphicsSettings.asset").FirstOrDefault();
            if (gs == null) return;
            var so = new SerializedObject(gs);
            var list = so.FindProperty("m_AlwaysIncludedShaders");
            foreach (var name in Shaders)
            {
                var shader = Shader.Find(name);
                if (shader == null) { Debug.LogWarning($"[Lumina Vale] Shader {name} not found yet — reimport Assets/_Game/Shaders."); continue; }
                bool present = false;
                for (int i = 0; i < list.arraySize; i++)
                    if (list.GetArrayElementAtIndex(i).objectReferenceValue == shader) present = true;
                if (present) continue;
                list.InsertArrayElementAtIndex(list.arraySize);
                list.GetArrayElementAtIndex(list.arraySize - 1).objectReferenceValue = shader;
            }
            so.ApplyModifiedProperties();
        }

        static void SetupPlayer()
        {
            PlayerSettings.companyName = "Lumina Vale";
            PlayerSettings.productName = "Lumina Vale";
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, "com.luminavale.game");
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel26;
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;
            PlayerSettings.SetGraphicsAPIs(BuildTarget.Android, new[] { GraphicsDeviceType.Vulkan, GraphicsDeviceType.OpenGLES3 });
            PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.Android, false);
            EditorUserBuildSettings.androidBuildSubtarget = MobileTextureSubtarget.ASTC;
            EditorUserBuildSettings.SwitchActiveBuildTarget(NamedBuildTarget.Android, BuildTarget.Android);

            string sdk = Environment.GetEnvironmentVariable("ANDROID_HOME") ?? @"C:\Android";
            string jdk = Environment.GetEnvironmentVariable("JAVA_HOME") ?? @"C:\src\jdk";
            if (Directory.Exists(sdk))
            {
                EditorPrefs.SetString("AndroidSdkRoot", sdk);
                EditorPrefs.SetBool("SdkUseEmbedded", false);
                UnityEditor.Android.AndroidExternalToolsSettings.sdkRootPath = sdk;
            }
            if (Directory.Exists(jdk))
            {
                EditorPrefs.SetString("JdkPath", jdk);
                EditorPrefs.SetBool("JdkUseEmbedded", false);
                UnityEditor.Android.AndroidExternalToolsSettings.jdkRootPath = jdk;
            }
            string ndkDir = Path.Combine(sdk, "ndk");
            if (Directory.Exists(ndkDir))
            {
                var ndk = Directory.GetDirectories(ndkDir);
                Array.Sort(ndk);
                string pick = ndk.FirstOrDefault(p => p.Contains("27.2")) ?? (ndk.Length > 0 ? ndk[0] : null);
                if (pick != null)
                {
                    EditorPrefs.SetString("AndroidNdkRoot", pick);
                    EditorPrefs.SetBool("NdkUseEmbedded", false);
                    UnityEditor.Android.AndroidExternalToolsSettings.ndkRootPath = pick;
                }
            }

            // "Both" input backends: Input System for the game, legacy kept so nothing breaks.
            var ps = AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/ProjectSettings.asset").FirstOrDefault();
            if (ps != null)
            {
                var so = new SerializedObject(ps);
                var prop = so.FindProperty("activeInputHandler");
                if (prop != null && prop.intValue != 2) { prop.intValue = 2; so.ApplyModifiedProperties(); }
            }
        }

        static void SetupScene()
        {
            Directory.CreateDirectory(Path.GetDirectoryName(ScenePath)!);
            if (!File.Exists(ScenePath))
            {
                var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
                new GameObject("Director").AddComponent<Director>();
                EditorSceneManager.SaveScene(scene, ScenePath);
            }
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
        }

        [MenuItem("Lumina Vale/Build Android APK", priority = 20)]
        public static void BuildAndroid()
        {
            Setup();
            Directory.CreateDirectory("Builds");
            var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
            {
                scenes = new[] { ScenePath },
                locationPathName = "Builds/LuminaVale.apk",
                target = BuildTarget.Android,
                options = BuildOptions.None,
            });
            Debug.Log($"[Lumina Vale] Build {report.summary.result}: {report.summary.outputPath} ({report.summary.totalSize / (1024 * 1024)} MB)");
            if (Application.isBatchMode && report.summary.result != UnityEditor.Build.Reporting.BuildResult.Succeeded) EditorApplication.Exit(1);
        }

        [MenuItem("Lumina Vale/Reset Save Data", priority = 40)]
        public static void ResetSave()
        {
            SaveSystem.Delete();
            Debug.Log("[Lumina Vale] Save deleted.");
        }
    }
}
