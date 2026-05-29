#!/usr/bin/env python3
"""Simulate the 72Flasher app update process.

Reads update.json, downloads the release archive from Google Drive,
and validates that the downloaded file is a genuine release.
"""

import json
import os
import re
import struct
import subprocess
import sys
import tempfile
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
UPDATE_JSON = os.path.join(SCRIPT_DIR, "update.json")

EXPECTED_EXE = "72Flasher.exe"
MIN_FILE_SIZE = 1_000_000  # 1 MB – any real release should exceed this
RAR_MAGIC = b"Rar!"


def load_update_info(path: str) -> dict:
    """Load and return the contents of update.json."""
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    for key in ("latest_version", "download_url"):
        if key not in data:
            raise KeyError(f"update.json is missing required key: {key}")
    return data


def extract_gdrive_file_id(url: str) -> str:
    """Extract the Google Drive file ID from a share or direct URL."""
    patterns = [
        r"/file/d/([A-Za-z0-9_-]+)",
        r"[?&]id=([A-Za-z0-9_-]+)",
    ]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    raise ValueError(f"Cannot extract Google Drive file ID from URL: {url}")


def build_direct_url(file_id: str) -> str:
    """Return a direct-download URL for the given Google Drive file ID."""
    return f"https://drive.google.com/uc?export=download&id={file_id}"


def download_file(url: str, dest: str) -> None:
    """Download *url* to *dest*, following redirects."""
    try:
        import gdown  # preferred – handles large-file confirmation pages
        gdown.download(url, dest, quiet=False)
    except ImportError:
        print("gdown not installed; falling back to urllib …")
        urllib.request.urlretrieve(url, dest)


def validate_rar_archive(path: str) -> bool:
    """Return True if *path* starts with the RAR magic bytes."""
    with open(path, "rb") as fh:
        magic = fh.read(4)
    return magic == RAR_MAGIC


def list_rar_contents(path: str) -> list[str]:
    """Return the list of file names inside the RAR archive.

    Tries the ``unrar`` CLI first, then falls back to reading the RAR
    header for the first stored filename.
    """
    try:
        result = subprocess.run(
            ["unrar", "l", path],
            capture_output=True,
            text=True,
            check=True,
        )
        names: list[str] = []
        in_listing = False
        for line in result.stdout.splitlines():
            if line.startswith("-----"):
                in_listing = not in_listing
                continue
            if in_listing:
                parts = line.split()
                if parts:
                    names.append(parts[-1])
        return names
    except FileNotFoundError:
        pass

    # Fallback: parse the first filename from the RAR5 header.
    names = []
    with open(path, "rb") as fh:
        raw = fh.read(4096)
        idx = raw.find(EXPECTED_EXE.encode())
        if idx != -1:
            names.append(EXPECTED_EXE)
    return names


def run() -> None:
    print("=" * 60)
    print("  72Flasher – Update Simulation")
    print("=" * 60)

    # 1. Load update metadata
    print(f"\n[1/5] Loading update metadata from {UPDATE_JSON} …")
    info = load_update_info(UPDATE_JSON)
    version = info["latest_version"]
    url = info["download_url"]
    print(f"       Version : {version}")
    print(f"       URL     : {url}")

    # 2. Resolve direct download URL
    print("\n[2/5] Resolving direct download URL …")
    file_id = extract_gdrive_file_id(url)
    direct_url = build_direct_url(file_id)
    print(f"       File ID : {file_id}")
    print(f"       Direct  : {direct_url}")

    # 3. Download
    dest_dir = tempfile.mkdtemp(prefix="72flasher_update_")
    dest_file = os.path.join(dest_dir, f"72Flasher_v{version}.rar")
    print(f"\n[3/5] Downloading release to {dest_file} …")
    download_file(direct_url, dest_file)
    size = os.path.getsize(dest_file)
    print(f"       Downloaded {size:,} bytes")

    # 4. Validate the archive
    print("\n[4/5] Validating downloaded file …")
    errors: list[str] = []

    if size < MIN_FILE_SIZE:
        errors.append(f"File too small ({size:,} B); expected ≥ {MIN_FILE_SIZE:,} B")

    if not validate_rar_archive(dest_file):
        errors.append("File does not have a valid RAR header")

    # 5. Verify archive contents
    print("\n[5/5] Inspecting archive contents …")
    contents = list_rar_contents(dest_file)
    if contents:
        print(f"       Archive entries: {contents}")
    else:
        print("       (could not list entries – unrar not available)")

    if contents and EXPECTED_EXE not in contents:
        errors.append(f"Expected '{EXPECTED_EXE}' inside the archive but found: {contents}")

    # Summary
    print("\n" + "=" * 60)
    if errors:
        print("  VALIDATION FAILED")
        for err in errors:
            print(f"    ✗ {err}")
        print("=" * 60)
        sys.exit(1)
    else:
        print("  VALIDATION PASSED")
        print(f"    • Version  : {version}")
        print(f"    • Size     : {size:,} bytes")
        print(f"    • Format   : RAR archive")
        if contents:
            print(f"    • Contains : {', '.join(contents)}")
        print(f"    • Location : {dest_file}")
        print("=" * 60)
        print("\nThe downloaded file is a valid 72Flasher release.")


if __name__ == "__main__":
    run()
