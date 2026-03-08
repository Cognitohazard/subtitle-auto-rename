#!/bin/bash
shopt -s nullglob  # Prevents errors if no files match a specific extension
shopt -s globstar  # Enable ** for recursive directory matching

# ==========================================
# USAGE / OPTIONS
# ==========================================
DRY_RUN=false
RECURSIVE=false
TARGET_DIR="."

usage() {
    echo "Usage: $(basename "$0") [OPTIONS] [DIRECTORY]"
    echo ""
    echo "Rename subtitle files to match their corresponding video filenames"
    echo "for Plex-compatible naming (e.g. Show.S01E03.1080p.en.ass)."
    echo ""
    echo "Options:"
    echo "  --dry-run, -n     Preview renames without executing them"
    echo "  --recursive, -r   Search subdirectories recursively"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Arguments:"
    echo "  DIRECTORY          Directory to process (default: current directory)"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run|-n)  DRY_RUN=true; shift ;;
        --recursive|-r) RECURSIVE=true; shift ;;
        -h|--help)     usage; exit 0 ;;
        -*)            echo "Unknown option: $1"; usage; exit 1 ;;
        *)             TARGET_DIR="$1"; shift ;;
    esac
done

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: '$TARGET_DIR' is not a directory."
    exit 1
fi

# ==========================================
# CONFIGURATION PATTERNS
# The parentheses () capture the episode number so we can compare them.
# ==========================================

# Video Pattern: Looks for "S" followed by 2 digits, "E", then captures 2+ digits.
# Matches S01E01, S02E15, S01E105, etc.
VID_PATTERN="S[0-9]{2}E([0-9]{2,})"

# Subtitle Pattern: Looks for an open bracket "[", then captures 2+ digits.
# Matches [01], [15v2], [105_flac], etc.
SUB_PATTERN="\[([0-9]{2,})"

# Plex language tag to append
LANG_TAG=".en"

# Video and subtitle extensions to search for
VID_EXTS=("mkv" "mp4" "avi" "webm")
SUB_EXTS=("ass" "srt" "ssa" "sub" "vtt")

# ==========================================

# Build glob patterns based on recursive mode
build_file_list() {
    local dir="$1"
    shift
    local -a exts=("$@")
    local -a results=()

    for ext in "${exts[@]}"; do
        if $RECURSIVE; then
            results+=("$dir"/**/*."$ext")
        else
            results+=("$dir"/*."$ext")
        fi
    done
    printf '%s\n' "${results[@]}"
}

# Collect file lists into arrays
mapfile -t vid_files < <(build_file_list "$TARGET_DIR" "${VID_EXTS[@]}")
mapfile -t sub_files < <(build_file_list "$TARGET_DIR" "${SUB_EXTS[@]}")

# Track which files got matched for the unmatched report
declare -A matched_vids
declare -A matched_subs

rename_count=0
skip_count=0

# Loop through video files
for vid in "${vid_files[@]}"; do
    if [[ "$vid" =~ $VID_PATTERN ]]; then
        ep=$((10#${BASH_REMATCH[1]}))  # Normalize: strip leading zeros
        vid_dir="$(dirname "$vid")"

        # Loop through subtitle files
        for sub in "${sub_files[@]}"; do
            # Only match subtitles in the same directory as the video
            [[ "$(dirname "$sub")" != "$vid_dir" ]] && continue

            if [[ "$sub" =~ $SUB_PATTERN ]]; then
                sub_ep=$((10#${BASH_REMATCH[1]}))  # Normalize: strip leading zeros

                if [[ "$ep" -eq "$sub_ep" ]]; then
                    base_name="${vid%.*}"
                    sub_ext="${sub##*.}"
                    new_name="${base_name}${LANG_TAG}.${sub_ext}"

                    # Bug fix: don't overwrite existing files
                    if [[ -e "$new_name" ]]; then
                        echo "Skipping Episode $ep: '$new_name' already exists"
                        ((skip_count++))
                        break
                    fi

                    echo "Matched Episode $ep:"
                    if $DRY_RUN; then
                        echo "  [DRY RUN] $sub -> $new_name"
                    else
                        echo "  -> $new_name"
                        mv "$sub" "$new_name"
                    fi

                    matched_vids["$vid"]=1
                    matched_subs["$sub"]=1
                    ((rename_count++))
                    break
                fi
            fi
        done
    fi
done

# ==========================================
# SUMMARY & UNMATCHED REPORT
# ==========================================
echo ""
echo "--- Summary ---"
echo "Renamed: $rename_count"
[[ $skip_count -gt 0 ]] && echo "Skipped (already exists): $skip_count"
$DRY_RUN && echo "(Dry run — no files were actually moved)"

# Report unmatched videos
unmatched_vids=()
for vid in "${vid_files[@]}"; do
    if [[ "$vid" =~ $VID_PATTERN ]] && [[ -z "${matched_vids[$vid]}" ]]; then
        unmatched_vids+=("$vid")
    fi
done

if [[ ${#unmatched_vids[@]} -gt 0 ]]; then
    echo ""
    echo "Unmatched videos (no subtitle found):"
    for f in "${unmatched_vids[@]}"; do
        echo "  $f"
    done
fi

# Report unmatched subtitles
unmatched_subs=()
for sub in "${sub_files[@]}"; do
    if [[ "$sub" =~ $SUB_PATTERN ]] && [[ -z "${matched_subs[$sub]}" ]]; then
        unmatched_subs+=("$sub")
    fi
done

if [[ ${#unmatched_subs[@]} -gt 0 ]]; then
    echo ""
    echo "Unmatched subtitles (no video found):"
    for f in "${unmatched_subs[@]}"; do
        echo "  $f"
    done
fi
