#!/bin/bash
shopt -s nullglob # Prevents errors if no files match a specific extension

# ==========================================
# CONFIGURATION PATTERNS
# The parentheses () capture the episode number so we can compare them.
# ==========================================

# Video Pattern: Looks for "S" followed by 2 digits, "E", then captures 2 digits.
# Matches S01E01, S02E15, etc.
VID_PATTERN="S[0-9]{2}E([0-9]{2})"

# Subtitle Pattern: Looks for an open bracket "[", then captures 2 digits.
# Matches [01], [15v2], [24_flac], etc.
SUB_PATTERN="\[([0-9]{2})"

# Plex language tag to append
LANG_TAG=".en"

# ==========================================

# Loop through common video formats
for vid in *.{mkv,mp4}; do
    # If the video matches the pattern, save the captured number
    if [[ "$vid" =~ $VID_PATTERN ]]; then
        ep="${BASH_REMATCH[1]}"
        
        # Loop through common subtitle formats
        for sub in *.{ass,srt}; do
            # If the subtitle matches its pattern, save the captured number
            if [[ "$sub" =~ $SUB_PATTERN ]]; then
                sub_ep="${BASH_REMATCH[1]}"
                
                # If the captured numbers match, we have a pair!
                if [[ "$ep" == "$sub_ep" ]]; then
                    # Strip the video extension and the subtitle extension
                    base_name="${vid%.*}"
                    sub_ext="${sub##*.}"
                    
                    # Build the new exact match name
                    new_name="${base_name}${LANG_TAG}.${sub_ext}"
                    
                    echo "Matched Episode $ep:"
                    echo "  -> $new_name"
                    mv "$sub" "$new_name"
                    break # Stop looking for this video's subtitle and move to the next video
                fi
            fi
        done
    fi
done
