use crate::api::{ConvertOptions, ConvertResult};
use serde_json::Value as JsonValue;
use serde_yaml::Value as YamlValue;
use std::collections::HashMap;
use std::path::Path;

/// 转换配置文件（YAML <-> Properties, YAML <-> JSON）
pub fn convert_config(
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

    match (input_ext.as_str(), output_ext.as_str()) {
        ("yaml" | "yml", "properties") => yaml_to_properties(input, &output_path),
        ("properties", "yaml" | "yml") => properties_to_yaml(input, &output_path),
        ("yaml" | "yml", "json") => yaml_to_json(input, &output_path),
        ("json", "yaml" | "yml") => json_to_yaml(input, &output_path),
        ("properties", "json") => properties_to_json(input, &output_path),
        ("json", "properties") => json_to_properties(input, &output_path),
        _ => ConvertResult {
            success: false,
            output_path: None,
            error: Some(format!("不支持的转换: {} -> {}", input_ext, output_ext)),
        },
    }
}

fn yaml_to_properties(input_path: &Path, output_path: &Path) -> ConvertResult {
    let yaml_content = match std::fs::read_to_string(input_path) {
        Ok(content) => content,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("无法读取 YAML 文件: {}", e)),
            }
        }
    };

    let yaml_value: YamlValue = match serde_yaml::from_str(&yaml_content) {
        Ok(value) => value,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("YAML 解析失败: {}", e)),
            }
        }
    };

    let mut properties = HashMap::new();
    flatten_yaml(&yaml_value, "", &mut properties);

    let mut keys: Vec<&String> = properties.keys().collect();
    keys.sort();

    let properties_content = keys
        .iter()
        .map(|k| {
            let v = &properties[*k];
            format!(
                "{}={}",
                escape_properties_key(k),
                escape_properties_value(v)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");

    match std::fs::write(output_path, properties_content) {
        Ok(()) => ConvertResult {
            success: true,
            output_path: Some(output_path.to_string_lossy().to_string()),
            error: None,
        },
        Err(e) => ConvertResult {
            success: false,
            output_path: None,
            error: Some(format!("写入 Properties 文件失败: {}", e)),
        },
    }
}

fn properties_to_yaml(input_path: &Path, output_path: &Path) -> ConvertResult {
    let properties_content = match std::fs::read_to_string(input_path) {
        Ok(content) => content,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("无法读取 Properties 文件: {}", e)),
            }
        }
    };

    let mut properties = HashMap::new();
    for line in properties_content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') || line.starts_with('!') {
            continue;
        }

        if let Some((key, value)) = parse_properties_line(line) {
            properties.insert(key, value);
        }
    }

    let yaml_value = unflatten_properties(&properties);
    let yaml_content = match serde_yaml::to_string(&yaml_value) {
        Ok(content) => content,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("YAML 序列化失败: {}", e)),
            }
        }
    };

    match std::fs::write(output_path, yaml_content) {
        Ok(()) => ConvertResult {
            success: true,
            output_path: Some(output_path.to_string_lossy().to_string()),
            error: None,
        },
        Err(e) => ConvertResult {
            success: false,
            output_path: None,
            error: Some(format!("写入 YAML 文件失败: {}", e)),
        },
    }
}

fn flatten_yaml(value: &YamlValue, prefix: &str, map: &mut HashMap<String, String>) {
    match value {
        YamlValue::Mapping(mapping) => {
            for (k, v) in mapping {
                if let YamlValue::String(key) = k {
                    let new_key = if prefix.is_empty() {
                        key.clone()
                    } else {
                        format!("{}.{}", prefix, key)
                    };
                    flatten_yaml(v, &new_key, map);
                }
            }
        }
        YamlValue::Sequence(seq) => {
            for (i, v) in seq.iter().enumerate() {
                let new_key = format!("{}[{}]", prefix, i);
                flatten_yaml(v, &new_key, map);
            }
        }
        YamlValue::Null => {
            map.insert(prefix.to_string(), "".to_string());
        }
        YamlValue::Bool(b) => {
            map.insert(prefix.to_string(), b.to_string());
        }
        YamlValue::Number(n) => {
            map.insert(prefix.to_string(), n.to_string());
        }
        YamlValue::String(s) => {
            map.insert(prefix.to_string(), s.clone());
        }
        _ => {}
    }
}

