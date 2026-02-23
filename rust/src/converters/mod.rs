pub mod config;
pub mod document;
pub mod image;
pub mod media;

use crate::api::{ConvertOptions, ConvertResult};

/// Convert a single file
pub fn convert_single(
    input_path: &str,
    output_dir: &str,
    options: &ConvertOptions,
) -> ConvertResult {
    // Ensure output directory exists
    if let Err(e) = std::fs::create_dir_all(output_dir) {
        return ConvertResult {
            success: false,
            output_path: None,
            error: Some(format!("Failed to create output directory: {}", e)),
        };
    }

    let file_type = crate::api::detect_file_type(input_path.to_string());

    match file_type {
        Some(crate::api::FileType::Image) => image::convert_image(input_path, output_dir, options),
        Some(crate::api::FileType::Document) => {
            document::convert_document(input_path, output_dir, options)
        }
        Some(crate::api::FileType::Audio) | Some(crate::api::FileType::Video) => {
            // Audio/Video conversion (requires FFmpeg)
            media::convert_media(input_path, output_dir, options)
        }
        Some(crate::api::FileType::Config) => {
            config::convert_config(input_path, output_dir, options)
        }
        None => ConvertResult {
            success: false,
            output_path: None,
            error: Some("Unsupported file type".to_string()),
        },
    }
}
