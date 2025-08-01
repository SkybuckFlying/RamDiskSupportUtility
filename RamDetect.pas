unit RamDetect;

interface

uses Windows, SysUtils, Definitions;

function GetRamDisk(var existing:TRamDisk): Boolean;

implementation

Uses RamVolume;

Function GetRamDisk(var existing:TRamDisk):Boolean;
var
  device: TDeviceNumber;
  address: TScsiAddress;
  adapter: THandle;
  config: TScsiDeviceConfig;
Begin
  Result:=False;
  // check for existing RAMdisk
  adapter := ImScsiOpenScsiAdapter(address.PortNumber);
  if adapter = INVALID_HANDLE_VALUE then
    Exit;
  try
    device.LongNumber := 0;
    config.DeviceNumber:=device;
    If not ImScsiQueryDevice(adapter, @config, SizeOf(TScsiDeviceConfig)) Then
    Begin
      // no such device
      Exit;
    end;
    existing.size:=config.DiskSize;
    // now enumerate disk volumes to find the drive letter
    existing.letter:=GetRamDiskLetter(device,address.PortNumber,existing);
    Result:=True;
  finally
    CloseHandle(adapter);
  end;
end;

end.