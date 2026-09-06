using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using BepInEx;
using BepInEx.Logging;
using BepInEx.Unity.IL2CPP;
using HarmonyLib;
using I2.Loc;
using TMPro;
using UnityEngine;
using UnityEngine.TextCore.LowLevel;

namespace Security51ThaiMod;

[BepInPlugin(PluginGuid, PluginName, PluginVersion)]
public sealed class Plugin : BasePlugin
{
    public const string PluginGuid = "th.security51.localization";
    public const string PluginName = "Security 51 Thai Mod";
    public const string PluginVersion = "0.1.5";

    private Harmony _harmony;

    public override void Load()
    {
        ModRuntime.Logger = Log;
        ModRuntime.DataDirectory = Path.Combine(Paths.PluginPath, "Security51Thai");
        ModRuntime.LoadTranslations();

        _harmony = new Harmony(PluginGuid);
        _harmony.PatchAll(typeof(LocalizationUpdateSourcesPatch));
        _harmony.PatchAll(typeof(CityOperationsWindowViewOnEnablePatch));
        _harmony.PatchAll(typeof(CityOperationsWindowViewSetConfirmButtonStatePatch));
        // Note: LocalizationInitializePatch is deliberately omitted. Hooking InitializeIfNeeded
        // caused infinite recursion with get_CurrentLanguage() triggering 0xc00000fd (stack overflow).

        try
        {
            UnityEngine.SceneManagement.SceneManager.sceneLoaded +=
                (UnityEngine.Events.UnityAction<UnityEngine.SceneManagement.Scene, UnityEngine.SceneManagement.LoadSceneMode>)((scene, mode) =>
                {
                    ModRuntime.OnSceneLoaded(scene.name);
                });
        }
        catch (Exception ex)
        {
            Log.LogWarning($"Failed to subscribe to sceneLoaded: {ex.Message}");
        }

        Log.LogInfo($"{PluginName} {PluginVersion} loaded with {ModRuntime.TranslationCount} translations.");
        ModRuntime.TryApply("plugin-load");
    }
}

internal static class ModRuntime
{
    private const string ThaiLanguageName = "Thai";
    private const string ThaiLanguageCode = "th";
    private const string BundledFontFileName = "NotoSansThai-Variable.ttf";

    // Complete assigned Thai Unicode character set (U+0E01 through U+0E5B)
    // Covers all consonants, vowels, tone marks (่ ้ ๊ ๋), punctuation, and Thai numerals.
    private static readonly string ThaiGlyphSet = string.Concat(
        Enumerable.Range(0x0E01, 0x0E5B - 0x0E01 + 1)
            .Select(c => (char)c)
            .Where(c => System.Globalization.CharUnicodeInfo.GetUnicodeCategory(c) != System.Globalization.UnicodeCategory.OtherNotAssigned));

    private static readonly string[] PreferredWindowsFontFamilies =
    {
        "Leelawadee UI",
        "Tahoma",
        "Nirmala UI",
        "Arial"
    };

    private static Dictionary<string, string> _translations = new(StringComparer.Ordinal);
    private static bool _applying;
    private static bool _isSettingLanguage;
    private static bool _termsInjected;
    private static TMP_FontAsset _thaiFontAsset;

    // Track native IL2CPP pointers to prevent redundant repetitive processing
    private static readonly HashSet<IntPtr> _configuredSourcePointers = new();
    private static readonly HashSet<IntPtr> _configuredFontPointers = new();
    private static readonly HashSet<int> _hiddenPlaceholderInstanceIds = new();

    internal static ManualLogSource Logger { get; set; }
    internal static string DataDirectory { get; set; } = string.Empty;
    internal static int TranslationCount => _translations.Count;

    internal static void LoadTranslations()
    {
        var path = Path.Combine(DataDirectory, "strings.th.json");
        if (!File.Exists(path))
        {
            Logger?.LogError($"Thai translation file not found: {path}");
            return;
        }

        var json = File.ReadAllText(path, System.Text.Encoding.UTF8);
        _translations = JsonSerializer.Deserialize<Dictionary<string, string>>(json)
            ?? new Dictionary<string, string>(StringComparer.Ordinal);
        _translations = new Dictionary<string, string>(_translations, StringComparer.Ordinal);
    }

