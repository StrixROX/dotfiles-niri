use std::collections::HashMap;
use std::process::{Command, Stdio};

use niri_ipc::socket::Socket;
use niri_ipc::{Event, Request, Response};

#[derive(PartialEq, Clone, Copy)]
enum BarState {
    Show,
    AutoHide,
}

fn show_bar(bar_name: &str, output: &str) {
    let _ = Command::new("noctalia")
        .args(["msg", "bar-auto-hide-set", "off", bar_name, output])
        .stdout(Stdio::null())
        .status();
    let _ = Command::new("noctalia")
        .args(["msg", "bar-show", "default", output])
        .stdout(Stdio::null())
        .status();
}

fn autohide_bar(bar_name: &str, output: &str) {
    let _ = Command::new("noctalia")
        .args(["msg", "bar-auto-hide-set", "on", bar_name, output])
        .stdout(Stdio::null())
        .status();
    let _ = Command::new("noctalia")
        .args(["msg", "bar-hide", "default", output])
        .stdout(Stdio::null())
        .status();
}

/// Re-queries niri for the current workspace/window state and fires
/// show_bar/autohide_bar for any output whose computed state changed.
fn evaluate(bar_name: &str, last_state: &mut HashMap<String, BarState>, overview_open: bool) {
    let mut socket = match Socket::connect() {
        Ok(s) => s,
        Err(e) => {
            eprintln!("error: failed to connect to niri socket: {e}");
            return;
        }
    };

    let reply = match socket.send(Request::Workspaces) {
        Ok(r) => r,
        Err(e) => {
            eprintln!("error: failed to query workspaces: {e}");
            return;
        }
    };

    let workspaces = match reply {
        Ok(Response::Workspaces(ws)) => ws,
        Ok(_) => {
            eprintln!("error: unexpected response to Workspaces request");
            return;
        }
        Err(e) => {
            eprintln!("error: niri returned an error: {e}");
            return;
        }
    };

    for ws in workspaces.iter().filter(|w| w.is_active) {
        let Some(output) = ws.output.clone() else {
            continue;
        };

        let has_windows = ws.active_window_id.is_some();
        let new_state = if overview_open {
            BarState::Show
        } else if has_windows {
            BarState::AutoHide
        } else {
            BarState::Show
        };

        let changed = last_state.get(&output) != Some(&new_state);
        if changed {
            last_state.insert(output.clone(), new_state);
            match new_state {
                BarState::AutoHide => autohide_bar(bar_name, &output),
                BarState::Show => show_bar(bar_name, &output),
            }
        }
    }
}

fn main() {
    let bar_name = match std::env::args().nth(1) {
        Some(name) => name,
        None => {
            let prog = std::env::args().next().unwrap_or_default();
            eprintln!("Usage: {prog} <bar_name>");
            std::process::exit(1);
        }
    };

    let mut last_state: HashMap<String, BarState> = HashMap::new();
    let mut overview_open = false;

    // Run once up front so initial state is correct before the first event.
    evaluate(&bar_name, &mut last_state, overview_open);

    let mut event_socket = match Socket::connect() {
        Ok(s) => s,
        Err(e) => {
            eprintln!("error: failed to connect to niri socket: {e}");
            std::process::exit(1);
        }
    };

    match event_socket.send(Request::EventStream) {
        Ok(Ok(Response::Handled)) => {}
        Ok(Ok(_)) => {
            eprintln!("error: unexpected response to EventStream request");
            std::process::exit(1);
        }
        Ok(Err(e)) => {
            eprintln!("error: niri returned an error: {e}");
            std::process::exit(1);
        }
        Err(e) => {
            eprintln!("error: failed to request event stream: {e}");
            std::process::exit(1);
        }
    }

    let mut read_event = event_socket.read_events();
    loop {
        let event = match read_event() {
            Ok(e) => e,
            Err(e) => {
                eprintln!("error: event stream closed: {e}");
                break;
            }
        };

        match event {
            Event::OverviewOpenedOrClosed { is_open } => {
                overview_open = is_open;
                evaluate(&bar_name, &mut last_state, overview_open);
            }
            Event::WorkspacesChanged { .. }
            | Event::WorkspaceActivated { .. }
            | Event::WindowsChanged { .. }
            | Event::WindowOpenedOrChanged { .. }
            | Event::WindowClosed { .. }
            | Event::WorkspaceActiveWindowChanged { .. } => {
                evaluate(&bar_name, &mut last_state, overview_open);
            }
            _ => {
                // Ignore other event types (KeyboardLayoutsChanged, ConfigLoaded, etc.)
            }
        }
    }
}
