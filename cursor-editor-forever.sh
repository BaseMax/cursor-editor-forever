#!/bin/bash

parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --appimage)
                cursor_image="$2"
                shift 2
                ;;
            *)
                echo "Unrecognized argument: $1"
                echo "Correct usage: $0 --appimage /path/to/cursor.AppImage"
                exit 1
                ;;
        esac
    done

    if [ -z "$cursor_image" ]; then
        echo "Error: You must specify the AppImage path."
        echo "Correct usage: $0 --appimage /path/to/cursor.AppImage"
        exit 1
    fi

    if [ ! -f "$cursor_image" ]; then
        echo "Error: The specified AppImage file ($cursor_image) does not exist."
        exit 1
    fi
}

verify_tools() {
    for tool in uuidgen; do
        if ! command -v "$tool" &>/dev/null; then
            echo "Error: The tool '$tool' is missing. Please install it."
            exit 1
        fi
    done
}

create_mac_id() {
    local uid=$(uuidgen | tr '[:upper:]' '[:lower:]')
    uid=$(echo "$uid" | sed 's/.\{12\}\(.\)/4/')
    local rand_hex=$(echo "$RANDOM" | md5sum | cut -c1)
    local rand_num=$((16#$rand_hex))
    local hex_char=$(printf '%x' $(( ($rand_num & 0x3) | 0x8 )))
    uid=$(echo "$uid" | sed "s/.\{16\}\(.\)/$hex_char/")
    echo "$uid"
}

create_random_id() {
    local part1=$(uuidgen | tr -d '-')
    local part2=$(uuidgen | tr -d '-')
    echo "${part1}${part2}"
}

ensure_cursor_stopped() {
    while pgrep -i "Cursor" >/dev/null || pgrep -i "Cursor.app" >/dev/null; do
        echo "Cursor is currently active. Please shut it down to continue."
        sleep 1
    done
    echo "Cursor has stopped. Moving forward..."
}

refresh_telemetry() {
    local active_user=$(whoami)
    if [ -z "$active_user" ]; then
        echo "Error: Could not identify the current user."
        exit 1
    fi
    local user_dir=$(eval echo "~$active_user")
    local config_file="$user_dir/.config/Cursor/User/globalStorage/storage.json"

    machine_id=$(create_random_id)
    mac_id=$(create_mac_id)
    device_id=$(uuidgen)
    sqm_id="{$(uuidgen | tr '[:lower:]' '[:upper:]')}"

    if [ -f "$config_file" ]; then
        cp "$config_file" "${config_file}.backup" || {
            echo "Error: Could not create a backup of storage.json."
            exit 1
        }

        if command -v jq &>/dev/null; then
            jq --arg m "$machine_id" \
               --arg mm "$mac_id" \
               --arg d "$device_id" \
               --arg s "$sqm_id" \
               '.["telemetry.machineId"]=$m | .["telemetry.macMachineId"]=$mm | .["telemetry.devDeviceId"]=$d | .["telemetry.sqmId"]=$s' \
               "$config_file" > "${config_file}.new" && \
            mv "${config_file}.new" "$config_file" || {
                echo "Error: Failed to refresh storage.json."
                exit 1
            }
        else
            echo "Notice: jq is not available. Skipping storage.json update."
        fi
    else
        echo "Notice: storage.json not located. Skipping update."
    fi

    echo "New telemetry values applied:"
    echo "  Machine ID: $machine_id"
    echo "  Mac Machine ID: $mac_id"
    echo "  Device ID: $device_id"
    echo "  SQM ID: $sqm_id"
}

alter_appimage() {
    work_dir=$(mktemp -d)
    if [ -z "$work_dir" ] || [ ! -d "$work_dir" ]; then
        echo "Error: Temporary directory creation failed."
        exit 1
    fi

    local image_dir=$(dirname "$cursor_image")
    cd "$image_dir" || { echo "Error: Failed to access AppImage directory."; exit 1; }
    cd "$work_dir" || { echo "Error: Failed to access temporary directory."; exit 1; }

    echo "Unpacking AppImage..."
    if [ ! -d "squashfs-root" ]; then
        "$cursor_image" --appimage-extract >/dev/null || {
            echo "Error: AppImage extraction unsuccessful."
            rm -rf "$work_dir"
            exit 1
        }
    fi
    echo "Unpacked to: $work_dir/squashfs-root"

    local target_files=(
        "$work_dir/squashfs-root/resources/app/out/main.js"
        "$work_dir/squashfs-root/resources/app/out/vs/code/node/cliProcessMain.js"
    )

    for target in "${target_files[@]}"; do
        if [ ! -f "$target" ]; then
            echo "Notice: $target not found. Skipping."
            continue
        fi

        chmod u+w "$target" || {
            echo "Error: Unable to set write permissions on $target."
            rm -rf "$work_dir"
            exit 1
        }

        sed -i 's/"[^"]*\/etc\/machine-id[^"]*"/"uuidgen"/g' "$target" || {
            echo "Error: Modification of $target failed."
            rm -rf "$work_dir"
            exit 1
        }
        echo "Altered $target successfully."
    done
}

rebuild_appimage() {
    local tool_path="/tmp/appimagetool"

    if [ ! -f "$tool_path" ]; then
        echo "Fetching appimagetool..."
        if command -v curl &>/dev/null; then
            curl -sL -o "$tool_path" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$(uname -m).AppImage" || {
                echo "Error: Could not download appimagetool."
                rm -rf "$work_dir"
                exit 1
            }
        elif command -v wget &>/dev/null; then
            wget -O "$tool_path" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$(uname -m).AppImage" || {
                echo "Error: Could not download appimagetool."
                rm -rf "$work_dir"
                exit 1
            }
        else
            echo "Error: No download tool (curl/wget) found."
            rm -rf "$work_dir"
            exit 1
        fi
        chmod +x "$tool_path" || {
            echo "Error: Could not make appimagetool executable."
            rm -rf "$work_dir"
            exit 1
        }
        echo "appimagetool acquired at $tool_path"
    fi

    echo "Rebuilding AppImage..."
    ARCH=x86_64 "$tool_path" -n ./squashfs-root >/dev/null 2>&1 || {
        echo "Error: Rebuilding process failed."
        rm -rf "$work_dir"
        exit 1
    }

    local rebuilt_image=$(ls -t Cursor-*.AppImage 2>/dev/null | head -n1)
    if [ -z "$rebuilt_image" ]; then
        echo "Error: Rebuilt AppImage not found."
        rm -rf "$work_dir"
        exit 1
    fi

    mv -f "$rebuilt_image" "$cursor_image" || {
        echo "Error: Failed to replace the original AppImage."
        rm -rf "$work_dir"
        exit 1
    }
    echo "Rebuilt AppImage saved to $cursor_image"
}

remove_temp() {
    if [ -d "$work_dir" ]; then
        rm -rf "$work_dir"
        echo "Cleaned up temporary files."
    fi
}

main_process() {
    parse_arguments "$@"
    verify_tools
    ensure_cursor_stopped
    refresh_telemetry
    alter_appimage
    rebuild_appimage
    remove_temp
    echo "License reset finished! Start Cursor with $cursor_image"
}

main_process "$@"
