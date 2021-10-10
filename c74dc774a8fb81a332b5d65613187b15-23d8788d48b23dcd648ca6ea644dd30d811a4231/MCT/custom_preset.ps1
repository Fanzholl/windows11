 $PRESET = 'Auto Setup'; $OPTIONS = '/Action CreateUpgradeMedia /Pkey Defer /Selfhost /Compat IgnoreWarning /MigrateDrivers All /ResizeRecoveryPartition Disable /ShowOOBE None /Telemetry Disable /CompactOS Disable /DynamicUpdate Enable /UpdateMedia Decline  /SkipSummary /Eula Accept'
 $VER = 22000; $EDITION = ''; $OS_EDITION = 'CoreSingleLanguage'; $OS_PRODUCT = 'Windows 10 Home Single Language'
 $VID = '11'; $XI = '11'; $11 = $XI -eq '11'; $AUTO = '1' -ne ''; $OEM = '' -eq ''
 $host.ui.rawui.windowtitle = $PRESET; $ROOT = 'D:\Torrent\c74dc774a8fb81a332b5d65613187b15-23d8788d48b23dcd648ca6ea644dd30d811a4231'; $hide = '1'; 
 cd -Lit($ROOT+'\MCT'); $DRIVE = [environment]::SystemDirectory[0]; $WIM = $DRIVE + ':\$WINDOWS.~WS'; $ESD = $DRIVE + ':\ESD'
 if ('Create USB' -eq $PRESET) { $DIR = $WIM + '\Sources\Windows' } else { $DIR = $ESD + '\Windows' } ; $env:DIR = $DIR
 cmd "/d/x/c rmdir /s/q $DIR >nul 2>nul"
#:: workaround for version 1703 and earlier not having media selection switches
 $CV = '"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion"'
 if ($VER -le 15063 -and $EDITION -ne '') {
   $null = reg add $CV /v EditionID /d $EDITION /f /reg:32; $null = reg delete $CV /v ProductName /f /reg:32
   $null = reg add $CV /v EditionID /d $EDITION /f /reg:64; $null = reg delete $CV /v ProductName /f /reg:64
 }
 function MCTCompatUndo { if ($VER -le 15063 -and $EDITION -ne '') {
   $null = reg add $CV /v EditionID /d $OS_EDITION /f /reg:32; $null = reg add $CV /v ProductName /d $OS_PRODUCT /f /reg:32
   $null = reg add $CV /v EditionID /d $OS_EDITION /f /reg:64; $null = reg add $CV /v ProductName /d $OS_PRODUCT /f /reg:64
 }}
#:: setup file watcher to minimally track progress internally
 function Watcher {
   $A = $args; $null = mkdir $A[1] -force -ea 0; $path = (gi -force -lit $A[1] -ea 0).FullName; $ret = $true
   $W = new-object IO.FileSystemWatcher; $W.Path = $path; $W.Filter = $A[2]
   $W.IncludeSubdirectories = $true; $W.NotifyFilter = 125; $W.EnableRaisingEvents = $true
   while ($true) {
     try { $found = $W.WaitForChanged(15, 15000) } catch { $null = mkdir $A[1] -ea 0; continue }
     if ($found.TimedOut -eq $false) { $found | Out-Default; $ret = $false; break } else { if ($A[0].HasExited) {break} ; $A[2] }
   } ; $W.Dispose(); return $ret
 }
#:: OEM files
 function OEMFiles {
   pushd -lit $ROOT
   foreach ($P in "$DIR\x86\sources","$DIR\x64\sources","$DIR\sources") {
     if (!$OEM -or !(test-path "$P\setupprep.exe")) {continue}
     if (test-path '$OEM$') {xcopy /CYBERHIQ '$OEM$' $($P+'\$OEM$')}
     if (test-path "MCT\PID.txt") {copy -path "MCT\PID.txt" -dest $P -force}
     if (test-path "MCT\auto.cmd") {copy -path "MCT\auto.cmd" -dest $DIR -force}
   }
   popd
 }
