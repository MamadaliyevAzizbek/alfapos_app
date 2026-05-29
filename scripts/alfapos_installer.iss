; AlfaPOS Windows o'rnatuvchi (Inno Setup 6)
; Build: scripts\build_windows_installer.ps1 yoki GitHub Actions

#ifndef MyAppVersion
  #define MyAppVersion "1.0.13"
#endif

#define MyAppName "AlfaPOS"
#define MyAppPublisher "AlfaPOS"
#define MyAppExeName "alfapos_app.exe"
#define MyReleaseDir "..\build\windows\x64\runner\Release"
#define MyOutputDir "..\release\alfapos-windows-release"

[Setup]
AppId={{A7B3C4D5-E6F7-4890-ABCD-EF1234567890}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#MyOutputDir}
OutputBaseFilename=alfapos_app-windows-x64-setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
MinVersion=10.0
CloseApplications=force
ChangesAssociations=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Ish stolida yorliq yaratish"; GroupDescription: "Qo'shimcha:"
Name: "firewall"; Description: "Windows Firewall: AlfaPOS uchun tarmoq ruxsati (tavsiya)"; GroupDescription: "Qo'shimcha:"; Flags: checkedonce

[Files]
; Release papkasidagi HAMMA fayl (exe, dll, data\, va h.k.)
Source: "{#MyReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\release\WINDOWS_OCHISH.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "install_firewall.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\windows\scripts\allow_alfapos_firewall.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\scripts\windows_raw_print.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{group}\O'rnatish bo'yicha qo'llanma"; Filename: "{app}\WINDOWS_OCHISH.txt"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; WorkingDir: "{app}"

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\install_firewall.ps1"""; StatusMsg: "Firewall sozlanmoqda..."; Flags: runhidden waituntilterminated; Tasks: firewall
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent unchecked; WorkingDir: "{app}"

[UninstallDelete]
Type: filesandordirs; Name: "{app}\data"

[Code]
function InitializeSetup(): Boolean;
begin
  Result := True;
end;
