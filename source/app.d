import std.stdio;
import std.string;
import std.getopt;
import std.file;
import std.path;
import std.xml;
import std.uuid;

/**
    Although it's called "filter" in visual studio, the same file cannot belong to different filters.
    
    In vcxproj:
    ItemGroup:
        ClCompile/ClInclude/None/ResourceCompile/Manifest/Image
        
    In vcxproj.filters:
    <ItemGroup>
        <Filter Include="tps">
            <UniqueIdentifier>{d38c671a-5665-4487-9e43-0ebe159dd8a4}</UniqueIdentifier>
        </Filter>
        <Filter Include="tps\aaa">
            <UniqueIdentifier>{248cee31-14ad-4ddb-aab3-e0d3a3e8a6af}</UniqueIdentifier>
        </Filter>
    </ItemGroup>
*/   

string rootDir;
bool testMode = false;

struct VisualStudioItem
{
    string relativePath;
    string absolutePath;
    string type;
    string filter;
};

string GetVisualStudioDefaultTypeByFileExtension(string ext)
{
    switch (ext.toLower())
    {
    case ".c":
    case ".cc":
    case ".cpp":
    case ".cxx":
        return "ClCompile";

    case ".h":
    case ".hh":
    case ".hxx":
    case ".tmh":
        return "ClInclude";

    case ".rc":
        return "ResourceCompile";

    case ".png":
    case ".jpg":
    case ".bmp":
    case ".jpeg":
        return "Image";

    default:
        break;
    }
    return "None";
}

void AddFilesToVisualStudioProject(VisualStudioItem[] items, string filename, bool withFilterInformation)
{
    string s = cast(string)std.file.read(filename);
    auto doc = new Document(s);

    bool[string] existingFiles;
    Element[string] specialElements;
    // Find correct Elements
    foreach (Element e; doc.elements)
    {
        if (e.tag.name == "ItemGroup")
        {
            if (e.elements.length > 0)
            {
                specialElements[e.elements[0].tag.name] = e;
            }

            foreach (Element fileNode; e.elements)
            {
                string path = std.path.buildNormalizedPath(std.path.dirName(filename), fileNode.tag.attr["Include"]);
                existingFiles[path.toLower()] = true;
            }
        }
    }

    bool[string] filtermap;
    foreach (VisualStudioItem item; items)
    {
        if (item.absolutePath.toLower() in existingFiles)
        {
            writeln("warning: file already exsits in project: ", item.relativePath);
            continue;
        }

        Element groupNode;
        if (item.type in specialElements)
        {
            groupNode = specialElements[item.type];
        }
        else
        {
            groupNode = new Element("ItemGroup");
            specialElements[item.type] = groupNode;
            doc ~= groupNode;
        }

        Element node = new Element(item.type);
        node.tag.attr["Include"] = item.relativePath;

        if (withFilterInformation && item.filter != ".")
        {
            node ~= new Element("Filter", item.filter);

            Element filtersNode;
            if ("Filter" in specialElements)
            {
                filtersNode = specialElements["Filter"];
            }
            else
            {
                filtersNode = new Element("ItemGroup");
                specialElements["Filter"] = filtersNode;
                doc ~= filtersNode;
            }

            if (item.filter !in filtermap)
            {
                filtermap[item.filter] = true;
                Element filterNode = new Element("Filter");
                filterNode.tag.attr["Include"] = item.filter;
                Element uuidNode = new Element("UniqueIdentifier", "{" ~ randomUUID().toString() ~ "}");
                filterNode ~= uuidNode;
                filtersNode ~= filterNode;
            }
        }

        groupNode ~= node;
    }

    string content = doc.prolog ~ join(doc.pretty(2), "\r\n") ~ doc.epilog;

    if (testMode)
    {
        writeln("new content in file: " ~ filename);
        writeln("=========================================================================================");
        writeln(content);
        writeln("=========================================================================================");
    }
    else
    {
        std.file.copy(filename, filename ~ ".bak");
        std.file.write(filename, content);
    }
}

void main(string[] argv)
{
    bool allowSpecial = false;
    auto helpInformation = getopt(
                                  argv, 
                                  "root|R", "Set root path", &rootDir,
                                  "test", "Test mode: output result contents to console", &testMode,
                                  "allow-special-entries", "Force adding special entries: file/dir starts with '.'", &allowSpecial
                                  );
    if (helpInformation.helpWanted || argv.length != 3)
    {
        defaultGetoptPrinter("usage: vsdir.exe [options] vcproj dir", helpInformation.options);
        return;
    }

    string vcprojFileName = argv[1].absolutePath();
    string destDir = argv[2].absolutePath();
    string vcprojFilterFileName = vcprojFileName ~ ".filters";
    string vcprojDirName = dirName(vcprojFileName);

    if (rootDir.length == 0)
    {
        writeln("root dir not given. using the same dir as vcproj");
        rootDir = vcprojDirName;
    }

    writef(
           "vcproj:         %s\n"
           "vcproj filters: %s\n"
           "root dir:       %s\n"
           "dest dir:       %s\n",
           vcprojFileName, vcprojFilterFileName, rootDir, destDir
             );

    // check if the root dir is really the parent of destDir
    {
        string filter = relativePath(destDir, vcprojDirName);
        if (filter == destDir || filter.length >= 2 && filter[0..2] == "..")
        {
            writeln("error. please make sure root dir is the ancestor of destDir");
            return;
        }
    }

    VisualStudioItem[] items;
    // get all files
    auto files = dirEntries(destDir, SpanMode.depth);
    foreach (string f; files)
    {
        if (isFile(f))
        {
            if (!allowSpecial)
            {
                string path = relativePath(f, destDir);
                if (path[0] == '.' || path.indexOf("\\.") != -1)
                {
                    continue;
                }
            }

            VisualStudioItem item;
            item.absolutePath = f;
            item.relativePath = relativePath(f, vcprojDirName);
            item.type = GetVisualStudioDefaultTypeByFileExtension(extension(f));
            item.filter = dirName(relativePath(f, rootDir));
            items ~= item;
        }
    }

    writeln(items);

    AddFilesToVisualStudioProject(items, vcprojFileName, false);
    AddFilesToVisualStudioProject(items, vcprojFilterFileName, true);

}
