#!/usr/bin/env python3
"""Download Impeller SDK archives from Flutter infra."""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
import urllib.error
import urllib.request
import zipfile
from pathlib import Path


DEFAULT_PLATFORMS = (
    "darwin-arm64",
    "darwin-x64",
    "linux-arm64",
    "linux-x64",
    "windows-arm64",
    "windows-x64",
)
DEFAULT_BASE_URL = "https://storage.googleapis.com/flutter_infra_release/flutter"
DEFAULT_RELEASES_URL = "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
DEFAULT_FLUTTER_REPO_RAW_URL = "https://raw.githubusercontent.com/flutter/flutter"
DEFAULT_CHANNEL = "stable"
RELEASE_CHANNELS = ("stable", "beta")
PLATFORM_DIRS = {
    "darwin-arm64": ("macos", "arm64"),
    "darwin-x64": ("macos", "x64"),
    "linux-arm64": ("linux", "arm64"),
    "linux-x64": ("linux", "x64"),
    "windows-arm64": ("windows", "arm64"),
    "windows-x64": ("windows", "x64"),
}


def read_json(url: str) -> dict[str, object]:
    with urllib.request.urlopen(url, timeout=30) as response:
        return json.load(response)


def latest_release(channel: str, releases_url: str) -> dict[str, object]:
    data = read_json(releases_url)
    current_release = data.get("current_release")
    if not isinstance(current_release, dict):
        raise RuntimeError(f"{releases_url} does not contain current_release metadata")

    framework_sha = current_release.get(channel)
    if not isinstance(framework_sha, str) or not framework_sha:
        raise RuntimeError(f"{releases_url} does not contain a {channel} release hash")

    releases = data.get("releases")
    if not isinstance(releases, list):
        raise RuntimeError(f"{releases_url} does not contain release entries")

    for release in releases:
        if not isinstance(release, dict):
            continue
        if release.get("hash") == framework_sha:
            return release

    return {"hash": framework_sha, "channel": channel}


def engine_hash_for_flutter(framework_sha: str, flutter_repo_raw_url: str) -> str:
    url = f"{flutter_repo_raw_url}/{framework_sha}/bin/internal/engine.version"
    with urllib.request.urlopen(url, timeout=30) as response:
        engine_sha = response.read().decode("utf-8").strip()
    if not engine_sha:
        raise RuntimeError(f"{url} is empty")
    return engine_sha


def artifact_exists(url: str) -> bool:
    request = urllib.request.Request(url, method="HEAD")
    try:
        with urllib.request.urlopen(request, timeout=30):
            return True
    except urllib.error.HTTPError as error:
        if error.code in {403, 404}:
            return False
        if error.code != 405:
            raise
    except urllib.error.URLError:
        raise

    request = urllib.request.Request(url, headers={"Range": "bytes=0-0"})
    try:
        with urllib.request.urlopen(request, timeout=30):
            return True
    except urllib.error.HTTPError as error:
        if error.code in {403, 404}:
            return False
        raise


def download_file(url: str, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=120) as response:
        with output.open("wb") as file:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                file.write(chunk)