fn unflatten_properties(properties: &HashMap<String, String>) -> YamlValue {
    let mut root: serde_yaml::Mapping = serde_yaml::Mapping::new();

    for (key, value) in properties {
        insert_value(&mut root, key, value);
    }

    YamlValue::Mapping(root)
}

fn insert_value(map: &mut serde_yaml::Mapping, key: &str, value: &str) {
    let parts: Vec<&str> = key.split('.').collect();

    if parts.len() == 1 {
        let key_value = YamlValue::String(parts[0].to_string());
        let value_value = parse_properties_value(value);
        map.insert(key_value, value_value);
        return;
    }

    let current_key = YamlValue::String(parts[0].to_string());
    let remaining_key = &parts[1..].join(".");

    let nested_map = map
        .get(&current_key)
        .and_then(|v| {
            if let YamlValue::Mapping(m) = v {
                Some(m.clone())
            } else {
                None
            }
        })
        .unwrap_or_else(|| serde_yaml::Mapping::new());

    let mut nested_map = nested_map;
    insert_value(&mut nested_map, remaining_key, value);
    map.insert(current_key, YamlValue::Mapping(nested_map));
}

fn parse_properties_line(line: &str) -> Option<(String, String)> {
    let mut key = String::new();
    let mut value = String::new();
    let mut in_escape = false;
    let mut in_key = true;
    let mut chars = line.chars().peekable();

    while let Some(c) = chars.next() {
        if in_escape {
            key.push(c);
            in_escape = false;
        } else if c == '\\' {
            in_escape = true;
        } else if c == '=' && in_key {
            in_key = false;
        } else if c == ':' && in_key {
            in_key = false;
        } else if c == ' ' && in_key && key.is_empty() {
            continue;
        } else if in_key {
            key.push(c);
        } else {
            value.push(c);
        }
    }

    if key.is_empty() {
        None
    } else {
        Some((key.trim().to_string(), value.trim().to_string()))
    }
}

fn parse_properties_value(value: &str) -> YamlValue {
    if value.is_empty() {
        return YamlValue::Null;
    }

    if value.eq_ignore_ascii_case("true") {
        return YamlValue::Bool(true);
    }

    if value.eq_ignore_ascii_case("false") {
        return YamlValue::Bool(false);
    }

    if let Ok(num) = value.parse::<i64>() {
        return YamlValue::Number(serde_yaml::Number::from(num));
    }

    if let Ok(num) = value.parse::<f64>() {
        let n = serde_yaml::Number::from(num);
        return YamlValue::Number(n);
    }

    YamlValue::String(unescape_properties_value(value))
}

fn escape_properties_key(key: &str) -> String {
    key.replace('\\', "\\\\")
        .replace('=', "\\=")
        .replace(':', "\\:")
        .replace(' ', "\\ ")
}

fn escape_properties_value(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
}

fn unescape_properties_value(value: &str) -> String {
    let mut result = String::new();
    let mut chars = value.chars().peekable();

    while let Some(c) = chars.next() {
        if c == '\\' {
            if let Some(next) = chars.next() {
                match next {
                    'n' => result.push('\n'),
                    'r' => result.push('\r'),
                    't' => result.push('\t'),
                    other => result.push(other),
                }
            }
        } else {
            result.push(c);
        }
    }

    result
}

fn yaml_to_json(input_path: &Path, output_path: &Path) -> ConvertResult {
    let yaml_content = match std::fs::read_to_string(input_path) {
        Ok(content) => content,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("无法读取 YAML 文件: {}", e)),
            }
        }
    };

    let yaml_value: YamlValue = match serde_yaml::from_str(&yaml_content) {
        Ok(value) => value,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("YAML 解析失败: {}", e)),
            }
        }
    };

    let json_value: JsonValue = match serde_json::to_value(&yaml_value) {
        Ok(value) => value,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("转换为 JSON 失败: {}", e)),
            }
        }
    };

    let json_content = match serde_json::to_string_pretty(&json_value) {
        Ok(content) => content,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("JSON 序列化失败: {}", e)),
            }
        }
    };

    match std::fs::write(output_path, json_content) {
        Ok(()) => ConvertResult {
            success: true,
            output_path: Some(output_path.to_string_lossy().to_string()),
            error: None,
        },
        Err(e) => ConvertResult {
            success: false,
            output_path: None,
            error: Some(format!("写入 JSON 文件失败: {}", e)),
        },
    }
}

