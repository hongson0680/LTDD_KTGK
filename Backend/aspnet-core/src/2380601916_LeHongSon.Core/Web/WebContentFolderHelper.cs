using Abp.Reflection.Extensions;
using System;
using System.IO;
using System.Linq;

namespace LeHongSon.Web;

/// <summary>
/// This class is used to find root path of the web project in;
/// unit tests (to find views) and entity framework core command line commands (to find conn string).
/// </summary>
public static class WebContentDirectoryFinder
{
    public static string CalculateContentRootFolder()
    {
        var coreAssemblyDirectoryPath = Path.GetDirectoryName(typeof(LeHongSonCoreModule).GetAssembly().Location);
        if (coreAssemblyDirectoryPath == null)
        {
            throw new Exception("Could not find location of LeHongSon.Core assembly!");
        }

        var directoryInfo = new DirectoryInfo(coreAssemblyDirectoryPath);
        while (!DirectoryContainsSolution(directoryInfo.FullName))
        {
            if (directoryInfo.Parent == null)
            {
                throw new Exception("Could not find content root folder!");
            }

            directoryInfo = directoryInfo.Parent;
        }

        var srcFolder = Path.Combine(directoryInfo.FullName, "src");
        var webMvcFolder = Directory.GetDirectories(srcFolder, "*.Web.Mvc").FirstOrDefault();
        if (webMvcFolder != null)
        {
            return webMvcFolder;
        }

        var webHostFolder = Directory.GetDirectories(srcFolder, "*.Web.Host").FirstOrDefault();
        if (webHostFolder != null)
        {
            return webHostFolder;
        }

        throw new Exception("Could not find root folder of the web project!");
    }

    private static bool DirectoryContainsSolution(string directory)
    {
        return Directory.GetFiles(directory, "*.sln").Any();
    }
}
