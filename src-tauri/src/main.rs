#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::{Deserialize, Serialize};
use std::{fs, path::PathBuf, sync::Mutex};
use tauri::{
    menu::{MenuBuilder, MenuItemBuilder},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Emitter, Manager, State, WindowEvent,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
enum ClipKind {
    Text,
    Html,
    Image,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ClipboardPayload {
    kind: ClipKind,
    title: String,
    preview: String,
    text: Option<String>,
    html: Option<String>,
    image_data_url: Option<String>,
    source: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct StoredClip {
    id: String,
    kind: ClipKind,
    title: String,
    preview: String,
    text: Option<String>,
    html: Option<String>,
    image_data_url: Option<String>,
    source: String,
    #[serde(rename = "createdAt")]
    created_at: String,
    favorite: bool,
    pinned: bool,
}

#[derive(Default)]
struct ClipboardRuntimeState {
    listener_started: Mutex<bool>,
}

#[tauri::command]
fn load_saved_clips(app: AppHandle) -> Result<Vec<StoredClip>, String> {
    let path = storage_file_path(&app)?;
    if !path.exists() {
        return Ok(Vec::new());
    }

    let bytes = fs::read(&path).map_err(|err| format!("failed to read persisted clips: {err}"))?;
    if bytes.is_empty() {
        return Ok(Vec::new());
    }

    serde_json::from_slice(&bytes).map_err(|err| format!("failed to parse persisted clips: {err}"))
}

#[tauri::command]
fn save_clips(app: AppHandle, clips: Vec<StoredClip>) -> Result<(), String> {
    let path = storage_file_path(&app)?;
    let parent = path
        .parent()
        .ok_or_else(|| "failed to resolve persistence directory".to_string())?;

    fs::create_dir_all(parent)
        .map_err(|err| format!("failed to create persistence directory: {err}"))?;
    let payload = serde_json::to_vec_pretty(&clips)
        .map_err(|err| format!("failed to serialize persisted clips: {err}"))?;
    fs::write(&path, payload).map_err(|err| format!("failed to write persisted clips: {err}"))
}

#[tauri::command]
fn start_clipboard_listener(
    app: AppHandle,
    state: State<ClipboardRuntimeState>,
) -> Result<(), String> {
    {
        let mut started = state
            .listener_started
            .lock()
            .map_err(|_| "failed to lock listener state".to_string())?;

        if *started {
            return Ok(());
        }

        *started = true;
    }

    #[cfg(target_os = "macos")]
    {
        macos::start_clipboard_listener(app);
    }

    #[cfg(not(target_os = "macos"))]
    {
        app.emit(
            "clipboard-listener-error",
            "当前版本仅在 macOS 上启用了原生剪贴板监听。",
        )
        .map_err(|err| format!("failed to emit fallback listener message: {err}"))?;
    }

    Ok(())
}

fn storage_file_path(app: &AppHandle) -> Result<PathBuf, String> {
    let app_data_dir = app
        .path()
        .app_data_dir()
        .map_err(|err| format!("failed to resolve app data directory: {err}"))?;
    Ok(app_data_dir.join("clips.json"))
}

#[cfg(target_os = "macos")]
mod macos {
    use super::{ClipKind, ClipboardPayload};
    use base64::{engine::general_purpose::STANDARD, Engine as _};
    use objc2::rc::Retained;
    use objc2_app_kit::{
        NSPasteboard, NSPasteboardTypeHTML, NSPasteboardTypePNG, NSPasteboardTypeString,
    };
    use objc2_foundation::{NSData, NSString};
    use std::{thread, time::Duration};
    use tauri::{AppHandle, Emitter};

    pub fn start_clipboard_listener(app: AppHandle) {
        thread::spawn(move || {
            let pasteboard = NSPasteboard::generalPasteboard();
            let mut last_seen = pasteboard.changeCount() as i64;

            loop {
                let change_count = pasteboard.changeCount() as i64;

                if change_count != last_seen {
                    last_seen = change_count;

                    if let Ok(Some(payload)) = read_payload(&pasteboard) {
                        let _ = app.emit("clipboard-updated", payload);
                    }
                }

                thread::sleep(Duration::from_millis(300));
            }
        });
    }

    fn read_payload(pasteboard: &NSPasteboard) -> Result<Option<ClipboardPayload>, String> {
        if let Some(image) = pasteboard_data(pasteboard, unsafe { &NSPasteboardTypePNG }) {
            return Ok(Some(ClipboardPayload {
                kind: ClipKind::Image,
                title: "PNG image".into(),
                preview: "Image captured from system pasteboard".into(),
                text: None,
                html: None,
                image_data_url: Some(format!("data:image/png;base64,{}", STANDARD.encode(image))),
                source: "NSPasteboardTypePNG".into(),
            }));
        }

        if let Some(html) = pasteboard_string(pasteboard, unsafe { &NSPasteboardTypeHTML }) {
            let text = pasteboard_string(pasteboard, unsafe { &NSPasteboardTypeString });
            let preview = html
                .replace('\n', " ")
                .chars()
                .take(180)
                .collect::<String>();
            return Ok(Some(ClipboardPayload {
                kind: ClipKind::Html,
                title: first_line(&html, "HTML snippet"),
                preview,
                text,
                html: Some(html),
                image_data_url: None,
                source: "NSPasteboardTypeHTML".into(),
            }));
        }

        if let Some(text) = pasteboard_string(pasteboard, unsafe { &NSPasteboardTypeString }) {
            let preview = text.chars().take(180).collect::<String>();
            return Ok(Some(ClipboardPayload {
                kind: ClipKind::Text,
                title: first_line(&text, "Text clip"),
                preview,
                text: Some(text),
                html: None,
                image_data_url: None,
                source: "NSPasteboardTypeString".into(),
            }));
        }

        Ok(None)
    }

    fn pasteboard_string(pasteboard: &NSPasteboard, kind: &NSString) -> Option<String> {
        pasteboard
            .stringForType(kind)
            .map(|value| value.to_string())
            .filter(|value| !value.trim().is_empty())
    }

    fn pasteboard_data(pasteboard: &NSPasteboard, kind: &NSString) -> Option<Vec<u8>> {
        pasteboard
            .dataForType(kind)
            .map(data_to_vec)
            .filter(|value| !value.is_empty())
    }

    fn data_to_vec(data: Retained<NSData>) -> Vec<u8> {
        data.to_vec()
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

fn build_tray(app: &AppHandle) -> Result<(), tauri::Error> {
    let show = MenuItemBuilder::with_id("show", "显示主窗口").build(app)?;
    let quit = MenuItemBuilder::with_id("quit", "退出 ClipShelf").build(app)?;
    let menu = MenuBuilder::new(app).items(&[&show, &quit]).build()?;

    let mut tray_builder = TrayIconBuilder::with_id("clipshelf-tray")
        .menu(&menu)
        .tooltip("ClipShelf 正在后台运行，右键可退出")
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id().as_ref() {
            "show" => {
                if let Some(window) = app.get_webview_window("main") {
                    let _ = window.show();
                    let _ = window.unminimize();
                    let _ = window.set_focus();
                }
            }
            "quit" => {
                app.exit(0);
            }
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                ..
            } = event
            {
                if let Some(window) = tray.app_handle().get_webview_window("main") {
                    let _ = window.show();
                    let _ = window.unminimize();
                    let _ = window.set_focus();
                }
            }
        });

    if let Some(icon) = app.default_window_icon().cloned() {
        tray_builder = tray_builder.icon(icon);
    }

    tray_builder.build(app)?;

    Ok(())
}

fn main() {
    tauri::Builder::default()
        .manage(ClipboardRuntimeState::default())
        .setup(|app| {
            build_tray(app.handle())?;

            if let Some(window) = app.get_webview_window("main") {
                let window_clone = window.clone();
                window.on_window_event(move |event| {
                    if let WindowEvent::CloseRequested { api, .. } = event {
                        api.prevent_close();
                        let _ = window_clone.hide();
                    }
                });
            }

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            start_clipboard_listener,
            load_saved_clips,
            save_clips
        ])
        .run(tauri::generate_context!())
        .expect("error while running ClipShelf");
}
