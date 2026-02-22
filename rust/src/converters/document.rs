use crate::api::{ConvertOptions, ConvertResult};
use std::path::Path;

/// 转换文档
pub fn convert_document(
    input_path: &str,
    output_dir: &str,
    options: &ConvertOptions,
) -> ConvertResult {
    let input = Path::new(input_path);
    let stem = input.file_stem().and_then(|s| s.to_str()).unwrap_or("output");
    let output_ext = options.output_format.to_lowercase();
    let output_name = format!("{}.{}", stem, output_ext);
    let output_path = Path::new(output_dir).join(&output_name);

    // 读取输入文件
    let content = match std::fs::read_to_string(input_path) {
        Ok(c) => c,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("无法读取文件: {}", e)),
            }
        }
    };

    let input_ext = input
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();

    match output_ext.as_str() {
        "html" => {
            convert_to_html(&content, &input_ext, &output_path)
        }
        "txt" => {
            convert_to_txt(&content, &input_ext, &output_path)
        }
        "pdf" => {
            // PDF 生成需要更复杂的实现
            ConvertResult {
                success: false,
                output_path: None,
                error: Some("PDF 输出功能开发中...".to_string()),
            }
        }
        _ => ConvertResult {
            success: false,
            output_path: None,
            error: Some(format!("不支持的输出格式: {}", output_ext)),
        },
    }
}

/// 转换为 HTML
fn convert_to_html(content: &str, input_ext: &str, output_path: &Path) -> ConvertResult {
    let html = match input_ext {
        "md" | "markdown" => {
            // Markdown 转 HTML
            let options = comrak::ComrakOptions::default();
            comrak::markdown_to_html(content, &options)
        }
        "html" | "htm" => content.to_string(),
        "txt" => {
            format!(
                "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>Document</title></head><body><pre>{}</pre></body></html>",
                html_escape(content)
            )
        }
        _ => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some("不支持的输入格式".to_string()),
            }
        }
    };

    match std::fs::write(output_path, html) {
        Ok(()) => ConvertResult {
            success: true,
            output_path: Some(output_path.to_string_lossy().to_string()),
            error: None,
        },
        Err(e) => ConvertResult {
            success: false,
            output_path: None,
            error: Some(format!("写入失败: {}", e)),
        },
    }
}

/// 转换为纯文本
fn convert_to_txt(content: &str, input_ext: &str, output_path: &Path) -> ConvertResult {
    let text = match input_ext {
        "md" | "markdown" => {
            // 简单移除 Markdown 标记
            content
                .replace("### ", "")
                .replace("## ", "")
                .replace("# ", "")
                .replace("**", "")
                .replace("__", "")
                .replace("*", "")
                .replace("_", "")
                .replace("`", "")
        }
        "html" | "htm" => {
            // 简单移除 HTML 标签
            let re = regex::Regex::new(r"<[^>]+>").unwrap();
            re.replace_all(content, "").to_string()
        }
        "txt" => content.to_string(),
        _ => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some("不支持的输入格式".to_string()),
            }
        }
    };

    match std::fs::write(output_path, text) {
        Ok(()) => ConvertResult {
            success: true,
            output_path: Some(output_path.to_string_lossy().to_string()),
            error: None,
        },
        Err(e) => ConvertResult {
            success: false,
            output_path: None,
            error: Some(format!("写入失败: {}", e)),
        },
    }
}

/// HTML 转义
fn html_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&#39;")
}
