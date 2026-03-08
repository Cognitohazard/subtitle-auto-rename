#!/bin/bash
# Test suite for subs-rename.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/subs-rename.sh"

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $desc"
        ((PASS++))
    else
        echo "  FAIL: $desc"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        ((FAIL++))
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "  PASS: $desc"
        ((PASS++))
    else
        echo "  FAIL: $desc"
        echo "    expected to contain: $needle"
        echo "    in: $haystack"
        ((FAIL++))
    fi
}

assert_file_exists() {
    local desc="$1" file="$2"
    if [[ -e "$file" ]]; then
        echo "  PASS: $desc"
        ((PASS++))
    else
        echo "  FAIL: $desc (file not found: $file)"
        ((FAIL++))
    fi
}

assert_file_not_exists() {
    local desc="$1" file="$2"
    if [[ ! -e "$file" ]]; then
        echo "  PASS: $desc"
        ((PASS++))
    else
        echo "  FAIL: $desc (file exists unexpectedly: $file)"
        ((FAIL++))
    fi
}

make_tmpdir() {
    mktemp -d "${TMPDIR:-/tmp}/subs-rename-test.XXXXXX"
}

# ==========================================
# TEST CASES
# ==========================================

test_basic_matching() {
    echo "TEST: Basic matching"
    local tmp
    tmp=$(make_tmpdir)

    touch "$tmp/Show.S01E03.1080p.mkv"
    touch "$tmp/[03] Something.ass"

    bash "$SCRIPT" "$tmp" > /dev/null 2>&1

    assert_file_exists "sub renamed to video base" "$tmp/Show.S01E03.1080p.en.ass"
    assert_file_not_exists "original sub removed" "$tmp/[03] Something.ass"

    rm -rf "$tmp"
}

test_multiple_episodes() {
    echo "TEST: Multiple episodes"
    local tmp
    tmp=$(make_tmpdir)

    touch "$tmp/Show.S01E01.720p.mkv"
    touch "$tmp/Show.S01E02.720p.mkv"
    touch "$tmp/Show.S01E03.720p.mkv"
    touch "$tmp/[01] Ep One.srt"
    touch "$tmp/[02] Ep Two.srt"
    touch "$tmp/[03] Ep Three.srt"

    local output
    output=$(bash "$SCRIPT" "$tmp" 2>&1)

    assert_file_exists "ep1 renamed" "$tmp/Show.S01E01.720p.en.srt"
    assert_file_exists "ep2 renamed" "$tmp/Show.S01E02.720p.en.srt"
    assert_file_exists "ep3 renamed" "$tmp/Show.S01E03.720p.en.srt"
    assert_contains "summary shows 3 renames" "Renamed: 3" "$output"

    rm -rf "$tmp"
}

test_episode_numbers_gt_99() {
    echo "TEST: Episode numbers > 99"
    local tmp
    tmp=$(make_tmpdir)

    touch "$tmp/Show.S01E105.mkv"
    touch "$tmp/[105] Big Number.ass"

    bash "$SCRIPT" "$tmp" > /dev/null 2>&1

    assert_file_exists "ep 105 renamed" "$tmp/Show.S01E105.en.ass"

    rm -rf "$tmp"
}

test_leading_zero_normalization() {
    echo "TEST: Leading zero normalization"
    local tmp
    tmp=$(make_tmpdir)

    touch "$tmp/Show.S01E05.mkv"
    touch "$tmp/[05] Title.srt"

    bash "$SCRIPT" "$tmp" > /dev/null 2>&1

    assert_file_exists "ep 05 matched" "$tmp/Show.S01E05.en.srt"

    rm -rf "$tmp"
}

test_overwrite_protection() {
    echo "TEST: Overwrite protection"
    local tmp
    tmp=$(make_tmpdir)

    touch "$tmp/Show.S01E01.mkv"
    touch "$tmp/[01] Sub.ass"
    echo "existing" > "$tmp/Show.S01E01.en.ass"

    local output
    output=$(bash "$SCRIPT" "$tmp" 2>&1)

    assert_contains "skip message shown" "Skipping" "$output"
    assert_contains "already exists noted" "already exists" "$output"
    # Original sub should still be there (not moved)
    assert_file_exists "original sub untouched" "$tmp/[01] Sub.ass"
    # Existing file should still have original content
    assert_eq "existing file not overwritten" "existing" "$(cat "$tmp/Show.S01E01.en.ass")"

    rm -rf "$tmp"
}

test_dry_run() {
    echo "TEST: Dry-run mode"
    local tmp
    tmp=$(make_tmpdir)

    touch "$tmp/Show.S01E01.mkv"
    touch "$tmp/[01] Sub.ass"

    local output
    output=$(bash "$SCRIPT" --dry-run "$tmp" 2>&1)

    assert_contains "dry run label shown" "DRY RUN" "$output"
    assert_contains "dry run summary" "Dry run" "$output"
    # File should NOT have been moved
    assert_file_exists "original sub still exists" "$tmp/[01] Sub.ass"
    assert_file_not_exists "renamed file not created" "$tmp/Show.S01E01.en.ass"

    rm -rf "$tmp"
}

