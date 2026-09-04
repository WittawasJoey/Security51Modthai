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
    public const string PluginVersion = "0.1.1";

    private Harmony _harmony;

    public override void Load()
    {
        ModRuntime.Logger = Log;
        ModRuntime.DataDirectory = Path.Combine(Paths.PluginPath, "Security51Thai");
        ModRuntime.LoadTranslations();

        _harmony = new Harmony(PluginGuid);
        _harmony.PatchAll(typeof(LocalizationInitializePatch));
        _harmony.PatchAll(typeof(LocalizationUpdateSourcesPatch));

        Log.LogInfo($"{PluginName} {PluginVersion} loaded with {ModRuntime.TranslationCount} translations.");
        ModRuntime.TryApply("plugin-load");
    }
}

internal static class ModRuntime
{
    private const string ThaiLanguageName = "Thai";
    private const string ThaiLanguageCode = "th";
    private const string BundledFontFileName = "NotoSansThai-Variable.ttf";
    private const string ThaiGlyphProbe = "กขคงจฉชซญฎฏฐฑฒณดตถทธนบปผพภมยรลวศษสหฬอฮะาิีึืุูเแโใไ่้๊๋์";
    private static readonly string[] PreferredWindowsFontFamilies =
    {
        "Leelawadee UI",
        "Tahoma",
        "Nirmala UI",
        "Arial"
    };

    private static Dictionary<string, string> _translations = new(StringComparer.Ordinal);
    private static bool _applying;
    private static TMP_FontAsset _thaiFontAsset;
    private static readonly HashSet<int> HiddenPlaceholderInstanceIds = new();

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

    internal static void TryApply(string trigger)
    {
        if (_applying || _translations.Count == 0)
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

            var applied = 0;
            foreach (var source in sources)
            {
                if (source is null)
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
            }

            if (applied == 0)
            {
                Logger?.LogWarning($"No matching I2 terms were found ({trigger}).");
                return;
            }

            LocalizationManager.SetLanguageAndCode(
                ThaiLanguageName,
                ThaiLanguageCode,
                RememberLanguage: false,
                Force: true);
            LocalizationManager.LocalizeAll(Force: true);
            try
            {
                InjectThaiFontFallback();
                LocalizationManager.LocalizeAll(Force: true);
                HideStrayButtonPlaceholderLabels();
            }
            catch (Exception fontException)
            {
                Logger?.LogError($"Thai translations were applied, but font fallback failed: {fontException}");
            }
            Logger?.LogInfo($"Applied {applied} Thai term values ({trigger}).");
        }
        catch (Exception exception)
        {
            Logger?.LogError($"Failed to apply Thai localization ({trigger}): {exception}");
        }
        finally
        {
            _applying = false;
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
        if (globalFallbacks is not null && !globalFallbacks.Contains(_thaiFontAsset))
            globalFallbacks.Add(_thaiFontAsset);

        foreach (var text in Resources.FindObjectsOfTypeAll<TMP_Text>())
        {
            var font = text.font;
            if (font?.fallbackFontAssetTable is not null && !font.fallbackFontAssetTable.Contains(_thaiFontAsset))
                font.fallbackFontAssetTable.Add(_thaiFontAsset);
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
        if (!candidate.TryAddCharacters(ThaiGlyphProbe, out var missingCharacters, includeFontFeatures: false))
        {
            Logger?.LogWarning($"{sourceDescription} is missing Thai probe characters: {missingCharacters}");
            return false;
        }

        candidate.name = "Security51 Thai Dynamic Fallback";
        _thaiFontAsset = candidate;
        return true;
    }

    private static void HideStrayButtonPlaceholderLabels()
    {
        var hidden = 0;
        foreach (var text in Resources.FindObjectsOfTypeAll<TMP_Text>())
        {
            if (text is null || !string.Equals(text.text?.Trim(), "Button", StringComparison.Ordinal))
                continue;

            text.enabled = false;
            if (HiddenPlaceholderInstanceIds.Add(text.GetInstanceID()))
                hidden++;
        }

        foreach (var text in Resources.FindObjectsOfTypeAll<UnityEngine.UI.Text>())
        {
            if (text is null || !string.Equals(text.text?.Trim(), "Button", StringComparison.Ordinal))
                continue;

            text.enabled = false;
            if (HiddenPlaceholderInstanceIds.Add(text.GetInstanceID()))
                hidden++;
        }

        if (hidden > 0)
            Logger?.LogInfo($"Hidden {hidden} stray UI placeholder label(s) containing the exact text 'Button'.");
    }

}

[HarmonyPatch(typeof(LocalizationManager), nameof(LocalizationManager.InitializeIfNeeded))]
internal static class LocalizationInitializePatch
{
    [HarmonyPostfix]
    private static void Postfix() => ModRuntime.TryApply("InitializeIfNeeded");
}

[HarmonyPatch(typeof(LocalizationManager), nameof(LocalizationManager.UpdateSources))]
internal static class LocalizationUpdateSourcesPatch
{
    [HarmonyPostfix]
    private static void Postfix() => ModRuntime.TryApply("UpdateSources");
}