#:: Skip TPM Check on Dynamic Update v2 - also available as standalone toggle script in the MCT subfolder
 if ($11) {
   $C = "cmd /q $N (c) AveYo, 2021 /d/x/r>nul (erase /f/s/q %systemdrive%\`$windows.~bt\appraiserres.dll"
   $C+= '&md 11&cd 11&ren vd.exe vdsldr.exe&robocopy "../" "./" "vdsldr.exe"&ren vdsldr.exe vd.exe&start vd -Embedding)&rem;'
   $K = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\vdsldr.exe'
   $0 = ni $K -force -ea 0; sp $K Debugger $C -force
   $0 = sp 'HKLM:\SYSTEM\Setup\MoSetup' 'AllowUpgradesWithUnsupportedTPMOrCPU' 1 -type dword -force -ea 0
 }
#:: MCT custom preset processing
 switch ($PRESET) {
   'Auto Setup' {
    #:: pasively wait MCT to author sources, then add $OEM$, PID.txt, auto.cmd (disable with NO_OEM) and launch auto.cmd setuprep
     $MCT = start -wait "MediaCreationTool$VID.exe" $OPTIONS; if (-not (test-path $DIR)) {break}
     OEMFiles; MCTCompatUndo; start -win $hide -wait cmd '/d/x/rcall auto.cmd %DIR%'
     break
   }
   'Create ISO' {
    #:: pasively wait MCT to author sources, then add $OEM$, PID.txt, auto.cmd (disable with NO_OEM) and Skip TPM check (if 11)
     $MCT = start -wait "MediaCreationTool$VID.exe" $OPTIONS; if (-not (test-path $DIR)) {break}
     OEMFiles; if ($11) {start -win $hide -wait cmd '/d/x/rcall Skip_TPM_Check_on_Media_Boot.cmd %DIR%'}
     break
   }
   'Create USB' {
   #:: just pass options and quit straightway if NO_OEM parameter used to skip adding $OEM$, pid.txt, auto.cmd to media
     if (-not $OEM) { $MCT = start "MediaCreationTool$VID.exe" $OPTIONS; break }
   #:: otherwise watch setup files from the sideline (MCT has authoring control from start to finish, locking file handles)
     $MCT = start -passthru "MediaCreationTool$VID.exe" $OPTIONS; if ($null -eq $MCT) {break} ; sleep 7
     Watcher $MCT $ESD "*.esd"; if ($MCT.HasExited) {break}; Watcher $MCT $WIM "*.wim"; if ($MCT.HasExited) {break}
   #:: then add $OEM$, PID.txt, auto.cmd (disable with NO_OEM)
     OEMFiles; if (-not $11) {break} ; Watcher $MCT $WIM "ws.dat"; if ($MCT.HasExited) {break}
   #:: if 11, suspend setuphost after boot.wim creation to apply Skip TPM Check on Media Boot
     $M=[AppDomain]::CurrentDomain."DefineDynami`cAssembly"(1,1)."DefineDynami`cModule"(1)
     $D=$M."Defin`eType"("A",1179913,[ValueType]); $n="DebugActiveProcess","DebugActiveProcessStop",[int],[int];
     0..1|% {$null=$D."DefinePInvok`eMethod"($n[$_],"kernel`32",8214,1,[int],$n[$_+2],1,4)}
     $T=$D."Creat`eType"(); function DP {$T."G`etMethod"($args[0]).invoke(0,$args[1])}
     $s=ps "SetupHost" -ea 0; if ($null -ne $s) {DP DebugActiveProcess $s.Id; sleep -m 300}
     $s=ps "SetupHost" -ea 0; if ($null -ne $s) {DP DebugActiveProcess $s.Id; sleep -m 600}
   #:: mount boot.wim and generate registry overrides via winpeshl.ini file (cleaner than altering system hive directly)
     if ($null -ne $s) {start -win $hide -wait cmd '/d/x/rcall Skip_TPM_Check_on_Media_Boot.cmd %DIR%'}
   #:: and finally, resume setuphost
     $s=ps "SetupHost" -ea 0; if ($null -ne $s) {DP DebugActiveProcessStop $s.Id; sleep -m 300}
     $s=ps "SetupHost" -ea 0; if ($null -ne $s) {DP DebugActiveProcessStop $s.Id; sleep -m 300}
   }
 }
#:: undo workaround for version 1703 and earlier not having media selection switches
 MCTCompatUndo
#,#