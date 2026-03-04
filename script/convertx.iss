#define MyAppName "ConvertX"
#define MyAppVersion "0.0.0"
#define MyPublisher ""
#define MySourceDir ""
#define MyOutputDir ""

[Setup]
AppId={{A5E6E2D2-8A06-4C3A-9D85-8D2D36B4E2D1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir={#MyOutputDir}
OutputBaseFilename={#MyAppName}-Setup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\convertx.exe"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\convertx.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\convertx.exe"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
