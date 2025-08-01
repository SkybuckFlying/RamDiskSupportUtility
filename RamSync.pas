unit RamSync;

interface

Uses Definitions;

procedure LoadRamDisk(Var config:TRamDisk);
procedure SaveRamDisk(Var existing:TRamDisk);
procedure RestoreTempFolder(letter:Char);

implementation

uses SysUtils,Windows,Registry,Classes,Junctions;

const
  DIR_ATTR = FILE_ATTRIBUTE_DIRECTORY or FILE_ATTRIBUTE_REPARSE_POINT;

type
  TStrArray = Array of string;
  TPathList = Array Of TStrArray;

procedure CopyTime(const src,dest:string);
var
  hDir:THandle;
  creationTime,accessTime,writeTime:TFileTime;
Begin
  hDir := CreateFile(PChar(src), 0, FILE_SHARE_READ, NIL, OPEN_EXISTING, 0, 0);
  if hDir <> INVALID_HANDLE_VALUE Then
  begin
    GetFileTime(hDir,@creationTime,@accessTime,@writeTime);
    CloseHandle(hDir);
    hDir := CreateFile(PChar(dest), GENERIC_WRITE, FILE_SHARE_WRITE, NIL, OPEN_EXISTING, 0, 0);
    if hDir <> INVALID_HANDLE_VALUE Then
    begin
      SetFileTime(hDir,@creationTime,@accessTime,@writeTime);
      CloseHandle(hDir);
    end;
  end;
end;

procedure TreeCopy(const src,dest:string);
var
  SR: TSearchRec;
  junction,current,source: string;
