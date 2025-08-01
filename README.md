# GUI + background service for the Arsenal Virtual RAM-disk driver

Allows:
Ability to preload content to the RAM-disk from a local directory and synchronize the RAM-disk back on shutdown.

Features:
+ GUI for configuring the parameters of the RAM-disk
+ `Windows service` that will create the desired RAM-disk on boot and persist it on shutdown.

Compatible with/ment for:
+ Arsenal Image Mounter software (already has Arsenal Virtual RAM-disk driver installed)
  Free Mode allows the creation and usage of RAM Disks:
  
https://arsenalrecon.com/products/arsenal-image-mounter

or

+ Arsenal Virtual RAM-disk driver (stand alone installation for console usage)
https://github.com/ArsenalRecon/Arsenal-Image-Mounter/tree/master/DriverSetup












For virtual RAM-disk driver stand-alone setup follow this guide, otherwise ignore it:

The code requires Admin privileges and the Arsenal driver - which can be downloaded from its [official repository](https://github.com/ArsenalRecon/Arsenal-Image-Mounter/tree/master/DriverSetup). 
Thanks to user `lazychris2000` here is a short instruction how to install the Arsenal driver:

### Hassle-free (automatic) way

- download [https://github.com/ArsenalRecon/Arsenal-Image-Mounter/raw/master/DriverSetup/DriverSetup.7z](https://github.com/ArsenalRecon/Arsenal-Image-Mounter/raw/master/DriverSetup/DriverSetup.7z)
- extract the archive into some folder, for example `c:\arsenal`
- using an elevated Administrator command prompt, run the following commands:

```
c:
cd \arsenal\cli\x64
aim_ll.exe --install ..\..

```

- you should get something similar to the following

```
Detected Windows kernel version 10.0.19045.
Platform code: 'Win10'. Using port driver storport.sys.

Reading inf file...
Creating device object...
Installing driver for device...
Finished successfully.
```

### Manual way

- download [https://github.com/ArsenalRecon/Arsenal-Image-Mounter/raw/master/DriverSetup/DriverFiles.zip](https://github.com/ArsenalRecon/Arsenal-Image-Mounter/raw/master/DriverSetup/DriverFiles.zip)
- extract the archive into some folder, for example `c:\arsenal`
- using Windows Explorer, open the appropriate subfolder - e.g. `Win8` or `Win8.1` or `Win10` or perhaps `Win7`
- point your mouse over `phdskmnt.inf` file in the given subfolder and click the **right** mouse button to open the context menu
- from this context menu, choose the item `Install` and the Arsenal driver will be installed. You should see it in the Device Manager as `Arsenal Image Mounter` under the group `Storage controllers`

You will need Delphi 12.3 in order to compile the source code of **RamDiskUI** - or you can simply download the binary release. 
All pull requests are welcome.

## Explanation of the registry values

The RAM-disk UI (not the Arsenal driver) creates several registry values which are then picked up by the RAM-disk service (not in real-time unfortunately - only on **start** or **restart** of the service).
They are created under `[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\ArsenalRamDisk]` and are explained below:

- `DiskSize` is the size in bytes
- `DriveLetter` is obvious
- `LoadContent` is path to a folder whose contents will be pre-loaded in the RAM-disk at startup
- `ExcludeFolders` is StringList (lines delimited with CRLF) which specifies which folder names from the RAM-disk won't be saved on shutdown in the folder specified by `LoadContent`. I usually create numeric folders in my RAM-disk for my daily projects - but I don't want them to be persisted on disk because I can pull them with Git every morning.
- `UseTempFolder` whether to create TEMP folder on RAM-disk and point the OS to this temp folder
- `SyncContent` whether to save RAM-disk content on shutdown to the folder specified by `LoadContent`
- `DeleteOld` whether to delete those files and folders from `LoadContent` which are not present on the RAM-disk on shutdown (meaningful only when `SyncContent` is TRUE)

Here is an example from my PC:

```
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\services\ArsenalRamDisk]
"DiskSize"="17179869184"
"DriveLetter"="Z"
"LoadContent"="D:\\Setup\\RAM_disk"
"ExcludeFolders"="chrome
opera
phpstorm
stoplight
_
0
1
2
3
4
5
6
7
8
9"
"UseTempFolder"=dword:00000001
"SyncContent"=dword:00000001
"DeleteOld"=dword:00000001
"Type"=dword:00000010
"Start"=dword:00000002
"ErrorControl"=dword:00000001
"ImagePath"=hex(2):44,00,3a,00,5c,00,53,00,4f,00,55,00,52,00,43,00,45,00,5c,00,\
  44,00,45,00,4c,00,46,00,49,00,5c,00,52,00,41,00,4d,00,64,00,69,00,73,00,6b,\
  00,5c,00,52,00,61,00,6d,00,53,00,65,00,72,00,76,00,69,00,63,00,65,00,2e,00,\
  65,00,78,00,65,00,00,00
"DisplayName"="Arsenal RAM-disk"
"WOW64"=dword:00000001
"ObjectName"="LocalSystem"
"Description"="Arsenal RAM-disk"
```

# LICENSE

MIT License

Copyright (c) 2021 tmcdos
Copyright (c) 2025 Skybuck Flying

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
