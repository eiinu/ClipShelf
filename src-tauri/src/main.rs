#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::Serialize;

#[derive(Debug, Serialize)]
#[serde(rename_all = "lowercase")]
enum ClipKind {
    Text,
    Html,
    Image,
}

#[derive(Debug, Serialize)]
struct ClipboardPayload {
    kind: ClipKind,
    title: String,
    preview: String,
    text: Option<String>,
    html: Option<String>,
    image_data_url: Option<String>,
    source: String,
}

#[tauri::command]
fn read_clipboard_snapshot() -> Result<Option<ClipboardPayload>, String> {
    #[cfg(target_os = "macos")]
    {
        macos::read_clipboard_snapshot()
    }

    #[cfg(not(target_os = "macos"))]
    {
        Ok(Some(ClipboardPayload {
            kind: ClipKind::Text,
            title: "macOS only demo".into(),
            preview: "This demo currently uses macOS pbpaste detection only.".into(),
            text: Some("Run ClipShelf on macOS to enable live clipboard capture.".into()),
            html: None,
            image_data_url: None,
            source: "fallback".into(),
        }))
    }
}

#[cfg(target_os = "macos")]
mod macos {
    use super::{ClipKind, ClipboardPayload};
    use base64::{engine::general_purpose::STANDARD, Engine as _};
    use std::process::Command;

    pub fn read_clipboard_snapshot() -> Result<Option<ClipboardPayload>, String> {
        if let Some(image) = pbpaste_bytes("png")? {
            return Ok(Some(ClipboardPayload {
                kind: ClipKind::Image,
                title: "PNG image".into(),
                preview: "Image captured from system clipboard".into(),
                text: None,
                html: None,
                image_data_url: Some(format!("data:image/png;base64,{}", STANDARD.encode(image))),
                source: "pbpaste -Prefer png".into(),
            }));
        }

        if let Some(html) = pbpaste_text("html")? {
            let preview = html
                .replace('\n', " ")
                .chars()
                .take(180)
                .collect::<String>();
            return Ok(Some(ClipboardPayload {
                kind: ClipKind::Html,
                title: first_line(&html, "HTML snippet"),
                preview,
                text: None,
                html: Some(html),
                image_data_url: None,
                source: "pbpaste -Prefer html".into(),
            }));
        }

        if let Some(text) = pbpaste_text("txt")? {
            let preview = text.chars().take(180).collect::<String>();
            return Ok(Some(ClipboardPayload {
                kind: ClipKind::Text,
                title: first_line(&text, "Text clip"),
                preview,
                text: Some(text),
                html: None,
                image_data_url: None,
                source: "pbpaste -Prefer txt".into(),
            }));
        }

        Ok(None)
    }

    fn pbpaste_text(preference: &str) -> Result<Option<String>, String> {
        let output = Command::new("pbpaste")
            .args(["-Prefer", preference])
            .output()
            .map_err(|err| format!("failed to execute pbpaste ({preference}): {err}"))?;

        if !output.status.success() || output.stdout.is_empty() {
            return Ok(None);
        }

        let value = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if value.is_empty() {
            return Ok(None);
        }

        Ok(Some(value))
    }

    fn pbpaste_bytes(preference: &str) -> Result<Option<Vec<u8>>, String> {
        let output = Command::new("pbpaste")
            .args(["-Prefer", preference])
            .output()
            .map_err(|err| format!("failed to execute pbpaste ({preference}): {err}"))?;

        if !output.status.success() || output.stdout.is_empty() {
            return Ok(None);
        }

        Ok(Some(output.stdout))
    }

    fn first_line(content: &str, fallback: &str) -> String {
        content
            .lines()
            .find(|line| !line.trim().is_empty())
            .map(|line| line.trim().chars().take(48).collect::<String>())
            .filter(|line| !line.is_empty())
            .unwrap_or_else(|| fallback.to_string())
    }
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![read_clipboard_snapshot])
        .run(tauri::generate_context!())
        .expect("error while running ClipShelf");
}
