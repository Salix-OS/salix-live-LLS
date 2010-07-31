' Copyright: Cyrille Pontvieux <jrd@enialis.net>
' Licence: WTFPL
Dim args
Set args  = Wscript.Arguments
If args.count = 0 Then
  WScript.Echo "Error, you must pass the drive letter as argument" & VBNewLine _
    & "  Example: cscript letter2disk.vbs H:"
  WScript.Quit(1)
End If
If args(0) = "/?" Then
  WScript.Echo "  letter2disk.vbs drive_letter:" & VBNewLine & VBNewLine _
    & "If found, the result is in the form:" & VBNewLine _
    & "  disk_index:partition_index:disk_interface_type"
  WScript.Quit(0)
End If
letter = ucase(args(0))
Set wmiServices  = GetObject ("winmgmts:{impersonationLevel=Impersonate}!//.")
'Get physical disk drive
Set wmiDiskDrives =  wmiServices.ExecQuery ("SELECT Caption, DeviceID, Index, InterfaceType FROM Win32_DiskDrive")
For Each wmiDiskDrive In wmiDiskDrives
    'Find associated partition
    query = "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='" & wmiDiskDrive.DeviceID & "'} WHERE AssocClass = Win32_DiskDriveToDiskPartition"    
    Set wmiDiskPartitions = wmiServices.ExecQuery(query)
    For Each wmiDiskPartition In wmiDiskPartitions
        'Use partition device id to find logical disk
        Set wmiLogicalDisks = wmiServices.ExecQuery("ASSOCIATORS OF {Win32_DiskPartition.DeviceID='" & wmiDiskPartition.DeviceID & "'} WHERE AssocClass = Win32_LogicalDiskToPartition") 
        For Each wmiLogicalDisk In wmiLogicalDisks
            If wmiLogicalDisk.DeviceID = letter Then
              WScript.Echo wmiDiskDrive.Index _
                & ":" & wmiDiskPartition.Index _
                & ":" & wmiDiskDrive.InterfaceType
            End If
        Next      
    Next
Next
