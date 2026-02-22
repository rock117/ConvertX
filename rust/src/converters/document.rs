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

     let input_ext = input
         .extension()
         .and_then(|e| e.to_str())
         .unwrap_or("")
         .to_lowercase();

     // Special case: EPUB -> PDF (via external tools)
     // NOTE: EPUB is a binary (zip) container; do NOT attempt to read it as UTF-8 text.
     if input_ext == "epub" {
         return match output_ext.as_str() {
             "pdf" => convert_epub_to_pdf(input_path, &output_path),
             _ => ConvertResult {
                 success: false,
                 output_path: None,
                 error: Some("EPUB 目前仅支持输出 PDF".to_string()),
             },
         };
     }

    // 读取输入文件（仅适用于纯文本类文档）
    let content = match std::fs::read_to_string(input_path) {
        Ok(c) => c,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("无法读取文本文件: {}", e)),
            }
        }
    };

    match output_ext.as_str() {
        "html" => {
            convert_to_html(&content, &input_ext, &output_path)
        }
        "txt" => {
            convert_to_txt(&content, &input_ext, &output_path)
        }
        "pdf" => {
            ConvertResult {
                success: false,
                output_path: None,
                error: Some("PDF 输出暂不支持（目前仅支持 EPUB -> PDF）".to_string()),
            }
        }
        _ => ConvertResult {
            success: false,
            output_path: None,
            error: Some(format!("不支持的输出格式: {}", output_ext)),
        },
    }
}

fn convert_epub_to_pdf(input_path: &str, output_path: &Path) -> ConvertResult {
    fn tool_exists(cmd: &str) -> bool {
        std::process::Command::new(cmd)
            .arg("--version")
            .output()
            .is_ok()
    }

    let has_pandoc = tool_exists("pandoc");
    let has_ebook_convert = tool_exists("ebook-convert");

    if !has_pandoc && !has_ebook_convert {
        return ConvertResult {
            success: false,
            output_path: None,
            error: Some(
                "未检测到 pandoc 或 calibre(ebook-convert)。请先安装任意一个：\n\n- pandoc: https://pandoc.org/installing.html\n- calibre: 安装后会提供 ebook-convert 命令\n\nWindows 也可用 winget：\n- winget install Pandoc\n- winget install calibre.calibre".to_string(),
            ),
        };
    }

    // Prefer pandoc
    if has_pandoc {
        match std::process::Command::new("pandoc")
            .arg(input_path)
            .arg("-o")
            .arg(output_path)
            .output()
        {
            Ok(out) if out.status.success() => {
                return ConvertResult {
                    success: true,
                    output_path: Some(output_path.to_string_lossy().to_string()),
                    error: None,
                };
            }
            Ok(out) => {
                let stderr = String::from_utf8_lossy(&out.stderr).to_string();
                // fallthrough to ebook-convert
                if !stderr.trim().is_empty() && has_ebook_convert {
                    // keep for later; nothing else
                }
            }
            Err(_) => {
                // fallthrough to ebook-convert
            }
        }
    }

    // Fallback to calibre
    if has_ebook_convert {
        match std::process::Command::new("ebook-convert")
            .arg(input_path)
            .arg(output_path)
            .output()
        {
            Ok(out) if out.status.success() => ConvertResult {
                success: true,
                output_path: Some(output_path.to_string_lossy().to_string()),
                error: None,
            },
            Ok(out) => ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!(
                    "EPUB->PDF 转换失败（ebook-convert 返回码: {:?}）。\n{}",
                    out.status.code(),
                    String::from_utf8_lossy(&out.stderr)
                )),
            },
            Err(e) => ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!(
                    "无法执行 ebook-convert: {}。请确认已安装 calibre，并确保 ebook-convert 在 PATH 中。",
                    e
                )),
            },
        }
    } else {
        ConvertResult {
            success: false,
            output_path: None,
            error: Some(
                "pandoc 转换失败，且未检测到 calibre(ebook-convert)。请安装 calibre 或检查 pandoc 输出日志。".to_string(),
            ),
        }
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
