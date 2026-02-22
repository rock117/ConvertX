# ConvertX

A powerful desktop file converter built with Flutter and Rust.

## 功能特性

- **图片转换**: PNG, JPG, WebP, BMP, ICO, GIF
- **文档转换**: PDF, Markdown, HTML, TXT
- **音频转换**: MP3, WAV, FLAC, AAC, OGG
- **视频转换**: MP4, AVI, MKV, WebM

## 技术栈

- **前端**: Flutter (Dart) - 跨平台 UI
- **后端**: Rust - 高性能文件处理
- **桥接**: flutter_rust_bridge - 类型安全 FFI

## 快速开始

### 前置条件

1. **Flutter SDK**: https://docs.flutter.dev/get-started/install/windows
   ```powershell
   # 下载后解压，添加到 PATH 环境变量
   flutter doctor
   ```
2. **Rust**: 已安装 ✓ (1.93.0)
3. **Visual Studio**: 安装 C++ 桌面开发工作负载

### 初始化步骤

```powershell
cd c:\rock\coding\code\my\MyApp\ConvertX

# 1. 初始化 Flutter 平台文件（需要先安装 Flutter）
flutter create . --platforms=windows

# 2. 安装依赖
flutter pub get

# 3. 构建 Rust 库
cd rust && cargo build --release && cd ..

# 4. 运行应用
flutter run -d windows
```

## 项目结构

```
ConvertX/
├── lib/                    # Flutter 前端
│   ├── main.dart           # 应用入口
│   └── src/
│       ├── screens/        # 页面
│       ├── widgets/        # UI 组件
│       ├── providers/      # 状态管理
│       └── rust/           # Rust 桥接
├── rust/                   # Rust 后端
│   ├── src/
│   │   ├── api.rs          # FFI 接口
│   │   └── converters/     # 转换模块
│   └── Cargo.toml
└── pubspec.yaml
```

## 开发进度

- [x] 项目结构创建
- [x] Rust 转换引擎（图片/文档）
- [x] Flutter UI 界面
- [ ] flutter_rust_bridge 集成
- [ ] 音视频转换（FFmpeg）
- [ ] 测试和打包

## License

MIT
