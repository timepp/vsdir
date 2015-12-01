# vsdir
batch add files to visual studio projects while preserving the directory structure.

# motivation
Microsoft Visual Studio is a good tool to study existing code because:

* syntax parser with full language semantics
* easily find inside entire solution
* ...

However, It's hard to add many source files to visual studio project while keep their existing directory structure. vsdir is the tool to help this.

# usage
``` Batchfile
vsdir.exe [options] projectfile destdir
```
You can specify the "filter-prefix" used as common folder for all added items.
The item path can also based on another variable, other than project directory, to make the generated project file sharable between peoples.
Type `vsdir.exe --help` for more information.

usage examples:

This will add all files inside `C:\src\mona` to `mona.vcxproj`, preserving the folder structure.

``` Batchfile
vsdir "C:\src\mona.vcxproj" C:\src\mona
```

This will add all files inside `Z:\src\security\vault\VaultEngine` to `VaultEngine.vcxproj`, item paths in project file will like `$(TsSrc)\security\vault\VaultEngine\...`. The folder structure inside project are the same as they are in `Z:\src\security\vault\VaultEngine` folder.

``` Batchfile
vsdir "C:\study\vault\VaultEngine\VaultEngine.vcxproj" Z:\src\security\vault\VaultEngine --folding-var=TsSrc:Z:\src --filter-prefix=*
```

# TODO
* option to convert existing items to SourceRoot format
* split 'nicerGetoptPrinter' to wind

