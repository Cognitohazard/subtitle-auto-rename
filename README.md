# subtitle-auto-rename

Automatically rename subtitle files to match their corresponding video filenames for Plex-compatible naming.

Given a directory with videos named like `Show.S01E03.1080p.mkv` and subtitles named like `[03] Something.ass`, the script pairs them by episode number and renames the subtitle to `Show.S01E03.1080p.en.ass`.

## Usage

```
subs-rename.sh [OPTIONS] [DIRECTORY]
```

| Option | Description |
|---|---|
| `--dry-run`, `-n` | Preview renames without moving files |
| `--recursive`, `-r` | Search subdirectories recursively |
| `-h`, `--help` | Show help message |

If no directory is given, the current directory is used.

## Examples

```bash
# Preview what would be renamed
bash subs-rename.sh --dry-run /path/to/media

# Rename subtitles in the current directory
bash subs-rename.sh

# Recursively rename across season folders
bash subs-rename.sh -r /path/to/show
```

## Matching rules

- **Video pattern:** `S01E03`, `S02E15`, `S01E105`, etc.
- **Subtitle pattern:** `[03]`, `[15v2]`, `[105_flac]`, etc.
- Episode numbers are compared numerically, so `E05` matches `[05]`.
- In recursive mode, subtitles only match videos in the same directory.
- Existing files are never overwritten — conflicts are skipped and reported.

## Supported formats

| Videos | Subtitles |
|---|---|
| `.mkv`, `.mp4`, `.avi`, `.webm` | `.ass`, `.srt`, `.ssa`, `.sub`, `.vtt` |

## Output

After processing, the script prints a summary:

- Number of files renamed
- Number of skips (target already exists)
- Unmatched videos with no subtitle found
- Unmatched subtitles with no video found

## Tests

```bash
bash test-subs-rename.sh
```

## Requirements

Bash 4+ (uses associative arrays and `globstar`).
