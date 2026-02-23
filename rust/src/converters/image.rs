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

    // Resize
    let final_img = if let (Some(w), Some(h)) = (options.width, options.height) {
        img.resize(w as u32, h as u32, image::imageops::FilterType::Lanczos3)
    } else if let Some(w) = options.width {
        img.resize(
            w as u32,
            (w as f64 * img.height() as f64 / img.width() as f64) as u32,
            image::imageops::FilterType::Lanczos3,
        )
    } else if let Some(h) = options.height {
        img.resize(
            (h as f64 * img.width() as f64 / img.height() as f64) as u32,
            h as u32,
            image::imageops::FilterType::Lanczos3,
        )
    } else {
        img
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

    // Save image
    match final_img.save_with_format(&output_path, format) {
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
