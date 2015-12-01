import std.stdio;
import std.string;
import std.getopt;
import std.file;
import std.path;
import std.xml;
import std.uuid;
import std.process;
import std.exception;
import wind.string;

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

void nicerGetoptPrinter(string text, Option[] opt)
{
    import std.stdio : stdout;
    nicerGetoptFormatter(stdout.lockingTextWriter(), text, opt);
}

void nicerGetoptFormatter(Output)(Output output, string text, Option[] opt)
{
    import std.format : formattedWrite; 
    import std.algorithm : min, max; 

    output.formattedWrite("%s\n", text); 

    size_t ls, ll; 
    bool hasRequired = false; 
    foreach (it; opt) 
    { 
        ls = max(ls, it.optShort.length); 
        ll = max(ll, it.optLong.length); 

        hasRequired = hasRequired || it.required; 
    } 

    string re = " Required: ";

    size_t prefixLength = ls + 1 + ll + (hasRequired? re.length : 1);

    foreach (it; opt) 
    {
        string[] lines = it.help.split("\n");
        foreach(i,l; lines)
        {
            if (i == 0)
                output.formattedWrite("%*s %*s%*s%s\n", ls, it.optShort, ll, it.optLong, 
                                      hasRequired ? re.length : 1, it.required ? re : " ", l);
            else
                output.formattedWrite("%*s%s\n", prefixLength, " ", l);
        }
    } 
   
}

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

bool hasSameRoot(string dir1, string dir2)
{
    return relativePath(dir1, dir2) != dir1;
}

bool isSubDir(string dir1, string dir2)
{
    string str = relativePath(dir1, dir2);
    return str != dir1 && !str.startsWith("..");
}

string helpmsg = r"
vsdir will scan files under destdir recursively and add them to vs project
with the directory structure up to the project dir.

If filter prefix is given, the directory structure in vs project will be changed
to: FilterPrefix\destdir\subdir1\subdri2\...

If the folding environment variable is given, item path will no longer be
relative to the project file path. Instead, it will become an absolute path.
The path will fold by the path that the folding var points to, e.g.:
    $(SourceRoot)\filter\prefix\sub\dir\item.cpp
";

void main(string[] argv){
    string filterPrefix;
    string foldspec;
    auto helpInformation = getopt(argv, 
                                  "filter-prefix|P", "Set the common filer prefix for all added items", &filterPrefix,
                                  "folding-var", "Set the folding environment variable: var[:val]", &foldspec,
                                  "test", "Test mode: output result contents to console", &testMode
                                  );
    if (helpInformation.helpWanted || argv.length != 3)
    {
        nicerGetoptPrinter("usage: vsdir.exe [options] projectfile destdir", helpInformation.options);
        write(helpmsg);
        return;
    }
   
    string projectFileName = argv[1].absolutePath();
    string destDir = argv[2].absolutePath();
    string foldVar = splitHead(foldspec, ':');
    string foldDir = splitTail(foldspec, ':', "");
    string projectFilterFileName = projectFileName ~ ".filters";
    string projectDir = dirName(projectFileName);

    if (foldVar && foldDir.length == 0)
    {
        foldDir = environment.get(foldVar);
        if (foldDir.length == 0)
        {
            writeln("cannot get folding-var value from process environment.");
            return;
        }
        foldDir = foldDir.absolutePath();
        if (!hasSameRoot(destDir, foldDir))
        {
            writeln("folding dir and dest dir must have the same root.");
            return;
        }
    }

    if (!filterPrefix)
    {
        if (!isSubDir(destDir, projectDir))
        {
            writeln("the project dir is not a parent of dest dir, please specify the fiter prefix explicitly.");
            return;
        }
        filterPrefix = relativePath(destDir, projectDir);
    }

    if (filterPrefix == "*")
        filterPrefix = "";

    if (filterPrefix.length > 0 && !filterPrefix.endsWith('\\'))
        filterPrefix ~= '\\';

    writeln("project:        ", projectFileName);
    writeln("project filters:", projectFilterFileName);
    writeln("fold variable:  ", foldVar);
    writeln("fold directory: ", foldDir);
    writeln("dest dir:       ", destDir);
    writeln("filter prefix   ", filterPrefix);


    VisualStudioItem[] items;
    // get all files
    auto files = dirEntries(destDir, SpanMode.depth);
    foreach (string f; files)
    {
        if (isFile(f))
        {
            string path = relativePath(f, destDir);
            if (path[0] == '.')
            {
                continue;
            }

            VisualStudioItem item;
            item.absolutePath = f;
            item.relativePath = foldVar?
                "$(%s)\\%s".format(foldVar, relativePath(f, foldDir)):
                relativePath(f, projectDir);
            item.type = GetVisualStudioDefaultTypeByFileExtension(extension(f));
            item.filter = filterPrefix ~ dirName(relativePath(f, destDir));
            items ~= item;
        }
    }

    AddFilesToVisualStudioProject(items, projectFileName, false);
    AddFilesToVisualStudioProject(items, projectFilterFileName, true);
}
