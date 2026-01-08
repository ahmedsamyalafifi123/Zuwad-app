# Zuwad Installer

This folder contains the Windows installer configuration for Zuwad Academy.

## Files

- `zuwad_setup.iss` - Inno Setup script
- `build_installer.bat` - Automated build script

## How to Build the Installer

### Option 1: Using Inno Setup GUI (Recommended for first time)

1. Open Inno Setup Compiler
2. Click **File → Open** and select `zuwad_setup.iss`
3. Click **Build → Compile** (or press F9)
4. The installer `ZuwadSetup.exe` will be created in this folder

### Option 2: Using Command Line

1. Add Inno Setup to your PATH if not already:

   ```
   setx PATH "%PATH%;C:\Program Files (x86)\Inno Setup 6"
   ```

2. Run from this folder:
   ```
   iscc zuwad_setup.iss
   ```

### Option 3: Automated Build Script

Run `build_installer.bat` - it will:

1. Build Flutter Windows release
2. Compile the installer

## Features

The installer includes:

- ✅ Desktop shortcut (checked by default)
- ✅ Start menu shortcuts
- ✅ Run app after installation option
- ✅ Uninstaller in Add/Remove Programs
- ✅ Arabic and English language support
- ✅ Modern wizard style
