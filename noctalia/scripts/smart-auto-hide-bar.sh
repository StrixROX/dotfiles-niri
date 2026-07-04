#!/usr/bin/bash
#
# smart-auto-hide-bar.sh
#
# When the active workspace on an output has no windows, shows the
# specified bar, else sets it to auto-hide.
#
# Watches niri's IPC event stream purely as a trigger, and on every
# relevant event re-queries `niri msg -j workspaces` to determine,
# independently for each output, whether that output's active
# workspace has windows or not. Runs a command whenever that state
# flips, per output.
#
# Keywords: niri, noctalia v5, jq, ipc
#
# Requires: jq
#
# Usage:
#   ./smart-auto-hide-bar.sh <bar_name>
#
set -uo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <bar_name>" >&2
    exit 1
fi
bar_name="$1"

# ---------------------------------------------------------------------------
# State: output -> "empty" / "nonempty"
# ---------------------------------------------------------------------------
declare -A last_state

evaluate() {
    local output has_windows state
    # For each output's active workspace: output, whether it has a window.
    while IFS=$'\t' read -r output has_windows; do
        [[ -z "$output" ]] && continue
        if [[ "$has_windows" == "true" ]]; then state="nonempty"; else state="empty"; fi
        if [[ "${last_state[$output]:-}" != "$state" ]]; then
            last_state["$output"]="$state"
            if [[ "$state" == "nonempty" ]]; then
                # Run when the output is "nonempty"
                noctalia msg bar-auto-hide-set on "$bar_name" "$output" > /dev/null
                noctalia msg bar-hide default "$output" > /dev/null
            else
                # Run when the output is "empty"
                noctalia msg bar-auto-hide-set off "$bar_name" "$output" > /dev/null
                noctalia msg bar-show default "$output" > /dev/null
            fi
        fi
    done < <(niri msg -j workspaces | jq -r '.[] | select(.is_active) | [.output, (.active_window_id != null)] | @tsv')
}

for dep in jq niri noctalia; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "error: $dep is required but not installed" >&2
        exit 1
    fi
done

# Run once up front so initial state is correct before the first event.
evaluate

niri msg --json event-stream | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    event_type=$(jq -r 'keys[0]' <<< "$line" 2> /dev/null) || continue
    case "$event_type" in
        WorkspacesChanged|WorkspaceActivated|WindowsChanged|WindowOpenedOrChanged|WindowClosed|WorkspaceActiveWindowChanged)
            evaluate
            ;;
        *)
            # Ignore other event types (KeyboardLayoutsChanged, ConfigLoaded, etc.)
            ;;
    esac
done
