use crate::api::{ConvertOptions, ConvertResult};
use std::path::Path;

/// 转换媒体文件（音视频）
pub fn convert_media(
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

    // Special case: Video -> Audio (via FFmpeg)
    let is_video = matches!(
        input_ext.as_str(),
        "mp4" | "avi" | "mkv" | "mov" | "webm" | "flv"
    );
    let is_audio_output = matches!(
        output_ext.as_str(),
        "mp3" | "wav" | "aac" | "flac" | "ogg" | "m4a"
    );

    if is_video && is_audio_output {
        return convert_via_ffmpeg(input_path, &output_path, options);
    }

    ConvertResult {
        success: false,
        output_path: None,
        error: Some(format!(
            "Unsupported media conversion: {} -> {}",
            input_ext, output_ext
        )),
    }
}

fn convert_via_ffmpeg(input_path: &str, output_path: &Path, options: &ConvertOptions) -> ConvertResult {
    let ffmpeg_cmd = options.ffmpeg_path.as_deref().unwrap_or("ffmpeg");

    fn tool_exists(cmd: &str) -> bool {
        std::process::Command::new(cmd)
            .arg("-version")
            .output()
            .is_ok()
    }

    if !tool_exists(ffmpeg_cmd) {
        return ConvertResult {
            success: false,
            output_path: None,
            error: Some(
                "FFmpeg is required for media conversions.\n\nInstall FFmpeg:\n- Windows (winget): winget install ffmpeg\n- Or download from https://ffmpeg.org/download.html"
                    .to_string(),
            ),
        };
    }

    let output_ext = output_path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();

    let mut cmd = std::process::Command::new(ffmpeg_cmd);
    cmd.arg("-y")             // Overwrite output files without asking
       .arg("-i")
       .arg(input_path)
       .arg("-vn");           // Disable video recording (extract audio only)

    // Format-specific arguments
    match output_ext.as_str() {
        "mp3" => {
            cmd.arg("-c:a").arg("libmp3lame").arg("-q:a").arg("2");
        }
        "wav" => {
            cmd.arg("-c:a").arg("pcm_s16le");
        }
        "aac" => {
            cmd.arg("-c:a").arg("aac").arg("-b:a").arg("192k");
        }
        "flac" => {
            cmd.arg("-c:a").arg("flac");
        }
        _ => {}
    }

    cmd.arg(output_path);

    match cmd.output() {
        Ok(out) if out.status.success() => ConvertResult {
            success: true,
            output_path: Some(output_path.to_string_lossy().to_string()),
            error: None,
        },
        Ok(out) => {
            let stderr = String::from_utf8_lossy(&out.stderr).to_string();
            ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!(
                    "FFmpeg conversion failed (exit code: {:?}).\n{}",
                    out.status.code(),
                    stderr
                )),
            }
        }
        Err(e) => ConvertResult {
            success: false,
            output_path: None,
            error: Some(format!("Failed to execute FFmpeg: {e}")),
        },
    }
}
