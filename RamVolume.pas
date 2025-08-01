unit RamVolume;

interface

uses Windows,Definitions;

function GetRamDiskLetter(device:TDeviceNumber;portNumber:Cardinal;Var existing:TRamDisk): Char;
Function ImScsiOpenDiskByDeviceNumber(DeviceNumber: TDeviceNumber; PortNumber: DWORD; var DiskNumber: Integer):THandle;

implementation

uses Classes,StrUtils,SysUtils;

Function ImScsiOpenDiskByDeviceNumber(DeviceNumber: TDeviceNumber; PortNumber: DWORD; var DiskNumber: Integer):THandle;
Const
  disk_prefix = 'PhysicalDrive';
var
  dosdevs: TArray<Char>;
  disk, adapter: THandle;
  disk_number: Integer;
  dw: DWORD;
  dev_path: string;
  config:TScsiDeviceConfig;
  i, len: Integer;
  devices: TStringList;
  address: TScsiAddress;
  device_number: TStorageDeviceNumber;
  disk_size: Int64;
Begin
  SetLength(dosDevs, MAX_DOS_NAMES);
  disk_number:= -1;
  Result:=INVALID_HANDLE_VALUE;
  len:=QueryDosDevice(NIL, dosdevs, Length(dosdevs));
  if len=0 then Exit;

  adapter := ImScsiOpenScsiAdapterByScsiPortNumber(PortNumber);
  if adapter = INVALID_HANDLE_VALUE then Exit;
  try
    config.DeviceNumber := DeviceNumber;
    If not ImScsiQueryDevice(adapter, @config, SizeOf(TScsiDeviceConfig)) Then
    begin
      Exit;
    end;
  finally
    CloseHandle(adapter);
  end;

  devices:=TStringList.Create;
  try
    devices.Text := String(dosdevs);
    for i:=0 to devices.Count-1 do
    Begin
      if not devices[i].StartsWith(disk_prefix) Then Continue;
      if not TryStrToInt(Copy(devices[i],Length(disk_prefix)+1,10), disk_number) then continue;
      dev_path := '\\?\' + devices[i];
      disk := CreateFile(PChar(dev_path), GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, NIL, OPEN_EXISTING, 0, 0);
      if disk = INVALID_HANDLE_VALUE then Continue;
      try
        if DeviceIoControl(disk, IOCTL_SCSI_GET_ADDRESS, NIL, 0, @address, sizeof(address), dw, NIL) then
        Begin
          if ((address.PortNumber = PortNumber) and
            (address.PathId = DeviceNumber.PathId) and
            (address.TargetId = DeviceNumber.TargetId) and
            (address.Lun = DeviceNumber.Lun)) then
          Begin
            if DeviceIoControl(disk, IOCTL_STORAGE_GET_DEVICE_NUMBER, NIL, 0, @device_number, sizeof(device_number), dw, NIL) then
            Begin
              if ((device_number.DeviceNumber = DWORD(disk_number)) and
                (device_number.DeviceType = FILE_DEVICE_DISK) and
                (device_number.PartitionNumber = 0)) then
              Begin
                DeviceIoControl(disk, FSCTL_ALLOW_EXTENDED_DASD_IO, NIL, 0, NIL, 0, dw, NIL);
                disk_size := 0;
                if DeviceIoControl(disk, IOCTL_DISK_GET_LENGTH_INFO, NIL, 0, @disk_size, sizeof(disk_size), dw, NIL) then
                begin
                  if disk_size = config.DiskSize then
                  Begin
                    DiskNumber := disk_number;
                    Result:=disk;
                    Exit;
                  end;
                end
              end;
            end;
          end;
        end
        else
        Case GetLastError of
          ERROR_INVALID_PARAMETER,
          ERROR_INVALID_FUNCTION,
          ERROR_NOT_SUPPORTED,
          ERROR_IO_DEVICE: break;
        end;
      finally
        if Result <> disk then
          CloseHandle(disk);
      end;
    end;
  Finally
    devices.Free;
  end;
end;

Function GetRamDiskLetter(device:TDeviceNumber;portNumber:Cardinal;Var existing:TRamDisk):Char;
var
  adapter, volHandle, volume: THandle;
  tmp: DWORD;
  address: TScsiAddress;
  device_number: TStorageDeviceNumber;
  volumeName: Array[0..49] of Char;
  mountName: Array[0..250] Of Char;
Begin
  Result:=#0;
  adapter:= ImScsiOpenDiskByDeviceNumber(device, PortNumber, existing.diskNumber);
  if adapter <> INVALID_HANDLE_VALUE then
  try
    volume := FindFirstVolume(volumeName, Length(volumeName));
    if volume <> INVALID_HANDLE_VALUE then
    try
      repeat
        volumeName[48] := #0;
        volHandle:= CreateFile(volumeName, 0, FILE_SHARE_READ or FILE_SHARE_WRITE, NIL, OPEN_EXISTING, 0, 0);
        if volHandle = INVALID_HANDLE_VALUE then continue;
        try
          volumeName[48] := '\';

          if DeviceIoControl(volHandle, IOCTL_SCSI_GET_ADDRESS, NIL, 0, @address, sizeof(address), tmp, NIL) then
          Begin
            if ((address.PortNumber = portNumber) and
              (address.PathId = device.PathId) and
              (address.TargetId = device.TargetId) and
              (address.Lun = device.Lun)) then
            Begin
              if DeviceIoControl(volHandle, IOCTL_STORAGE_GET_DEVICE_NUMBER, NIL, 0, @device_number, sizeof(device_number), tmp, NIL) then
              Begin
                if (device_number.DeviceNumber = DWORD(existing.diskNumber)) and
                  (device_number.DeviceType = FILE_DEVICE_DISK) and
                  (device_number.PartitionNumber > 0) then
                Begin
                  if GetVolumePathNamesForVolumeName(volumeName, mountName, Length(mountName), tmp) then
                  begin
                    existing.volumeName:=String(volumeName);
                    Result:=mountName[0]; // mountName is array of ASCIIZ, ending with empty ASCIIZ
                    Break;
                  end;
                end;
              end;
            end;
          end;
        finally
          CloseHandle(volHandle);
        end;
      until not FindNextVolume(volume, volumeName, Length(volumeName));
    finally
      FindVolumeClose(volume);
    end;
  finally
    CloseHandle(adapter);
  end;
end;

end.