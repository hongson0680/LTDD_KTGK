using Abp.Configuration.Startup;
using Abp.Localization.Dictionaries;
using Abp.Localization.Dictionaries.Xml;
using Abp.Reflection.Extensions;

namespace LeHongSon.Localization;

public static class LeHongSonLocalizationConfigurer
{
    public static void Configure(ILocalizationConfiguration localizationConfiguration)
    {
        localizationConfiguration.Sources.Add(
            new DictionaryBasedLocalizationSource(LeHongSonConsts.LocalizationSourceName,
                new XmlEmbeddedFileLocalizationDictionaryProvider(
                    typeof(LeHongSonLocalizationConfigurer).GetAssembly(),
                    "LeHongSon.Localization.SourceFiles"
                )
            )
        );
    }
}
