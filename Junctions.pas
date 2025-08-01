unit Junctions;

// http://progmatix.blogspot.com/2010/10/get-target-of-symlink-in-delphi.html
// https://delphisources.ru/pages/faq/base/hardlink_symbolic_link.html
// http://www.flexhex.com/docs/articles/hard-links.phtml#junctions
// https://fossil.2of4.net/zaap/artifact/ad9fc313554aea05

interface

uses
  SysUtils;

const
    FILE_ATTRIBUTE_REPARSE_POINT = 1024;

function GetSymLinkTarget(const AFilename: string): string;
procedure CreateJunction(const ALink,ADest:string);

implementation

uses Windows;

const
  MAX_REPARSE_SIZE = 17000;
  MAX_NAME_LENGTH = 1024;
  REPARSE_MOUNTPOINT_HEADER_SIZE = 8;
  IO_REPARSE_TAG_MOUNT_POINT    = $0A0000003;
  FILE_FLAG_OPEN_REPARSE_POINT = $00200000;
  FILE_DEVICE_FILE_SYSTEM = $0009;
  FILE_ANY_ACCESS = 0;
  METHOD_BUFFERED   = 0;
  FSCTL_SET_REPARSE_POINT    = (FILE_DEVICE_FILE_SYSTEM shl 16) or (FILE_ANY_ACCESS shl 14) or (41 shl 2) or (METHOD_BUFFERED);
  FSCTL_GET_REPARSE_POINT    = (FILE_DEVICE_FILE_SYSTEM shl 16) or (FILE_ANY_ACCESS shl 14) or (42 shl 2) or (METHOD_BUFFERED);

type
  REPARSE_DATA_BUFFER = packed record
    ReparseTag: DWORD;
    ReparseDataLength: Word;
    Reserved: Word;
    SubstituteNameOffset: Word;
    SubstituteNameLength: Word;
    PrintNameOffset: Word;
    PrintNameLength: Word;
    PathBuffer: array[0..0] of WideChar;
  end;
  TReparseDataBuffer = REPARSE_DATA_BUFFER;
  PReparseDataBuffer = ^TReparseDataBuffer;

  REPARSE_MOUNTPOINT_DATA_BUFFER = packed record
    ReparseTag: DWORD;
    ReparseDataLength: DWORD;
    Reserved: Word;
    ReparseTargetLength: Word;
    ReparseTargetMaximumLength: Word;
    Reserved1: Word;
    ReparseTarget: array[0..0] of WideChar;
  end;
  TReparseMountPointDataBuffer = REPARSE_MOUNTPOINT_DATA_BUFFER;
  PReparseMountPointDataBuffer = ^TReparseMountPointDataBuffer;

  Function CreateSymbolicLinkW(Src,Target:PWideChar;Flags:Cardinal):BOOL; Stdcall; External 'kernel32.dll';

function OpenDirectory(const ADir:string;bReadWrite:Boolean):THandle;
var
  token:THandle;
  tp:TTokenPrivileges;
  bp:string;
  dw,access:DWORD;
begin
  // Obtain backup/restore privilege in case we don't have it
  if not OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES, token) then
    RaiseLastOSError;
  try
    If bReadWrite Then bp:='SeRestorePrivilege' else bp:='SeBackupPrivilege';
    if not LookupPrivilegeValue(NIL, PChar(bp), tp.Privileges[0].Luid) then
      RaiseLastOSError;
    tp.PrivilegeCount := 1;
    tp.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
    if not AdjustTokenPrivileges(token, FALSE, tp, sizeof(TOKEN_PRIVILEGES), NIL, dw) then
      RaiseLastOSError;
  finally
    CloseHandle(token);
  end;

  // Open the directory
  access:=GENERIC_READ;
  if bReadWrite then access:=access or GENERIC_WRITE;
  Result := CreateFile(PChar(ADir), access, 0, NIL, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT or FILE_FLAG_BACKUP_SEMANTICS, 0);
  if Result = INVALID_HANDLE_VALUE then
    RaiseLastOSError;
end;

function GetSymLinkTarget(const AFilename: string): string;
var
  hDir:THandle;
  nRes:DWORD;
  reparseBuffer: TBytes;
  reparseInfo: PReparseDataBuffer;
  name2: array[0..MAX_NAME_LENGTH-1] of WideChar;
begin
  hDir:= OpenDirectory(AFilename,False);
  try
    SetLength(reparseBuffer, MAX_REPARSE_SIZE);
    reparseInfo := PReparseDataBuffer(reparseBuffer);
    if DeviceIoControl(hDir, FSCTL_GET_REPARSE_POINT, nil, 0, reparseInfo, MAX_REPARSE_SIZE, nRes, nil) Then
    begin
      If reparseInfo.ReparseTag = IO_REPARSE_TAG_MOUNT_POINT then
      Begin
        FillChar(name2, SizeOf(name2), 0);
        lstrcpyn(name2, @reparseInfo.PathBuffer[reparseInfo.SubstituteNameOffset div 2], reparseInfo.SubstituteNameLength div 2);
        Result:= Copy(name2,5,Length(name2)); // remove the '\??\' prefix
      end
      else
        Result := '';
    end
    else
      RaiseLastOSError;
  finally
    CloseHandle(hDir);
  end;
end;

// target must NOT begin with "\??\" - it will be added automatically
procedure CreateJunction(const ALink,ADest:string);
Const
  LinkPrefix: string = '\\??\\';
var
  Buffer: TBytes;
  pBuffer: PReparseMountPointDataBuffer;
  BufSize: integer;
  TargetName: string;
  hDir:THandle;
  dw:DWORD;
Begin
  hDir:=OpenDirectory(ALink,True);
  try
    If Pos(LinkPrefix,ADest)=1 then TargetName:=ADest else TargetName:=LinkPrefix+ADest;
    BufSize:=(Length(TargetName)+1)*SizeOf(WideChar) + REPARSE_MOUNTPOINT_HEADER_SIZE + 12;
    SetLength(Buffer, BufSize);
    pBuffer := PReparseMountPointDataBuffer(Buffer);

    FillChar(pBuffer^,BufSize,#0);
    With pBuffer^ Do
    Begin
      Move(TargetName[1], ReparseTarget, (Length(TargetName)+1)*SizeOf(WideChar));
      ReparseTag:= IO_REPARSE_TAG_MOUNT_POINT;
      ReparseTargetLength:= Length(TargetName)*SizeOf(WideChar);
      ReparseTargetMaximumLength:= ReparseTargetLength+2;
      ReparseDataLength:= ReparseTargetLength+12;
    end;
    if not DeviceIoControl(hDir,FSCTL_SET_REPARSE_POINT,pBuffer,pBuffer.ReparseDataLength + REPARSE_MOUNTPOINT_HEADER_SIZE,Nil,0,dw,Nil) then
      RaiseLastOSError;
  finally
    CloseHandle(hDir);
  end;
end;

end.