    internal static void OnSceneLoaded(string sceneName)
    {
        Logger?.LogDebug($"Scene loaded: {sceneName}");
        TryApply($"SceneLoaded:{sceneName}");
        HideStrayButtonPlaceholderLabels();
    }

    internal static void EnsureThaiActive(string trigger)
    {
        if (_applying || _isSettingLanguage || _translations.Count == 0)
            return;

        if (!_termsInjected)
        {
            TryApply(trigger);
            return;
        }

        // Fast path: inspect raw backing field mCurrentLanguage without invoking InitializeIfNeeded()
        var current = LocalizationManager.mCurrentLanguage;
        if (string.Equals(current, ThaiLanguageName, StringComparison.Ordinal))
            return;

        SetThaiLanguage(trigger);
    }

    internal static void TryApply(string trigger)
    {
        if (_applying || _isSettingLanguage || _translations.Count == 0)
            return;

        _applying = true;
        try
        {
            var sources = LocalizationManager.Sources;
            if (sources is null || sources.Count == 0)
            {
                Logger?.LogDebug($"I2 sources are not ready ({trigger}).");
                return;
            }

            var newlyConfigured = 0;
            var applied = 0;
            foreach (var source in sources)
            {
                if (source is null)
                    continue;

                var ptr = source.Pointer;
                if (_configuredSourcePointers.Contains(ptr))
                    continue;

                var languageIndex = source.GetLanguageIndexFromCode(
                    ThaiLanguageCode,
                    exactMatch: true,
                    ignoreDisabled: true);
                if (languageIndex < 0)
                {
                    source.AddLanguage(ThaiLanguageName, ThaiLanguageCode);
                    languageIndex = source.GetLanguageIndexFromCode(
                        ThaiLanguageCode,
                        exactMatch: true,
                        ignoreDisabled: true);
                }

                if (languageIndex < 0)
                {
                    Logger?.LogError("I2 failed to add the Thai language.");
                    continue;
                }

                foreach (var pair in _translations)
                {
                    var term = source.GetTermData(pair.Key, allowCategoryMistmatch: false);
                    if (term is null)
                        continue;
                    term.SetTranslation(languageIndex, pair.Value, specialization: string.Empty);
                    applied++;
                }
                source.UpdateDictionary(force: true);
                _configuredSourcePointers.Add(ptr);
                newlyConfigured++;
            }

            if (newlyConfigured > 0)
            {
                _termsInjected = true;
                Logger?.LogInfo($"Applied {applied} Thai term values ({trigger}). Configured {newlyConfigured} source(s).");
            }
        }
        catch (Exception exception)
        {
            Logger?.LogError($"Failed to apply Thai localization ({trigger}): {exception}");
        }
        finally
        {
            _applying = false;
        }

        SetThaiLanguage(trigger);
    }

    private static void SetThaiLanguage(string trigger)
    {
        if (_isSettingLanguage)
            return;

        _isSettingLanguage = true;
        try
        {
            var current = LocalizationManager.mCurrentLanguage;
            if (!string.Equals(current, ThaiLanguageName, StringComparison.Ordinal))
            {
                LocalizationManager.SetLanguageAndCode(
                    ThaiLanguageName,
                    ThaiLanguageCode,
                    RememberLanguage: true,
                    Force: true);
            }

            InjectThaiFontFallback();
            LocalizationManager.LocalizeAll(Force: true);
            HideStrayButtonPlaceholderLabels();
            Logger?.LogInfo($"Activated Thai language ({trigger}).");
        }
        catch (Exception ex)
        {
            Logger?.LogError($"Failed to set Thai language ({trigger}): {ex}");
        }
        finally
        {
            _isSettingLanguage = false;
        }
    }