def safe_extract_zip(zip_path: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    destination_root = destination.resolve()
    with zipfile.ZipFile(zip_path) as archive:
        for member in archive.infolist():
            target = (destination / member.filename).resolve()
            if destination_root != target and destination_root not in target.parents:
                raise RuntimeError(f"refusing to extract path outside destination: {member.filename}")
        archive.extractall(destination)


def copy_file(src: Path, dst: Path, force: bool) -> bool:
    if dst.exists() and not force:
        return False
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(src.read_bytes())
    return True


def first_existing(root: Path, names: tuple[str, ...]) -> Path | None:
    for name in names:
        matches = sorted(root.rglob(name))
        if matches:
            return matches[0]
    return None


def remove_tree(path: Path) -> None:
    if not path.exists():
        return
    for child in sorted(path.rglob("*"), reverse=True):
        if child.is_file() or child.is_symlink():
            child.unlink()
        elif child.is_dir():
            child.rmdir()
    path.rmdir()


def reset_staged_sdk(sdk_root: Path) -> None:
    for name in ("include", "lib", "archives"):
        remove_tree(sdk_root / name)
    for name in ("README.md", "LICENSE.sdk.md"):
        path = sdk_root / name
        if path.exists():
            path.unlink()


def stage_platform_sdk(zip_path: Path, platform: str, sdk_root: Path, force: bool, temp_root: Path) -> list[Path]:
    platform_dirs = PLATFORM_DIRS.get(platform)
    if not platform_dirs:
        raise RuntimeError(f"unknown platform mapping: {platform}")

    extract_dir = temp_root / platform
    safe_extract_zip(zip_path, extract_dir)

    copied: list[Path] = []
    header = first_existing(extract_dir, ("impeller.h",))
    if header and copy_file(header, sdk_root / "include" / "impeller.h", force):
        copied.append(sdk_root / "include" / "impeller.h")

    readme = first_existing(extract_dir, ("README.md",))
    if readme and copy_file(readme, sdk_root / "README.md", force):
        copied.append(sdk_root / "README.md")

    license_file = first_existing(extract_dir, ("LICENSE.sdk.md", "LICENSE", "LICENSE.md"))
    if license_file and copy_file(license_file, sdk_root / "LICENSE.sdk.md", force):
        copied.append(sdk_root / "LICENSE.sdk.md")

    os_dir, arch_dir = platform_dirs
    lib_dir = sdk_root / "lib" / os_dir / arch_dir
    for pattern in ("libimpeller.so", "libimpeller.dylib", "impeller.dll", "impeller.dll.lib"):
        for src in sorted(extract_dir.rglob(pattern)):
            dst = lib_dir / src.name
            if copy_file(src, dst, force):
                copied.append(dst)

    return copied


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--sha",
        help="Flutter engine commit hash. Defaults to the engine hash used by the latest release for --channel.",
    )
    parser.add_argument(
        "--channel",
        choices=RELEASE_CHANNELS,
        default=DEFAULT_CHANNEL,
        help="Flutter release channel used when --sha is omitted. Defaults to stable.",
    )
    parser.add_argument(
        "--releases-url",
        default=DEFAULT_RELEASES_URL,
        help="Flutter releases metadata URL used when --sha is omitted.",
    )
    parser.add_argument(
        "--flutter-repo-raw-url",
        default=DEFAULT_FLUTTER_REPO_RAW_URL,
        help="Raw Flutter repository URL used to read bin/internal/engine.version.",
    )
    parser.add_argument(
        "--base-url",
        default=DEFAULT_BASE_URL,
        help="Base URL that contains per-SHA Flutter artifacts.",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        help="Output directory. Defaults to tools/impeller_<sha8>.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing zip files.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the resolved SHA and artifact URLs without downloading.",
    )
    args = parser.parse_args()

    release = None
    framework_sha = None
    if args.sha:
        engine_sha = args.sha
    else:
        release = latest_release(args.channel, args.releases_url)
        framework_sha_value = release.get("hash")
        if not isinstance(framework_sha_value, str):
            raise RuntimeError(f"latest {args.channel} release does not contain a framework hash")
        framework_sha = framework_sha_value
        engine_sha = engine_hash_for_flutter(framework_sha, args.flutter_repo_raw_url)

    out_dir = args.out_dir or Path("tools") / f"impeller_{engine_sha[:8]}"
    sdk_root = out_dir

    print(f"Downloading Impeller SDK for Flutter engine SHA: {engine_sha}")
    if not args.sha:
        version = release.get("version") if release else None
        release_date = release.get("release_date") if release else None
        suffix = f" {version}" if isinstance(version, str) else ""
        print(f"Resolved from latest {args.channel} Flutter release{suffix}")
        if isinstance(release_date, str):
            print(f"Release date: {release_date}")
        print(f"Flutter framework SHA: {framework_sha}")
    print(f"Output directory: {out_dir}")
    print()

    if args.dry_run:
        temp_archive_dir = Path("<temp>")
        for platform in DEFAULT_PLATFORMS:
            url = f"{args.base_url}/{engine_sha}/{platform}/impeller_sdk.zip"
            output = temp_archive_dir / f"impeller_sdk_{platform}.zip"
            print(f"{platform}: {url} -> {output}")
        return 0

    reset_staged_sdk(sdk_root)

    downloaded = 0
    skipped = 0
    staged_files: set[Path] = set()
    with tempfile.TemporaryDirectory(prefix="impeller_sdk_") as temp_dir:
        temp_root = Path(temp_dir)
        archive_dir = temp_root / "archives"
        for platform in DEFAULT_PLATFORMS:
            url = f"{args.base_url}/{engine_sha}/{platform}/impeller_sdk.zip"
            output = archive_dir / f"impeller_sdk_{platform}.zip"

            print(f"Downloading {platform}... ", end="", flush=True)
            if not artifact_exists(url):
                print("SKIP (not found)")
                skipped += 1
                continue

            download_file(url, output)
            print("OK")
            downloaded += 1

            print(f"Staging {platform}... ", end="", flush=True)
            copied = stage_platform_sdk(output, platform, sdk_root, args.force, temp_root)
            staged_files.update(copied)
            print(f"OK ({len(copied)} files)")

    print()
    print(f"Done. Downloaded: {downloaded}, skipped: {skipped}")
    if staged_files:
        print()
        print(f"Staged SDK: {sdk_root}")
        for file in sorted(staged_files):
            print(file)

    return 0 if staged_files else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