fn json_to_yaml(input_path: &Path, output_path: &Path) -> ConvertResult {
    let json_content = match std::fs::read_to_string(input_path) {
        Ok(content) => content,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("无法读取 JSON 文件: {}", e)),
            }
        }
    };

    let json_value: JsonValue = match serde_json::from_str(&json_content) {
        Ok(value) => value,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("JSON 解析失败: {}", e)),
            }
        }
    };

    let yaml_value: YamlValue = match serde_yaml::to_value(&json_value) {
        Ok(value) => value,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("转换为 YAML 失败: {}", e)),
            }
        }
    };

    let yaml_content = match serde_yaml::to_string(&yaml_value) {
        Ok(content) => content,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("YAML 序列化失败: {}", e)),
            }
        }
    };

    match std::fs::write(output_path, yaml_content) {
        Ok(()) => ConvertResult {
            success: true,
            output_path: Some(output_path.to_string_lossy().to_string()),
            error: None,
        },
        Err(e) => ConvertResult {
            success: false,
            output_path: None,
            error: Some(format!("写入 YAML 文件失败: {}", e)),
        },
    }
}

fn properties_to_json(input_path: &Path, output_path: &Path) -> ConvertResult {
    let properties_content = match std::fs::read_to_string(input_path) {
        Ok(content) => content,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("无法读取 Properties 文件: {}", e)),
            }
        }
    };

    let mut properties = HashMap::new();
    for line in properties_content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') || line.starts_with('!') {
            continue;
        }

        if let Some((key, value)) = parse_properties_line(line) {
            properties.insert(key, value);
        }
    }

    let yaml_value = unflatten_properties(&properties);
    let json_value: JsonValue = match serde_json::to_value(&yaml_value) {
        Ok(value) => value,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("转换为 JSON 失败: {}", e)),
            }
        }
    };

    let json_content = match serde_json::to_string_pretty(&json_value) {
        Ok(content) => content,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("JSON 序列化失败: {}", e)),
            }
        }
    };

    match std::fs::write(output_path, json_content) {
        Ok(()) => ConvertResult {
            success: true,
            output_path: Some(output_path.to_string_lossy().to_string()),
            error: None,
        },
        Err(e) => ConvertResult {
            success: false,
            output_path: None,
            error: Some(format!("写入 JSON 文件失败: {}", e)),
        },
    }
}

fn json_to_properties(input_path: &Path, output_path: &Path) -> ConvertResult {
    let json_content = match std::fs::read_to_string(input_path) {
        Ok(content) => content,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("无法读取 JSON 文件: {}", e)),
            }
        }
    };

    let json_value: JsonValue = match serde_json::from_str(&json_content) {
        Ok(value) => value,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("JSON 解析失败: {}", e)),
            }
        }
    };

    let yaml_value: YamlValue = match serde_yaml::to_value(&json_value) {
        Ok(value) => value,
        Err(e) => {
            return ConvertResult {
                success: false,
                output_path: None,
                error: Some(format!("转换为 YAML 失败: {}", e)),
            }
        }
    };

    let mut properties = HashMap::new();
    flatten_yaml(&yaml_value, "", &mut properties);

    let mut keys: Vec<&String> = properties.keys().collect();
    keys.sort();

    let properties_content = keys
        .iter()
        .map(|k| {
            let v = &properties[*k];
            format!(
                "{}={}",
                escape_properties_key(k),
                escape_properties_value(v)
            )
        })
        .collect::<Vec<_>>()
        .join("\n");

    match std::fs::write(output_path, properties_content) {
        Ok(()) => ConvertResult {
            success: true,
            output_path: Some(output_path.to_string_lossy().to_string()),
            error: None,
        },
        Err(e) => ConvertResult {
            success: false,
            output_path: None,
            error: Some(format!("写入 Properties 文件失败: {}", e)),
        },
    }
}
