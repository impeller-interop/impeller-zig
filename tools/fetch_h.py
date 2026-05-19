#!/usr/bin/env python3
"""Fetch Impeller's standalone SDK header."""

from __future__ import annotations

import argparse
import json
import re
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parent
CURRENT_HEADER = TOOLS_DIR / "impeller.h"
DEFAULT_BASE_URL = "https://storage.googleapis.com/flutter_infra_release/flutter"
DEFAULT_RELEASES_URL = "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
DEFAULT_FLUTTER_REPO_RAW_URL = "https://raw.githubusercontent.com/flutter/flutter"
DEFAULT_ZON = Path("build.zig.zon")
SDK_DEP_NAME = "impeller_sdk"
HEADER_PLATFORMS = (
    "linux-x64",
    "darwin-arm64",
    "darwin-x64",
    "linux-arm64",
    "windows-x64",
    "windows-arm64",
)


def read_json(url: str) -> dict[str, object]:
    with urllib.request.urlopen(url, timeout=30) as response:
        return json.load(response)


def latest_stable_release() -> dict[str, object]:
    data = read_json(DEFAULT_RELEASES_URL)
    current_release = data.get("current_release")
    if not isinstance(current_release, dict):
        raise RuntimeError(f"{DEFAULT_RELEASES_URL} does not contain current_release metadata")

    framework_sha = current_release.get("stable")
    if not isinstance(framework_sha, str) or not framework_sha:
        raise RuntimeError(f"{DEFAULT_RELEASES_URL} does not contain a stable release hash")

    releases = data.get("releases")
    if not isinstance(releases, list):
        raise RuntimeError(f"{DEFAULT_RELEASES_URL} does not contain release entries")

    for release in releases:
        if isinstance(release, dict) and release.get("hash") == framework_sha:
            return release

    return {"hash": framework_sha, "channel": "stable"}


def engine_hash_for_flutter(framework_sha: str) -> str:
    url = f"{DEFAULT_FLUTTER_REPO_RAW_URL}/{framework_sha}/bin/internal/engine.version"
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

    request = urllib.request.Request(url, headers={"Range": "bytes=0-0"})
    try:
        with urllib.request.urlopen(request, timeout=30):
            return True
    except urllib.error.HTTPError as error:
        if error.code in {403, 404}:
            return False
        raise


def dependency_url(zon_text: str, dep_name: str) -> str:
    pattern = re.compile(
        rf"\.{re.escape(dep_name)}\s*=\s*\.{{(?P<body>.*?)^\s*}},",
        re.S | re.M,
    )
    match = pattern.search(zon_text)
    if not match:
        raise RuntimeError(f"could not find dependency `{dep_name}`")

    url_match = re.search(r'\.url\s*=\s*"(?P<url>[^"]+)"', match.group("body"))
    if not url_match:
        raise RuntimeError(f"dependency `{dep_name}` does not contain a url")
    return url_match.group("url")


def github_raw_url(package_url: str, path: str) -> str:
    if not package_url.startswith("git+"):
        raise RuntimeError(f"unsupported package url: {package_url}")

    parsed = urllib.parse.urlsplit(package_url[4:])
    if parsed.netloc != "github.com":
        raise RuntimeError(f"only GitHub package urls are supported: {package_url}")
    if not parsed.fragment:
        raise RuntimeError(f"package url does not pin a commit: {package_url}")

    repo = parsed.path.strip("/")
    if repo.endswith(".git"):
        repo = repo[:-4]
    return f"https://raw.githubusercontent.com/{repo}/{parsed.fragment}/{path}"


def write_url(url: str, output: Path) -> None:
    with urllib.request.urlopen(url, timeout=120) as response:
        output.write_bytes(response.read())


def write_header_from_zip(url: str, output: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="impeller_header_") as temp_name:
        zip_path = Path(temp_name) / "impeller_sdk.zip"
        with urllib.request.urlopen(url, timeout=120) as response:
            zip_path.write_bytes(response.read())

        with zipfile.ZipFile(zip_path) as archive:
            for member in archive.infolist():
                if not member.is_dir() and member.filename.endswith("impeller.h"):
                    output.write_bytes(archive.read(member))
                    return

    raise RuntimeError(f"could not find impeller.h in {url}")


def fetch_current() -> Path:
    zon_text = DEFAULT_ZON.read_text(encoding="utf-8")
    sdk_url = dependency_url(zon_text, SDK_DEP_NAME)
    write_url(github_raw_url(sdk_url, "sdk/include/impeller.h"), CURRENT_HEADER)
    return CURRENT_HEADER


def fetch_engine_sha(engine_sha: str) -> Path:
    output = TOOLS_DIR / f"impeller_{engine_sha[:8]}.h"
    for platform in HEADER_PLATFORMS:
        url = f"{DEFAULT_BASE_URL}/{engine_sha}/{platform}/impeller_sdk.zip"
        if not artifact_exists(url):
            continue
        write_header_from_zip(url, output)
        return output

    raise RuntimeError(f"could not find Impeller SDK header for engine SHA: {engine_sha}")


def fetch_latest() -> tuple[str, Path]:
    release = latest_stable_release()
    framework_sha = release.get("hash")
    if not isinstance(framework_sha, str):
        raise RuntimeError("latest stable release does not contain a framework hash")
    engine_sha = engine_hash_for_flutter(framework_sha)
    return engine_sha, fetch_engine_sha(engine_sha)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--current", action="store_true", help="Fetch the SDK header pinned by build.zig.zon into tools/impeller.h.")
    group.add_argument("--sha", help="Fetch the SDK header for a Flutter engine commit into tools/impeller_<sha8>.h.")
    args = parser.parse_args()

    if args.current:
        output = fetch_current()
        print(f"Wrote {output}")
        return 0

    if args.sha:
        output = fetch_engine_sha(args.sha)
        print(f"Wrote {output}")
        return 0

    engine_sha, output = fetch_latest()
    print(f"Resolved latest stable engine SHA: {engine_sha}")
    print(f"Wrote {output}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
