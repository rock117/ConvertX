# build portable exe zip

cargo build --release --manifest-path .\rust\Cargo.toml
powershell -ExecutionPolicy Bypass -File .\script\build_windows_portable_zip.ps1 -SkipFlutterBuild
