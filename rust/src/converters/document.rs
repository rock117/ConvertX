use crate::api::{ConvertOptions, ConvertResult};
use headless_chrome::Browser;
use std::path::Path;

/// Convert document
pub fn convert_document(
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

    let input_ext = input
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();

    // Special case: Markdown <-> Office (via pandoc)
    // NOTE: docx/pptx are binary containers; do NOT attempt to read them as UTF-8 text.
    if matches!(input_ext.as_str(), "md" | "markdown" | "docx" | "pptx")
        && matches!(output_ext.as_str(), "md" | "docx" | "pptx")
        && !(matches!(input_ext.as_str(), "docx" | "pptx")
            && matches!(output_ext.as_str(), "docx" | "pptx"))
    {
        return convert_via_pandoc(input_path, &output_path);
    }

    // Special case: Markdown -> PDF (via Chromium)
    if matches!(input_ext.as_str(), "md" | "markdown") && output_ext == "pdf" {
        return convert_markdown_to_pdf(input_path, &output_path);
    }

    // PDF input is not supported (do not attempt to read it as UTF-8 text)
    if input_ext == "pdf" {
        return ConvertResult {
            success: false,
            output_path: None,
            error: Some("PDF input conversion is not supported.".to_string()),
        };
    }

    // Special case: EPUB -> PDF (via external tools)
    // NOTE: EPUB is a binary (zip) container; do NOT attempt to read it as UTF-8 text.
    if input_ext == "epub" {
        return match output_ext.as_str() {
            "pdf" => convert_epub_to_pdf(input_path, &output_path),
            _ => ConvertResult {
                success: false,
                output_path: None,
                error: Some("EPUB currently only supports PDF output".to_string()),
            },
        };
    }

    // Read input file (only applicable for plain text documents)
    let content = match std::fs::read_to_string(input_path) {
        Ok(c) => c,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("Failed to read text file: {}", e)),
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
        "pdf" => ConvertResult {
            success: false,
            output_path: None,
            error: Some(
                "PDF output is not supported for this input type (only Markdown -> PDF and EPUB -> PDF are supported)."
                    .to_string(),
            ),
        },
        _ => ConvertResult {
            success: false,
            output_path: None,
            error: Some(format!("Unsupported output format: {}", output_ext)),
        },
    }
}

fn convert_markdown_to_pdf(input_path: &str, output_path: &Path) -> ConvertResult {
    convert_via_chromium(input_path, output_path)
}

