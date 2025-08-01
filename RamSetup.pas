unit RamSetup;

interface

uses Windows;

Function ImScsiRescanScsiAdapterAsync(AsyncFlag:Boolean):THandle;

implementation

uses SysUtils,Classes,Definitions;

const
  CfgMgrDllName = 'cfgmgr32.dll';
  SetupApiModuleName = 'SETUPAPI.DLL';
  WT_EXECUTEINPERSISTENTTHREAD = $00000080;
  CR_SUCCESS                  = $00000000;
  CM_GETIDLIST_FILTER_SERVICE = $00000002;

type
  DEVINST = DWORD;
  DEVINSTID = PChar;
  RETURN_TYPE = DWORD;
  CONFIGRET = RETURN_TYPE;
  TThreadStartFunc = Function (Event:THandle):DWORD; Stdcall;

function QueueUserWorkItem (func: TThreadStartFunc; Context: Pointer; Flags: DWORD): BOOL; stdcall; external kernel32;
function CM_Locate_DevNode(var dnDevInst: DEVINST; pDeviceID: DEVINSTID; ulFlags: ULONG): CONFIGRET; stdcall; external CfgMgrDllName name 'CM_Locate_DevNodeW';
function CM_Reenumerate_DevNode(var dnDevInst: DEVINST; ulFlags: ULONG): CONFIGRET; stdcall; external CfgMgrDllName;
function CM_Get_Device_ID_List(const pszFilter: PChar; Buffer: PChar; BufferLen: ULONG; ulFlags: ULONG): CONFIGRET; stdcall; External CfgMgrDllName name 'CM_Get_Device_ID_ListW';
function CM_Get_Device_ID_List_Size(var ulLen: ULONG; const pszFilter: PChar; ulFlags: ULONG): CONFIGRET; stdcall; External CfgMgrDllName name 'CM_Get_Device_ID_List_SizeW';

Function ImScsiScanForHardwareChanges(rootid:DEVINSTID = Nil; flags:DWORD = 0):DWORD;
Var
  dev_inst: DEVINST;
  status: DWORD;
begin
  status := CM_Locate_DevNode(dev_inst, rootid, 0);
  if status <> CR_SUCCESS then
  begin
    DebugLog('Error scanning for hardware changes: $' + IntToHex(status,8),EVENTLOG_ERROR_TYPE);
    Result:=status;
  end
  else Result:=CM_Reenumerate_DevNode(dev_inst, flags);
end;

Function ImScsiScanForHardwareChangesThread(Event:THandle):DWORD; Stdcall;
begin
  ImScsiScanForHardwareChanges;
  SetEvent(Event);
  Result:=0;
end;

function ImScsiAllocateDeviceInstanceListForService(service:string;var instances:PChar):Integer;
var
  length,status:DWORD;
Begin
  length:=0;
  Result:=0;
  status := CM_Get_Device_ID_List_Size(length, PChar(service), CM_GETIDLIST_FILTER_SERVICE);
  if status = CR_SUCCESS then
  begin
    instances := AllocMem(sizeof(Char) * length);
    if Not Assigned(instances) then Exit;
    status := CM_Get_Device_ID_List(PChar(service), instances, length, CM_GETIDLIST_FILTER_SERVICE);
    if status <> CR_SUCCESS then
    begin
      FreeMem(instances);
      //ImScsiDebugMessage(L"Error enumerating instances for service %1!ws!: %2!#x!", service, status);
    End
    Else Result:=length;
  end;
end;

Function ImScsiRescanScsiAdapter:Boolean;
var
  i,length:Integer;
  hwinstances:PChar;
  status: DWORD;
Begin
  hwinstances := NIL;
  Result:=False;
  Try
    length:=ImScsiAllocateDeviceInstanceListForService('phdskmnt', hwinstances);
    if length <= 1 Then Exit;
    i:=0;
    while i < length do
    begin
      if hwinstances + i = '' Then Continue;
      status := ImScsiScanForHardwareChanges(hwinstances + i, 0);
      if status = CR_SUCCESS then Result:=True
      else
      begin
        // ImScsiDebugMessage(L"Rescanning of %1 failed: %2!#x!", hwinstances, status);
      end;
      Inc(i,1 + StrLen(hwinstances + i));
    end;
  Finally
    if Assigned(hwinstances) then
      FreeMem(hwinstances);
  end;
end;

Function ImScsiRescanScsiAdapterThread(Event:THandle):DWORD; Stdcall;
begin
  ImScsiRescanScsiAdapter;
  SetEvent(Event);
  Result:=0;
end;

Function ImScsiRescanScsiAdapterAsync(AsyncFlag:Boolean):THandle;
begin
  Result := CreateEvent(NIL, TRUE, FALSE, NIL);
  if Result <> 0 then
  begin
    if AsyncFlag then
    begin
      if Not QueueUserWorkItem(ImScsiRescanScsiAdapterThread, Pointer(Result), WT_EXECUTEINPERSISTENTTHREAD) then
      begin
        CloseHandle(Result);
        Result:=0;
      end;
    end
    else ImScsiRescanScsiAdapterThread(Result);
  end;
end;

end.