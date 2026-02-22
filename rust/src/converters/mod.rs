pub mod image;
pub mod document;

use crate::api::{ConvertOptions, ConvertResult};

/// 转换单个文件
pub fn convert_single(
    input_path: &str,
    output_dir: &str,
    options: &ConvertOptions,
) -> ConvertResult {
    // 确保输出目录存在
    if let Err(e) = std::fs::create_dir_all(output_dir) {
        return ConvertResult {
            success: false,
            output_path: None,
            error: Some(format!("无法创建输出目录: {}", e)),
        };
    }

    let file_type = crate::api::detect_file_type(input_path.to_string());
    
    match file_type {
        Some(crate::api::FileType::Image) => {
            image::convert_image(input_path, output_dir, options)
        }
        Some(crate::api::FileType::Document) => {
            document::convert_document(input_path, output_dir, options)
        }
        Some(crate::api::FileType::Audio) | Some(crate::api::FileType::Video) => {
            // 音视频转换需要 FFmpeg，后续实现
            ConvertResult {
                success: false,
                output_path: None,
                error: Some("音视频转换功能开发中...".to_string()),
            }
        }
        None => ConvertResult {
            success: false,
            output_path: None,
            error: Some("不支持的文件类型".to_string()),
        },
    }
}
