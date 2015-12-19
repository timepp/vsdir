# vsp
manipulate visual studio projects, such as:

1. batch add files while preserving the directory structure
2. ...

# motivation
Microsoft Visual Studio is a good tool to study existing code because:

* syntax parser with full language semantics
* easily find inside entire solution
* ...

However, It will waste some time to configure the project. e.g. it's hard to batch add files while keep their existing directory structure.

# usage
``` Batchfile
vsp add projectfile destdir
```
Batch add files while preserving the directory structure. 

Type `vsp --help` for more information.

# examples

This will add all files inside `C:\src\mona` to `mona.vcxproj`, preserving the folder structure.

``` Batchfile
vsp add "C:\src\mona.vcxproj" C:\src\mona
```

This will add all files inside `Z:\src\security\vault\VaultEngine` to `VaultEngine.vcxproj`, item paths in project file will like `$(TsSrc)\security\vault\VaultEngine\...`. The folder structure inside project are the same as they are in `Z:\src\security\vault\VaultEngine` folder.

``` Batchfile
vsdir "C:\study\vault\VaultEngine\VaultEngine.vcxproj" Z:\src\security\vault\VaultEngine --folding-var=TsSrc:Z:\src --filter-prefix=*
```

# TODO
* option to convert existing items to SourceRoot format
* split 'nicerGetoptPrinter' to wind