Begin
  if FindFirst(src+'*.*',faAnyFile,SR)<>0 then Exit;
  try
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        //Application.ProcessMessages;
        current:=dest + SR.Name;
        source:=src + SR.Name;
        if (SR.Attr and faDirectory) <> 0 then
        begin;
          CreateDir(current);
          // check for junction point
          if (GetFileAttributes(PChar(source)) and DIR_ATTR) = DIR_ATTR Then
          Begin
            junction:=GetSymLinkTarget(source);
            If junction<>'' Then
            Begin
              CreateJunction(current, junction);
              CopyTime(source,current);
              Continue;
            end;
          end;
          TreeCopy(src + SR.Name + '\', dest + SR.Name + '\');
          CopyTime(source,current);
        end
        else
        Begin
          CopyFile(PChar(source), PChar(current),False); // we don't care if it is a symlink
          CopyTime(source,current);
        End;
      end;
    Until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure DelTree(const path:String);
var
  SR: TSearchRec;
Begin
  if FindFirst(path+'*.*',faAnyFile,SR)<>0 then Exit;
  try
    Repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin;
        if (SR.Attr and faDirectory) <> 0 then
        Begin
          DelTree(path + SR.Name + '\');
          RemoveDir(path + SR.Name);
        end
        else SysUtils.DeleteFile(path + SR.Name);
      end;
    Until FindNext(SR) <> 0;
  finally
    SysUtils.FindClose(SR);
  end;
  RemoveDir(path);
end;

Procedure LoadRamDisk(Var config:TRamDisk);
Var
  reg: TRegistry;
  tempDir:String;
Begin
  DebugLog('Configuring RAM-disk');
  If (config.persistentFolder<>'') And DirectoryExists(config.persistentFolder) Then
  Begin
    TreeCopy(IncludeTrailingPathDelimiter(config.persistentFolder),config.letter+':\');
    DebugLog('RAM-disk was populated with content from ' + config.persistentFolder);
  end;
  If config.useTemp Then
  Begin
    tempDir:=config.letter+':\TEMP';
    DebugLog('Configuring TEMP folder as ' + tempDir);
    if CreateDir(tempDir) Then
    Begin
      reg:=Nil;
      Try
        reg:=TRegistry.Create(KEY_WRITE);
        reg.RootKey:=HKEY_LOCAL_MACHINE;
        if Reg.OpenKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', True) then
        Begin
          reg.WriteExpandString('TMP',tempDir);
          reg.WriteExpandString('TEMP',tempDir);
          DebugLog('TMP and TEMP folders for all users were set');
        end;
        reg.CloseKey;

        reg.RootKey:=HKEY_CURRENT_USER;
        if Reg.OpenKey('Environment', True) then
        Begin
          reg.WriteExpandString('TMP',tempDir);
          reg.WriteExpandString('TEMP',tempDir);
          DebugLog('TMP and TEMP folders for the current user were set');
        end;
        reg.CloseKey;
      finally
        reg.Free;
      end;
    end;
  end;
  // remove $RECYCLE.BIN
  DelTree(config.letter+':\$RECYCLE.BIN\');
end;

procedure RestoreTempFolder(letter:Char);
Var
  reg: TRegistry;
  tmpFolder, tempFolder: String;
  tmp:string;
Begin
  reg:=Nil;
  try
    DebugLog('Switching to the default TEMP folder');
    reg:=TRegistry.Create(KEY_ALL_ACCESS);
    // read defaults
    reg.RootKey:=HKEY_USERS;
    if Reg.OpenKey('.DEFAULT\Environment', False) then
    Begin
      tmpFolder:=reg.ReadString('TMP');
      DebugLog(Format('Default TMP folder = %s',[tmpFolder]));
      tempFolder:=reg.ReadString('TEMP');
      DebugLog(Format('Default TEMP folder = %s',[tempFolder]));
    end;
    reg.CloseKey;
    // set active values
    reg.RootKey:=HKEY_LOCAL_MACHINE;
    if Reg.OpenKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', True) then
    Begin
      // restore default only if current setting was using the just unmounted Ramdisk
      tmp:=UpperCase(reg.ReadString('TMP'));
      If (tmp<>'')And(tmp[1] = letter) then
      Begin
        reg.WriteExpandString('TMP',tmpFolder);
        DebugLog('Restoring TMP folder for all users');
      End;
      tmp:=UpperCase(reg.ReadString('TEMP'));
      If (tmp<>'')and(tmp[1] = letter) then
      Begin
        reg.WriteExpandString('TEMP',tempFolder);
        DebugLog('Restoring TEMP folder for all users');
      End;
    end;
    reg.CloseKey;

    reg.RootKey:=HKEY_CURRENT_USER;
    if Reg.OpenKey('Environment', True) then
    Begin
      tmp:=UpperCase(reg.ReadString('TMP'));
      If (tmp<>'')and(tmp[1] = letter) then
      Begin
        reg.WriteExpandString('TMP',tmpFolder);
        DebugLog('Restoring TMP folder for the current user');
      end;
      tmp:=UpperCase(reg.ReadString('TEMP'));
      If (tmp<>'')and(tmp[1] = letter) then
      Begin
        reg.WriteExpandString('TEMP',tempFolder);
        DebugLog('Restoring TMP folder for the current user');
      end;
    end;
    reg.CloseKey;
  finally
    reg.Free;
  end;
end;

Function NewerSource(const src,dest:string):Boolean;
var
  hDir:THandle;
  srcCreation,srcAccess,srcModify,destCreation,destAccess,destModify:TFileTime;
Begin
  Result:=False;
  hDir := CreateFile(PChar(src), 0, FILE_SHARE_READ, NIL, OPEN_EXISTING, 0, 0);
  if hDir <> INVALID_HANDLE_VALUE Then
  begin
    GetFileTime(hDir,@srcCreation,@srcAccess,@srcModify);
    CloseHandle(hDir);
    hDir := CreateFile(PChar(dest), 0, FILE_SHARE_READ, NIL, OPEN_EXISTING, 0, 0);
    if hDir <> INVALID_HANDLE_VALUE Then
    begin
      GetFileTime(hDir,@destCreation,@destAccess,@destModify);
      CloseHandle(hDir);
      //-1, Source is older than Destination
      //0, Source is the same age as Destination
      //+1 Source is younger than Destination
      Result:=(CompareFileTime(srcModify,destModify)>0) or (CompareFileTime(srcCreation,destCreation)>0);
    end
    Else Result:=True; // destination probably does not exist
  end;
end;

// copy from RAM-disk to the persistent folder, excluding disabled paths
procedure TreeSave(const src,dest:string;excluded:TStringList);
var
  SR: TSearchRec;
  junction,current,source: string;
Begin
  DebugLog(Format('Now persisting folder %s',[src]));
  if FindFirst(src+'*.*',faAnyFile,SR)<>0 then Exit;
  try
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        //Application.ProcessMessages;
        current:=dest + SR.Name;
        source:=src + SR.Name;
        if (SR.Attr and faDirectory) <> 0 then
        begin
          if Assigned(excluded) And (excluded.IndexOf(UpperCase(SR.Name)) <> -1) then Continue;
          CreateDir(current);
          // check for junction point
          if (GetFileAttributes(PChar(source)) and DIR_ATTR) = DIR_ATTR Then
          Begin
            junction:=GetSymLinkTarget(source);
            If junction<>'' Then
            Begin
              CreateJunction(current, junction);
              Continue;
            end;
          end;
          TreeSave(source + '\', current + '\',Nil);
        end
        else
        Begin
          if NewerSource(source,current) then CopyFile(PChar(source), PChar(current),False); // overwrite existing
        End;
      end;
    Until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

// delete from persistent folder items which are no longer present on the RAM-disk
procedure TreeDelete(const src,dest:string;excluded:TStringList);
var
  SR: TSearchRec;
Begin
  DebugLog(Format('Now removing folder %s',[src]));
  if FindFirst(src+'*.*',faAnyFile,SR)<>0 then Exit;
  try
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        //Application.ProcessMessages;
        if (SR.Attr and faDirectory) <> 0 then
        begin
          if Assigned(excluded) And (excluded.IndexOf(UpperCase(SR.Name)) <> -1) then Continue;
          TreeDelete(src + SR.Name + '\', dest + SR.Name + '\',Nil);
          if not DirectoryExists(dest + SR.Name) then RemoveDir(src + SR.Name);
        end
        else
        Begin
          if Not FileExists(dest + SR.Name) Then DeleteFile(src + SR.Name);
        End;
      end;
    Until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

Procedure SplitPath(const path:string;var list:TStrArray);
var
  oldPos,newPos,k:Integer;
Begin
  SetLength(List,Length(path));
  k:=0;
  oldPos:=1;
  Repeat
    newPos:=PosEx('\',path,oldPos);
    if newPos=0 then list[k]:=Copy(path,oldPos,MaxInt)
    Else
    Begin
      list[k]:=Copy(path,oldPos,newPos);
      oldPos:=newPos;
    end;
    Inc(k);
  Until newPos=0;
  SetLength(list,k);
end;

Procedure SaveRamDisk(Var existing:TRamDisk);
var
  list:TStringList;
Begin
  DebugLog('Trying to persist RamDisk before unmount');
  if DirectoryExists(existing.persistentFolder) then
  Begin
    list:=Nil;
    try
      list:=TStringList.Create;
      list.Text:=UpperCase(existing.excludedList);
      list.Add('TEMP'); // always exclude TEMP folder and system folders
      list.Add('$RECYCLE.BIN');
      list.Add('System Volume Information');
      // first we persist RAM-disk, excluding disabled paths
      TreeSave(existing.letter+':\',IncludeTrailingPathDelimiter(existing.persistentFolder),list);
      DebugLog('RamDisk content was persisted');
      // then we delete the data that is not present on the RAM-disk
      if existing.deleteOld then
      Begin;
        TreeDelete(IncludeTrailingPathDelimiter(existing.persistentFolder),existing.letter+':\',list);
        DebugLog('Obsolete data inside the synchronization folder was removed');
      End;
    Finally
      list.Free;
    end;
  End
  else DebugLog(Format('Folder "%s" does not exist',[existing.persistentFolder]),EVENTLOG_ERROR_TYPE);
end;

end.