test_unmatched_report() {
    echo "TEST: Unmatched report"
    local tmp
    tmp=$(make_tmpdir)

    touch "$tmp/Show.S01E01.mkv"
    touch "$tmp/Show.S01E02.mkv"
    touch "$tmp/[01] Sub.ass"
    touch "$tmp/[03] Orphan.srt"

    local output
    output=$(bash "$SCRIPT" "$tmp" 2>&1)

    assert_contains "unmatched video reported" "Unmatched videos" "$output"
    assert_contains "ep2 video listed" "S01E02" "$output"
    assert_contains "unmatched sub reported" "Unmatched subtitles" "$output"
    assert_contains "orphan sub listed" "[03]" "$output"

    rm -rf "$tmp"
}

test_extended_extensions() {
    echo "TEST: Extended extensions"
    local tmp
    tmp=$(make_tmpdir)

    touch "$tmp/Show.S01E01.avi"
    touch "$tmp/[01] Sub.ssa"
    touch "$tmp/Show.S01E02.webm"
    touch "$tmp/[02] Sub.sub"
    touch "$tmp/Show.S01E03.mkv"
    touch "$tmp/[03] Sub.vtt"

    bash "$SCRIPT" "$tmp" > /dev/null 2>&1

    assert_file_exists ".avi + .ssa works" "$tmp/Show.S01E01.en.ssa"
    assert_file_exists ".webm + .sub works" "$tmp/Show.S01E02.en.sub"
    assert_file_exists ".mkv + .vtt works" "$tmp/Show.S01E03.en.vtt"

    rm -rf "$tmp"
}

test_recursive_mode() {
    echo "TEST: Recursive mode"
    local tmp
    tmp=$(make_tmpdir)

    mkdir -p "$tmp/Season1"
    touch "$tmp/Season1/Show.S01E01.mkv"
    touch "$tmp/Season1/[01] Sub.ass"

    bash "$SCRIPT" --recursive "$tmp" > /dev/null 2>&1

    assert_file_exists "sub renamed in subdir" "$tmp/Season1/Show.S01E01.en.ass"

    rm -rf "$tmp"
}

test_recursive_same_directory_constraint() {
    echo "TEST: Recursive same-directory constraint"
    local tmp
    tmp=$(make_tmpdir)

    mkdir -p "$tmp/Season1" "$tmp/Season2"
    touch "$tmp/Season1/Show.S01E01.mkv"
    touch "$tmp/Season2/[01] Sub.ass"

    local output
    output=$(bash "$SCRIPT" --recursive "$tmp" 2>&1)

    # Sub in Season2 should NOT match video in Season1
    assert_file_not_exists "cross-dir rename blocked" "$tmp/Season1/Show.S01E01.en.ass"
    assert_file_exists "sub still in Season2" "$tmp/Season2/[01] Sub.ass"
    assert_contains "reports unmatched video" "Unmatched videos" "$output"
    assert_contains "reports unmatched sub" "Unmatched subtitles" "$output"

    rm -rf "$tmp"
}

test_no_files() {
    echo "TEST: No files (empty directory)"
    local tmp
    tmp=$(make_tmpdir)

    local output
    output=$(bash "$SCRIPT" "$tmp" 2>&1)
    local rc=$?

    assert_eq "exit code 0" "0" "$rc"
    assert_contains "shows Renamed: 0" "Renamed: 0" "$output"

    rm -rf "$tmp"
}

test_invalid_directory() {
    echo "TEST: Invalid directory"
    local output
    output=$(bash "$SCRIPT" "/nonexistent/dir/xyz" 2>&1)
    local rc=$?

    assert_eq "exit code 1" "1" "$rc"
    assert_contains "error message shown" "not a directory" "$output"
}

test_help_flag() {
    echo "TEST: Help flag"
    local output
    output=$(bash "$SCRIPT" --help 2>&1)
    local rc=$?

    assert_eq "exit code 0" "0" "$rc"
    assert_contains "shows usage" "Usage:" "$output"
    assert_contains "mentions dry-run" "--dry-run" "$output"
    assert_contains "mentions recursive" "--recursive" "$output"
}

# ==========================================
# RUN ALL TESTS
# ==========================================

echo "=== subs-rename.sh test suite ==="
echo ""

test_basic_matching
test_multiple_episodes
test_episode_numbers_gt_99
test_leading_zero_normalization
test_overwrite_protection
test_dry_run
test_unmatched_report
test_extended_extensions
test_recursive_mode
test_recursive_same_directory_constraint
test_no_files
test_invalid_directory
test_help_flag

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ $FAIL -gt 0 ]]; then
    exit 1
else
    echo "All tests passed!"
    exit 0
fi
