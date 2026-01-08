; Inno Setup Script for Zuwad Academy
; Created for easy Windows installer generation

#define MyAppName "Zuwad Academy"
#define MyAppVersion "1.0.1"
#define MyAppPublisher "Zuwad"
#define MyAppURL "https://zuwad.academy"
#define MyAppExeName "zuwad.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
AppId={{B8E5F2A1-3C7D-4E9F-A2B1-5D8C6E4F7A3B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; Output settings - installer will be created in the same folder as this script
OutputDir=.
OutputBaseFilename=ZuwadSetup
; Use the app icon for the installer
SetupIconFile=..\windows\runner\resources\app_icon.ico
; Compression settings
Compression=lzma
SolidCompression=yes
; Windows Vista and later
MinVersion=6.1
; Privileges - use lowest to not require admin (installs to user folder)
; Change to "admin" if you want to install to Program Files for all users
PrivilegesRequired=lowest
; Uninstaller settings
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
; Visual settings
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; Main application files from Release build
Source: "..\build\windows\x64\runner\Release\zuwad.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
; Start menu shortcut
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
; Desktop shortcut
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
; Start menu uninstall shortcut
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

[Run]
; Run app after installation (user can uncheck this option)
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean up any cached data during uninstall (optional)
Type: filesandordirs; Name: "{localappdata}\{#MyAppName}"
