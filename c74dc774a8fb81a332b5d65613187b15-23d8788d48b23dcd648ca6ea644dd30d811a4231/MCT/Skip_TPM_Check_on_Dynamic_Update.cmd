@(set "0=%~f0"^)#) & powershell -nop -c iex([io.file]::ReadAllText($env:0)) & exit/b
#:: double-click to run or just copy-paste into powershell - it's a standalone hybrid script
#:: v2 using ifeo instead of wmi - increased compatibility at the cost of showing a cmd briefly on diskmgmt 

$_Paste_in_Powershell = {
  $N = 'Skip TPM Check on Dynamic Update'
  $B = gwmi -Class __FilterToConsumerBinding -Namespace 'root\subscription' -Filter "Filter = ""__eventfilter.name='$N'""" -ea 0
  $C = gwmi -Class CommandLineEventConsumer -Namespace 'root\subscription' -Filter "Name='$N'" -ea 0
  $F = gwmi -Class __EventFilter -NameSpace 'root\subscription' -Filter "Name='$N'" -ea 0
  if ($B) { $B | rwmi } ; if ($C) { $C | rwmi } ; if ($F) { $F | rwmi }
  $C = "cmd /q $N (c) AveYo, 2021 /d/x/r>nul (erase /f/s/q %systemdrive%\`$windows.~bt\appraiserres.dll"
  $C+= '&md 11&cd 11&ren vd.exe vdsldr.exe&robocopy "../" "./" "vdsldr.exe"&ren vdsldr.exe vd.exe&start vd -Embedding)&rem;'
  $K = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\vdsldr.exe'
  if (test-path $K) {ri $K -force -ea 0; write-host -fore 0xf -back 0xd "`n $N [REMOVED] run again to install "; timeout /t 5}
  else {$0=ni $K; sp $K Debugger $C -force; write-host -fore 0xf -back 0x2 "`n $N [INSTALLED] run again to remove ";timeout /t 5}
  $0 = sp HKLM:\SYSTEM\Setup\MoSetup 'AllowUpgradesWithUnsupportedTPMOrCPU' 1 -type dword -force -ea 0
} ; start -verb runas powershell -args "-nop -c & {`n`n$($_Paste_in_Powershell-replace'"','\"')}"
$_Press_Enter
#,#