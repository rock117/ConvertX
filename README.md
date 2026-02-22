# ConvertX

> A desktop file converter built with **Flutter + Rust**.

[![status](https://img.shields.io/badge/status-active%20development-orange)](./README.md)
[![platform](https://img.shields.io/badge/platform-Windows-blue)](./README.md)
[![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

> [!WARNING]
> **Work in Progress**
>
> This project is under active development. Features and APIs may change.
> Not recommended for production use yet. Feedback and issues are welcome.

## Table of Contents

- [Overview](#overview)
- [Features & Supported Formats](#features--supported-formats)
- [Tech Stack](#tech-stack)
- [Quick Start](#quick-start)
- [EPUB -> PDF Dependencies](#epub---pdf-dependencies)
- [Project Structure](#project-structure)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

## Overview

ConvertX is a desktop file conversion tool:

- A modern desktop UI built with Flutter
- High-performance conversion engine built with Rust
- Type-safe FFI integration via `flutter_rust_bridge`

Current focus areas:

- Image conversion
- Text/document conversion
- EPUB -> PDF (via external tools)
- Clear conversion progress and error feedback

## Features & Supported Formats

### Implemented

| Category | Input Formats | Output Formats | Notes |
|---|---|---|---|
| Image | `png/jpg/jpeg/webp/bmp/ico/gif` | `png/jpg/jpeg/webp/bmp/ico/gif` | Basic image conversion |
| Text Document | `txt/md/html/htm` | `txt/html` | Plain text and markup conversion |
| Ebook | `epub` | `pdf` | Requires `pandoc` or `ebook-convert` |

### Planned

- [ ] Generic document -> PDF (currently only `epub -> pdf`)
- [ ] Audio/video conversion (planned with FFmpeg)
- [ ] PDF input parsing/conversion
- [ ] More batch processing and advanced options

### UI Behavior

- Output formats are filtered dynamically based on selected input files
- In-progress tasks clearly show `Converting...`
- Long-running jobs (like EPUB -> PDF) show external-tool stage hints
- Failed tasks support detailed error viewing

## Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Rust
- **Bridge**: flutter_rust_bridge

## Quick Start

### 1) Prerequisites (Windows)

1. Install Flutter SDK: <https://docs.flutter.dev/get-started/install/windows>
2. Install Rust: <https://www.rust-lang.org/tools/install>
3. Install Visual Studio with the **Desktop development with C++** workload

Verify installation:

```powershell
flutter doctor
rustc --version
cargo --version
```

### 2) Clone and Run

```powershell
git clone <your-repo-url>
cd ConvertX

# Initialize Flutter platform files (first time only)
flutter create . --platforms=windows

# Install dependencies
flutter pub get

# Build Rust backend
cd rust
cargo build --release
cd ..

# Run app
flutter run -d windows
```

## EPUB -> PDF Dependencies

`epub -> pdf` requires one of the following external tools:

- `pandoc`
- `calibre` (provides `ebook-convert`)

### Verify Installation

```powershell
pandoc --version
ebook-convert --version
```

### Windows Installation (choose one or both)

```powershell
winget install Pandoc
```

```powershell
winget install calibre.calibre
```

## Project Structure

```text
ConvertX/
├── lib/                    # Flutter frontend
│   ├── main.dart           # App entry
│   └── src/
│       ├── screens/        # Screens
│       ├── widgets/        # UI components
│       ├── providers/      # State management
│       └── rust/           # Generated Rust bindings
├── rust/                   # Rust backend
│   ├── src/
│   │   ├── api.rs          # FFI API
│   │   └── converters/     # Conversion logic
│   └── Cargo.toml
└── pubspec.yaml
```

## Roadmap

- [x] Base project structure
- [x] Image and document conversion
- [x] EPUB -> PDF via external tools
- [x] Progress and error feedback improvements
- [ ] Full flutter_rust_bridge workflow docs
- [ ] Audio/video conversion (FFmpeg)
- [ ] Automated testing and release pipeline

## Contributing

Contributions are welcome:

1. Fork the repository
2. Create a branch: `feat/xxx` or `fix/xxx`
3. Commit your changes and open a Pull Request
4. In your PR, describe purpose, scope, and test results

If you find a bug, please open an Issue with minimal reproduction steps.

## License

MIT