    private static void InjectThaiFontFallback()
    {
        if (_thaiFontAsset is null)
        {
            var bundledFontPath = Path.Combine(DataDirectory, "fonts", BundledFontFileName);
            if (File.Exists(bundledFontPath))
            {
                var bundledCandidate = TMP_FontAsset.CreateFontAsset(
                    bundledFontPath,
                    faceIndex: 0,
                    samplingPointSize: 32,
                    atlasPadding: 5,
                    renderMode: GlyphRenderMode.SDFAA,
                    atlasWidth: 1024,
                    atlasHeight: 1024);
                if (TryUseThaiFontCandidate(bundledCandidate, $"bundled font '{BundledFontFileName}'"))
                    Logger?.LogInfo($"Created Thai TMP fallback from bundled font '{BundledFontFileName}'.");
            }
            else
            {
                Logger?.LogWarning($"Bundled Thai font was not found: {bundledFontPath}");
            }
        }

        if (_thaiFontAsset is null)
        {
            foreach (var fontFamilyName in PreferredWindowsFontFamilies)
            {
                var candidate = TMP_FontAsset.CreateFontAsset(fontFamilyName, "Regular", 32);
                if (candidate is null)
                {
                    Logger?.LogWarning($"TextMeshPro could not open Windows font '{fontFamilyName}'.");
                    continue;
                }

                if (!TryUseThaiFontCandidate(candidate, $"Windows font '{fontFamilyName}'"))
                    continue;

                Logger?.LogInfo($"Created Thai TMP fallback from Windows font '{fontFamilyName}'.");
                break;
            }
        }

        if (_thaiFontAsset is null)
        {
            Logger?.LogError("Neither the bundled font nor a Windows font with the required Thai glyphs was available.");
            return;
        }

        var globalFallbacks = TMP_Settings.fallbackFontAssets;
        if (globalFallbacks is not null && globalFallbacks.Contains(_thaiFontAsset))
            globalFallbacks.Remove(_thaiFontAsset);

        // Iterate font assets directly (O(fonts) instead of O(all text components in hierarchy))
        foreach (var font in Resources.FindObjectsOfTypeAll<TMP_FontAsset>())
        {
            if (font is null || font == _thaiFontAsset)
                continue;

            // Never inject fallback into EmptyFont or zero-glyph dummy placeholder fonts
            var fontName = font.name;
            if (!string.IsNullOrEmpty(fontName) && fontName.IndexOf("Empty", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                if (font.fallbackFontAssetTable is not null && font.fallbackFontAssetTable.Contains(_thaiFontAsset))
                {
                    font.fallbackFontAssetTable.Remove(_thaiFontAsset);
                }
                continue;
            }

            var ptr = font.Pointer;
            if (_configuredFontPointers.Contains(ptr))
                continue;

            if (font.fallbackFontAssetTable is not null && !font.fallbackFontAssetTable.Contains(_thaiFontAsset))
            {
                font.fallbackFontAssetTable.Add(_thaiFontAsset);
            }
            _configuredFontPointers.Add(ptr);
        }
    }

    private static bool TryUseThaiFontCandidate(TMP_FontAsset candidate, string sourceDescription)
    {
        if (candidate is null)
        {
            Logger?.LogWarning($"TextMeshPro could not open {sourceDescription}.");
            return false;
        }

        candidate.atlasPopulationMode = AtlasPopulationMode.Dynamic;
        candidate.isMultiAtlasTexturesEnabled = true;

        // Pre-cache full Thai Unicode glyphs with OpenType font features (GSUB/GPOS) upfront
        // to eliminate frametime spikes during runtime text rendering.
        if (!candidate.TryAddCharacters(ThaiGlyphSet, out var missingCharacters, includeFontFeatures: true))
        {
            Logger?.LogWarning($"{sourceDescription} is missing some Thai characters: {missingCharacters}");
        }

        candidate.name = "Security51 Thai Dynamic Fallback";
        _thaiFontAsset = candidate;
        return true;
    }

    internal static void CleanWindowViewButtons(CityOperations.Views.CityOperationsWindowView view)
    {
        if (view is null) return;
        try
        {
            CleanButtonPlaceholder(view.confirmButton);
            CleanButtonPlaceholder(view.backButton);

            var buttons = view.GetComponentsInChildren<UnityEngine.UI.Button>(true);
            if (buttons is not null)
            {
                foreach (var btn in buttons)
                {
                    CleanButtonPlaceholder(btn);
                }
            }
        }
        catch (Exception ex)
        {
            Logger?.LogWarning($"Error cleaning buttons in CityOperationsWindowView: {ex.Message}");
        }
    }

    internal static void CleanButtonPlaceholder(UnityEngine.UI.Button button)
    {
        if (button is null) return;
        try
        {
            var allTmp = button.GetComponentsInChildren<TMP_Text>(true);
            if (allTmp is not null)
            {
                foreach (var text in allTmp)
                {
                    if (text is null) continue;
                    if (IsPlaceholderLabel(text, button))
                    {
                        text.enabled = false;
                        _hiddenPlaceholderInstanceIds.Add(text.GetInstanceID());
                    }
                }
            }

            var allUiText = button.GetComponentsInChildren<UnityEngine.UI.Text>(true);
            if (allUiText is not null)
            {
                foreach (var text in allUiText)
                {
                    if (text is null) continue;
                    if (IsPlaceholderLabel(text, button))
                    {
                        text.enabled = false;
                        _hiddenPlaceholderInstanceIds.Add(text.GetInstanceID());
                    }
                }
            }
        }
        catch (Exception ex)
        {
            Logger?.LogWarning($"CleanButtonPlaceholder failed for button '{button.name}': {ex.Message}");
        }
    }

    private static bool IsPlaceholderLabel(TMP_Text text, UnityEngine.UI.Button button)
    {
        if (text is null || button is null)
            return false;

        // Never hide localized text
        if (text.GetComponent<I2.Loc.Localize>() is not null)
            return false;

        var rawText = text.text;
        if (string.IsNullOrWhiteSpace(rawText))
            return false;

        if (!string.Equals(rawText.Trim(), "Button", StringComparison.OrdinalIgnoreCase))
            return false;

        // Condition A: Font is explicitly an Empty font (placeholder font intended to have 0 glyphs)
        var font = text.font;
        if (font is not null && !string.IsNullOrEmpty(font.name) &&
            font.name.IndexOf("Empty", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            return true;
        }

        // Condition B: Parent button already has another valid text label
        var allTmp = button.GetComponentsInChildren<TMP_Text>(true);
        if (allTmp is not null)
        {
            foreach (var other in allTmp)
            {
                if (other is not null && other != text &&
                    !string.Equals(other.text?.Trim(), "Button", StringComparison.OrdinalIgnoreCase) &&
                    !string.IsNullOrWhiteSpace(other.text))
                {
                    return true;
                }
            }
        }

        var allUiText = button.GetComponentsInChildren<UnityEngine.UI.Text>(true);
        if (allUiText is not null)
        {
            foreach (var other in allUiText)
            {
                if (other is not null &&
                    !string.Equals(other.text?.Trim(), "Button", StringComparison.OrdinalIgnoreCase) &&
                    !string.IsNullOrWhiteSpace(other.text))
                {
                    return true;
                }
            }
        }

        // Condition C: Button contains an icon component (e.g. InputIconImage)
        if (button.GetComponentInChildren<GamepadInput.Icons.InputIconImage>(true) is not null)
        {
            return true;
        }

        return false;
    }

    private static bool IsPlaceholderLabel(UnityEngine.UI.Text text, UnityEngine.UI.Button button)
    {
        if (text is null || button is null)
            return false;

        if (text.GetComponent<I2.Loc.Localize>() is not null)
            return false;

        var rawText = text.text;
        if (string.IsNullOrWhiteSpace(rawText))
            return false;

        if (!string.Equals(rawText.Trim(), "Button", StringComparison.OrdinalIgnoreCase))
            return false;

        var font = text.font;
        if (font is not null && !string.IsNullOrEmpty(font.name) &&
            font.name.IndexOf("Empty", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            return true;
        }

        var allUiText = button.GetComponentsInChildren<UnityEngine.UI.Text>(true);
        if (allUiText is not null)
        {
            foreach (var other in allUiText)
            {
                if (other is not null && other != text &&
                    !string.Equals(other.text?.Trim(), "Button", StringComparison.OrdinalIgnoreCase) &&
                    !string.IsNullOrWhiteSpace(other.text))
                {
                    return true;
                }
            }
        }

        var allTmp = button.GetComponentsInChildren<TMP_Text>(true);
        if (allTmp is not null)
        {
            foreach (var other in allTmp)
            {
                if (other is not null &&
                    !string.Equals(other.text?.Trim(), "Button", StringComparison.OrdinalIgnoreCase) &&
                    !string.IsNullOrWhiteSpace(other.text))
                {
                    return true;
                }
            }
        }

        if (button.GetComponentInChildren<GamepadInput.Icons.InputIconImage>(true) is not null)
        {
            return true;
        }

        return false;
    }

    internal static void HideStrayButtonPlaceholderLabels()
    {
        // 1. Re-enable any previously hidden components whose text dynamically changed away from "Button"
        if (_hiddenPlaceholderInstanceIds.Count > 0)
        {
            foreach (var text in Resources.FindObjectsOfTypeAll<TMP_Text>())
            {
                if (text is null) continue;
                var id = text.GetInstanceID();
                if (_hiddenPlaceholderInstanceIds.Contains(id) &&
                    !string.Equals(text.text?.Trim(), "Button", StringComparison.OrdinalIgnoreCase))
                {
                    text.enabled = true;
                    _hiddenPlaceholderInstanceIds.Remove(id);
                }
            }
            foreach (var text in Resources.FindObjectsOfTypeAll<UnityEngine.UI.Text>())
            {
                if (text is null) continue;
                var id = text.GetInstanceID();
                if (_hiddenPlaceholderInstanceIds.Contains(id) &&
                    !string.Equals(text.text?.Trim(), "Button", StringComparison.OrdinalIgnoreCase))
                {
                    text.enabled = true;
                    _hiddenPlaceholderInstanceIds.Remove(id);
                }
            }
        }

        var hidden = 0;

        // 2. Surgically inspect TMP_Text components on buttons
        foreach (var text in Resources.FindObjectsOfTypeAll<TMP_Text>())
        {
            if (text is null) continue;
            var button = text.GetComponentInParent<UnityEngine.UI.Button>();
            if (button is null) continue;

            if (IsPlaceholderLabel(text, button))
            {
                text.enabled = false;
                if (_hiddenPlaceholderInstanceIds.Add(text.GetInstanceID()))
                    hidden++;
            }
        }

        // 3. Surgically inspect standard UnityEngine.UI.Text components on buttons
        foreach (var text in Resources.FindObjectsOfTypeAll<UnityEngine.UI.Text>())
        {
            if (text is null) continue;
            var button = text.GetComponentInParent<UnityEngine.UI.Button>();
            if (button is null) continue;

            if (IsPlaceholderLabel(text, button))
            {
                text.enabled = false;
                if (_hiddenPlaceholderInstanceIds.Add(text.GetInstanceID()))
                    hidden++;
            }
        }

        if (hidden > 0)
            Logger?.LogInfo($"Hidden {hidden} stray UI placeholder label(s) overlaying button text.");
    }
}

[HarmonyPatch(typeof(LocalizationManager), nameof(LocalizationManager.UpdateSources))]
internal static class LocalizationUpdateSourcesPatch
{
    [HarmonyPostfix]
    private static void Postfix() => ModRuntime.TryApply("UpdateSources");
}

[HarmonyPatch(typeof(CityOperations.Views.CityOperationsWindowView), nameof(CityOperations.Views.CityOperationsWindowView.OnEnable))]
internal static class CityOperationsWindowViewOnEnablePatch
{
    [HarmonyPostfix]
    private static void Postfix(CityOperations.Views.CityOperationsWindowView __instance)
    {
        if (__instance is null) return;
        ModRuntime.CleanWindowViewButtons(__instance);
    }
}

[HarmonyPatch(typeof(CityOperations.Views.CityOperationsWindowView), nameof(CityOperations.Views.CityOperationsWindowView.SetConfirmButtonState))]
internal static class CityOperationsWindowViewSetConfirmButtonStatePatch
{
    [HarmonyPostfix]
    private static void Postfix(CityOperations.Views.CityOperationsWindowView __instance)
    {
        if (__instance is null) return;
        ModRuntime.CleanButtonPlaceholder(__instance.confirmButton);
    }
}