fn convert_via_chromium(input_path: &str, output_path: &Path) -> ConvertResult {
    // Read markdown file
    let markdown_content = match std::fs::read_to_string(input_path) {
        Ok(content) => content,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("Failed to read markdown file: {}", e)),
            }
        }
    };

    // Convert markdown to HTML using comrak (enable GFM extensions we need)
    let mut options = comrak::ComrakOptions::default();
    options.extension.tasklist = true;
    options.extension.table = true;
    let mut html_content = comrak::markdown_to_html(&markdown_content, &options);

    // Replace checkbox input elements with symbols for stable PDF rendering.
    // Comrak emits variants like:
    // - <input type="checkbox" disabled="" />
    // - <input type="checkbox" checked="" disabled="" />
    let checkbox_re =
        match regex::Regex::new(r#"(?i)<input[^>]*type=(?:\"checkbox\"|'checkbox')[^>]*>"#) {
            Ok(re) => re,
            Err(e) => {
                return ConvertResult {
                    success: false,
                    output_path: None,
                    error: Some(format!("Failed to build checkbox regex: {}", e)),
                }
            }
        };
    html_content = checkbox_re
        .replace_all(&html_content, |caps: &regex::Captures| {
            let tag = caps.get(0).map(|m| m.as_str()).unwrap_or("");
            if tag.to_ascii_lowercase().contains("checked") {
                r#"<span class="task-check task-check-done">✓</span>"#
            } else {
                r#"<span class="task-check task-check-todo">✗</span>"#
            }
        })
        .to_string();

    // Wrap HTML with proper styling for better PDF output
    let full_html = format!(
        r#"<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 900px;
            margin: 0 auto;
            padding: 20px;
            background-color: #fff;
        }}
        h1, h2, h3, h4, h5, h6 {{
            margin-top: 24px;
            margin-bottom: 16px;
            font-weight: 600;
            line-height: 1.25;
        }}
        h1 {{ font-size: 2em; border-bottom: 1px solid #eaecef; padding-bottom: 0.3em; }}
        h2 {{ font-size: 1.5em; border-bottom: 1px solid #eaecef; padding-bottom: 0.3em; }}
        h3 {{ font-size: 1.25em; }}
        h4 {{ font-size: 1em; }}
        h5 {{ font-size: 0.875em; }}
        h6 {{ font-size: 0.85em; color: #6a737d; }}
        p {{ margin: 0 0 16px 0; }}
        a {{ color: #0366d6; text-decoration: none; }}
        a:hover {{ text-decoration: underline; }}
        code {{
            background-color: #f6f8fa;
            padding: 0.2em 0.4em;
            margin: 0;
            font-size: 85%;
            border-radius: 3px;
            font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace;
        }}
        pre {{
            background-color: #f6f8fa;
            border: 1px solid #ddd;
            border-radius: 3px;
            padding: 16px;
            overflow: auto;
            font-size: 85%;
            line-height: 1.45;
            margin: 0 0 16px 0;
        }}
        pre code {{
            background-color: transparent;
            padding: 0;
            margin: 0;
            font-size: 100%;
            border-radius: 0;
        }}
        blockquote {{
            padding: 0 1em;
            color: #6a737d;
            border-left: 0.25em solid #dfe2e5;
            margin: 0 0 16px 0;
        }}
        table {{
            border-collapse: collapse;
            width: 100%;
            margin: 0 0 16px 0;
        }}
        table th, table td {{
            padding: 6px 13px;
            border: 1px solid #dfe2e5;
        }}
        table tr:nth-child(2n) {{
            background-color: #f6f8fa;
        }}
        ul, ol {{
            padding-left: 2em;
            margin: 0 0 16px 0;
        }}
        li {{
            margin-bottom: 8px;
        }}
        img {{
            max-width: 100%;
            height: auto;
        }}
        .task-check {{
            display: inline-block;
            width: 1.2em;
            font-weight: 700;
            margin-right: 0.35em;
        }}
        .task-check-done {{
            color: #16a34a;
        }}
        .task-check-todo {{
            color: #dc2626;
        }}
    </style>
</head>
<body>
{}
</body>
</html>"#,
        html_content
    );

    // Try to launch browser and convert to PDF
    match Browser::default() {
        Ok(browser) => {
            match browser.new_tab() {
                Ok(tab) => {
                    // Navigate to data URL with HTML content
                    let data_url = format!("data:text/html;charset=utf-8,{}", urlencoding::encode(&full_html));
                    match tab.navigate_to(&data_url) {
                        Ok(_) => {
                            // Give page time to render
                            std::thread::sleep(std::time::Duration::from_millis(1000));

                            // Print to PDF
                            match tab.print_to_pdf(None) {
                                Ok(pdf_data) => {
                                    match std::fs::write(output_path, pdf_data) {
                                        Ok(_) => ConvertResult {
                                            success: true,
                                            output_path: Some(output_path.to_string_lossy().to_string()),
                                            error: None,
                                        },
                                        Err(e) => ConvertResult {
                                            success: false,
                                            output_path: None,
                                            error: Some(format!("Failed to write PDF file: {}", e)),
                                        },
                                    }
                                }
                                Err(e) => ConvertResult {
                                    success: false,
                                    output_path: None,
                                    error: Some(format!("Failed to generate PDF: {}", e)),
                                },
                            }
                        }
                        Err(e) => ConvertResult {
                            success: false,
                            output_path: None,
                            error: Some(format!("Failed to navigate to content: {}", e)),
                        },
                    }
                }
                Err(e) => ConvertResult {
                    success: false,
                    output_path: None,
                    error: Some(format!("Failed to create browser tab: {}", e)),
                },
            }
        }
        Err(e) => ConvertResult {
            success: false,
            output_path: None,
            error: Some(format!(
                "Chromium not available: {}. Install Chrome/Chromium and ensure it can be launched in this environment.",
                e
            )),
        },
    }
}

fn convert_via_pandoc(input_path: &str, output_path: &Path) -> ConvertResult {
    fn tool_exists(cmd: &str) -> bool {
        std::process::Command::new(cmd)
            .arg("--version")
            .output()
            .is_ok()
    }

    if !tool_exists("pandoc") {
        return ConvertResult {
            success: false,
            output_path: None,
            error: Some(
                "pandoc is required for Markdown conversions (Office/PDF).\n\nInstall pandoc:\n- https://pandoc.org/installing.html\n\nWindows (winget):\n- winget install Pandoc"
                    .to_string(),
            ),
        };
    }

    let output_ext = output_path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();

    let mut cmd = std::process::Command::new("pandoc");
    cmd.arg(input_path).arg("-o").arg(output_path);

    if output_ext == "pdf" {
        cmd.arg("--pdf-engine=xelatex");
    }

    match cmd.output() {
        Ok(out) if out.status.success() => ConvertResult {
            success: true,
            output_path: Some(output_path.to_string_lossy().to_string()),
            error: None,
        },
        Ok(out) => {
            let stderr = String::from_utf8_lossy(&out.stderr).to_string();
            let mut message = format!(
                "Pandoc conversion failed (exit code: {:?}).\n{}",
                out.status.code(),
                stderr
            );

            let stderr_lc = stderr.to_lowercase();

            if output_ext == "pdf" {
                if stderr_lc.contains("unicode character")
                    && stderr_lc.contains("not set up for use with latex")
                {
                    message.push_str(
                        "\n\nUnicode/CJK character error detected:\n- ConvertX uses XeLaTeX for better Unicode support.\n- Ensure XeLaTeX is installed (usually included with MiKTeX/TeX Live).\n- For CJK text (Chinese/Japanese/Korean), install CJK fonts on your system.\n- On Windows with MiKTeX: open MiKTeX Console, run Updates, then retry.\n- If XeLaTeX is not available, install TeX Live or MiKTeX with full package support.\n",
                    );
                } else if stderr_lc.contains("pdflatex")
                    || stderr_lc.contains("miktex")
                    || stderr_lc.contains("xelatex")
                    || stderr_lc.contains("lualatex")
                    || stderr_lc.contains("latex")
                {
                    message.push_str(
                        "\n\nPDF generation notes (Windows):\n- pandoc requires a PDF engine (e.g. MiKTeX/TeX Live with XeLaTeX).\n- If you use MiKTeX, open MiKTeX Console and run Updates, then retry.\n- Ensure XeLaTeX is installed and available in PATH.\n- For CJK support, install appropriate language packages and fonts.\n",
                    );
                }
            }

            ConvertResult {
                success: false,
                output_path: None,
                error: Some(message),
            }
        }
        Err(e) => ConvertResult {
            success: false,
            output_path: None,
            error: Some(format!("Failed to execute pandoc: {e}")),
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
                "Neither pandoc nor calibre (ebook-convert) was detected. Please install one of them:\n\n- pandoc: https://pandoc.org/installing.html\n- calibre: Provides the ebook-convert command after installation\n\nWindows (winget):\n- winget install Pandoc\n- winget install calibre.calibre".to_string(),
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
                    "EPUB->PDF conversion failed (ebook-convert exit code: {:?}).\n{}",
                    out.status.code(),
                    String::from_utf8_lossy(&out.stderr)
                )),
            },
            Err(e) => ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!(
                    "Failed to execute ebook-convert: {}. Please ensure calibre is installed and ebook-convert is in PATH.",
                    e
                )),
            },
        }
    } else {
        ConvertResult {
            success: false,
            output_path: None,
            error: Some(
                "pandoc conversion failed and calibre (ebook-convert) was not detected. Please install calibre or check the pandoc output log.".to_string(),
            ),
        }
    }
}

/// Convert to HTML
fn convert_to_html(content: &str, input_ext: &str, output_path: &Path) -> ConvertResult {
    let html = match input_ext {
        "md" | "markdown" => {
            // Markdown to HTML
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
                error: Some("Unsupported input format".to_string()),
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
            error: Some(format!("Write failed: {}", e)),
        },
    }
}

/// Convert to plain text
fn convert_to_txt(content: &str, input_ext: &str, output_path: &Path) -> ConvertResult {
    let text = match input_ext {
        "md" | "markdown" => {
            // Simply remove Markdown markers
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
            // Simply remove HTML tags
            let re = regex::Regex::new(r"<[^>]+>").unwrap();
            re.replace_all(content, "").to_string()
        }
        "txt" => content.to_string(),
        _ => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some("Unsupported input format".to_string()),
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
            error: Some(format!("Write failed: {}", e)),
        },
    }
}

/// HTML escape
fn html_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&#39;")
}
