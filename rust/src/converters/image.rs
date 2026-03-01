use crate::api::{ConvertOptions, ConvertResult};
use image::{ImageFormat, ImageReader};
use std::path::Path;

/// Convert image
pub fn convert_image(
    input_path: &str,
    output_dir: &str,
    options: &ConvertOptions,
) -> ConvertResult {
    let input = Path::new(input_path);
    let stem = input
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("output");
    let output_ext = options.output_format.to_lowercase();
    let output_name = format!("{}.{}", stem, output_ext);
    let output_path = Path::new(output_dir).join(&output_name);

    // Read image
    let img = match ImageReader::open(input) {
        Ok(reader) => match reader.decode() {
            Ok(img) => img,
            Err(e) => {
                return ConvertResult {
                    success: false,
                    output_path: None,
                    error: Some(format!("Failed to decode image: {}", e)),
                }
            }
        },
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("Failed to read file: {}", e)),
            }
        }
    };

    // Determine output format
    let format = match output_ext.as_str() {
        "png" => ImageFormat::Png,
        "jpg" | "jpeg" => ImageFormat::Jpeg,
        "webp" => ImageFormat::WebP,
        "bmp" => ImageFormat::Bmp,
        "ico" => ImageFormat::Ico,
        "gif" => ImageFormat::Gif,
        _ => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("Unsupported output format: {}", output_ext)),
            }
        }
    };

    // Save image with quality settings
    let quality = options.image_quality.unwrap_or(85).clamp(1, 100) as u8;

    match format {
        ImageFormat::Jpeg => {
            // JPEG supports quality setting
            let mut output_file = match std::fs::File::create(&output_path) {
                Ok(f) => f,
                Err(e) => {
                    return ConvertResult {
                        success: false,
                        output_path: None,
                        error: Some(format!("Failed to create output file: {}", e)),
                    }
                }
            };

            let encoder =
                image::codecs::jpeg::JpegEncoder::new_with_quality(&mut output_file, quality);
            match img.write_with_encoder(encoder) {
                Ok(()) => ConvertResult {
                    success: true,
                    output_path: Some(output_path.to_string_lossy().to_string()),
                    error: None,
                },
                Err(e) => ConvertResult {
                    success: false,
                    output_path: None,
                    error: Some(format!("Failed to save JPEG: {}", e)),
                },
            }
        }
        ImageFormat::WebP => {
            // WebP - use default encoding for now
            match img.save_with_format(&output_path, format) {
                Ok(()) => ConvertResult {
                    success: true,
                    output_path: Some(output_path.to_string_lossy().to_string()),
                    error: None,
                },
                Err(e) => ConvertResult {
                    success: false,
                    output_path: None,
                    error: Some(format!("Failed to save WebP: {}", e)),
                },
            }
        }
        _ => {
            // PNG, BMP, ICO, GIF - no quality setting needed (lossless or fixed format)
            match img.save_with_format(&output_path, format) {
                Ok(()) => ConvertResult {
                    success: true,
                    output_path: Some(output_path.to_string_lossy().to_string()),
                    error: None,
                },
                Err(e) => ConvertResult {
                    success: false,
                    output_path: None,
                    error: Some(format!("Failed to save: {}", e)),
                },
            }
        }
    }
}
