; AlfaPOS Windows o'rnatuvchi (Inno Setup 6)
; Build: scripts\build_windows_installer.ps1 yoki GitHub Actions
; VC++: avval scripts\download_vcredist.ps1

#ifndef MyAppVersion
  #define MyAppVersion "1.0.15"
#endif

#define MyAppName "AlfaPOS"
#define MyAppPublisher "AlfaPOS"
#define MyAppExeName "alfapos_app.exe"
#define MyReleaseDir "..\build\windows\x64\runner\Release"
#define MyOutputDir "..\release\alfapos-windows-release"

[Setup]
SetupIconFile=..\windows\runner\resources\app_icon.ico
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
; VC++ Redistributable va firewall uchun admin kerak
PrivilegesRequired=admin
MinVersion=10.0
CloseApplications=force
ChangesAssociations=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Ish stolida yorliq yaratish"; GroupDescription: "Qo'shimcha:"
Name: "firewall"; Description: "Windows Firewall: internet + telefon Mobil relay (TCP 9100) ruxsati — tavsiya"; GroupDescription: "Qo'shimcha:"; Flags: checkedonce

[Files]
; Release papkasidagi HAMMA fayl (exe, dll, data\, va h.k.)
Source: "{#MyReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\release\WINDOWS_OCHISH.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "install_firewall.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\windows\scripts\allow_alfapos_firewall.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\scripts\windows_raw_print.ps1"; DestDir: "{app}"; Flags: ignoreversion
; Microsoft Visual C++ 2015–2022 (x64) — o'rnatish vaqtida jim o'rnatiladi
Source: "vcredist\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

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
function VCRedistInstalled: Boolean;
var
  Installed: Cardinal;
begin
  { VC++ 2015–2022 x64 (Flutter / MSVC runtime) }
  Result := RegQueryDWordValue(HKLM64,
    'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
    'Installed', Installed) and (Installed = 1);
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep <> ssPostInstall then
    Exit;
  if VCRedistInstalled then
  begin
    Log('VC++ Redistributable allaqachon o''rnatilgan — o''tkazib yuborildi');
    Exit;
  end;

  WizardForm.StatusLabel.Caption := 'Microsoft Visual C++ Redistributable o''rnatilmoqda...';
  WizardForm.StatusLabel.Update;
  if not Exec(
    ExpandConstant('{tmp}\vc_redist.x64.exe'),
    '/install /quiet /norestart',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Log('VC++ Redistributable ishga tushmadi');
    MsgBox(
      'Visual C++ Redistributable avtomatik o''rnatilmadi.'#13#10 +
      'AlfaPOS ochilmasa, Microsoft saytidan «VC++ 2015-2022 x64» ni qo''lda o''rnating.',
      mbInformation, MB_OK);
    Exit;
  end;

  { 0 = OK, 1638 = allaqachon bor, 3010 = OK lekin reboot }
  if (ResultCode <> 0) and (ResultCode <> 1638) and (ResultCode <> 3010) then
  begin
    Log('VC++ Redistributable exit code: ' + IntToStr(ResultCode));
    MsgBox(
      'Visual C++ Redistributable o''rnatish kodi: ' + IntToStr(ResultCode) + #13#10 +
      'AlfaPOS ishlamasa, VC++ 2015-2022 x64 ni qo''lda o''rnating.',
      mbInformation, MB_OK);
  end
  else
    Log('VC++ Redistributable o''rnatildi (kod ' + IntToStr(ResultCode) + ')');
end;
