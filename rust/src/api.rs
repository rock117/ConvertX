use flutter_rust_bridge::frb;

/// File type enum
#[frb]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum FileType {
    Image,
    Document,
    Audio,
    Video,
    Config,
}

/// Convert options
#[frb]
#[derive(Debug, Clone)]
pub struct ConvertOptions {
    /// Output format (e.g., "png", "jpg", "pdf", "mp4")
    pub output_format: String,
    /// Quality (0-100, for image/video compression)
    pub quality: Option<i32>,
    /// Width (for image/video resizing)
    pub width: Option<i32>,
    /// Height (for image/video resizing)
    pub height: Option<i32>,
    /// FFmpeg executable path (if provided by Dart side)
    pub ffmpeg_path: Option<String>,
}

/// Conversion result
#[frb]
#[derive(Debug, Clone)]
pub struct ConvertResult {
    /// Whether the conversion was successful
    pub success: bool,
    /// Output file path
    pub output_path: Option<String>,
    /// Error message
    pub error: Option<String>,
}

/// Conversion progress
#[frb]
#[derive(Debug, Clone)]
pub struct ConvertProgress {
    /// Task ID
    pub task_id: String,
    /// Progress percentage (0-100)
    pub progress: i32,
    /// Current status
    pub status: String,
}

/// Detect file type
#[frb]
pub fn detect_file_type(file_path: String) -> Option<FileType> {
    let ext = std::path::Path::new(&file_path)
        .extension()?
        .to_str()?
        .to_lowercase();

    match ext.as_str() {
        "png" | "jpg" | "jpeg" | "webp" | "bmp" | "ico" | "svg" | "gif" => Some(FileType::Image),
        "pdf" | "md" | "markdown" | "html" | "htm" | "txt" | "doc" | "docx" | "ppt" | "pptx"
        | "epub" => Some(FileType::Document),
        "mp3" | "wav" | "flac" | "aac" | "ogg" | "m4a" => Some(FileType::Audio),
        "mp4" | "avi" | "mkv" | "mov" | "webm" | "flv" => Some(FileType::Video),
        "yaml" | "yml" | "properties" | "json" => Some(FileType::Config),
        _ => None,
    }
}

/// Get supported output formats
#[frb]
pub fn get_supported_output_formats(file_type: FileType) -> Vec<String> {
    match file_type {
        FileType::Image => vec![
            "png".to_string(),
            "jpg".to_string(),
            "jpeg".to_string(),
            "webp".to_string(),
            "bmp".to_string(),
            "ico".to_string(),
            "gif".to_string(),
        ],
        FileType::Document => vec![
            "html".to_string(),
            "txt".to_string(),
            // PDF is only supported for certain inputs (e.g., EPUB) via external tools.
            "pdf".to_string(),
        ],
        FileType::Audio => vec![
            "mp3".to_string(),
            "wav".to_string(),
            "flac".to_string(),
            "aac".to_string(),
            "ogg".to_string(),
        ],
        FileType::Video => vec![
            "mp4".to_string(),
            "avi".to_string(),
            "mkv".to_string(),
            "webm".to_string(),
        ],
        FileType::Config => vec![
            "yaml".to_string(),
            "yml".to_string(),
            "properties".to_string(),
            "json".to_string(),
        ],
    }
}

/// Get supported output formats for a specific file (based on extension/type)
///
/// Note: This is stricter than `get_supported_output_formats(FileType)` to avoid showing invalid options in the UI.
#[frb]
pub fn get_supported_output_formats_for_file(file_path: String) -> Vec<String> {
    let ext = std::path::Path::new(&file_path)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();

    match ext.as_str() {
        // Images
        "png" | "jpg" | "jpeg" | "webp" | "bmp" | "ico" | "svg" | "gif" => {
            get_supported_output_formats(FileType::Image)
        }

        // Markdown -> (html/txt/docx/pptx/pdf)
        "md" | "markdown" => vec![
            "html".to_string(),
            "txt".to_string(),
            "docx".to_string(),
            "pptx".to_string(),
            "pdf".to_string(),
        ],

        // Documents: plain-text-ish -> html/txt
        "html" | "htm" | "txt" => vec!["html".to_string(), "txt".to_string()],

        // Office -> Markdown (via pandoc)
        "docx" | "pptx" => vec!["md".to_string()],

        // Documents: epub -> pdf (requires external tools)
        "epub" => vec!["pdf".to_string()],

        // PDF input (conversion not implemented)
        "pdf" => vec![],

        // Audio: not implemented yet
        "mp3" | "wav" | "flac" | "aac" | "ogg" | "m4a" => vec![],

        // Video -> Audio (via FFmpeg)
        "mp4" | "avi" | "mkv" | "mov" | "webm" | "flv" => vec![
            "mp3".to_string(),
            "wav".to_string(),
            "aac".to_string(),
            "flac".to_string(),
        ],

        // Config files: YAML <-> Properties, YAML <-> JSON, Properties <-> JSON
        "yaml" | "yml" => vec!["properties".to_string(), "json".to_string()],
        "properties" => vec!["yaml".to_string(), "yml".to_string(), "json".to_string()],
        "json" => vec![
            "yaml".to_string(),
            "yml".to_string(),
            "properties".to_string(),
        ],

        _ => vec![],
    }
}

/// Convert single file
#[frb]
pub fn convert_file(
    input_path: String,
    output_dir: String,
    options: ConvertOptions,
) -> ConvertResult {
    crate::converters::convert_single(&input_path, &output_dir, &options)
}

/// Batch convert files
#[frb]
pub fn convert_files(
    input_paths: Vec<String>,
    output_dir: String,
    options: ConvertOptions,
) -> Vec<ConvertResult> {
    input_paths
        .iter()
        .map(|path| crate::converters::convert_single(path, &output_dir, &options))
        .collect()
}

/// Open folder
#[frb]
pub fn open_folder(folder_path: String) -> bool {
    #[cfg(target_os = "windows")]
    {
        std::process::Command::new("explorer")
            .arg(&folder_path)
            .spawn()
            .is_ok()
    }
    #[cfg(target_os = "macos")]
    {
        std::process::Command::new("open")
            .arg(&folder_path)
            .spawn()
            .is_ok()
    }
    #[cfg(target_os = "linux")]
    {
        std::process::Command::new("xdg-open")
            .arg(&folder_path)
            .spawn()
            .is_ok()
    }
    #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
    {
        false
    }
}
