using LeHongSon.Debugging;

namespace LeHongSon;

public class LeHongSonConsts
{
    public const string LocalizationSourceName = "LeHongSon";

    public const string ConnectionStringName = "Default";

    public const bool MultiTenancyEnabled = true;


    /// <summary>
    /// Default pass phrase for SimpleStringCipher decrypt/encrypt operations
    /// </summary>
    public static readonly string DefaultPassPhrase =
        DebugHelper.IsDebug ? "gsKxGZ012HLL3MI5" : "1fc211ffd220438597b0ca86773ce45a";
}
