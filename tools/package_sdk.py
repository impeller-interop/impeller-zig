#!/usr/bin/env python3
"""Build per-platform Zig packages for the standalone Impeller SDK."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path
from typing import Any

import fetch_sdk


SDK_DEPS_START = "        // BEGIN GENERATED IMPELLER SDK DEPS"
SDK_DEPS_END = "        // END GENERATED IMPELLER SDK DEPS"
DEFAULT_VERSION = "0.0.1"
PLATFORM_DEP_NAMES = {
    "darwin-arm64": "impeller_sdk_macos_arm64",
    "darwin-x64": "impeller_sdk_macos_x64",
    "linux-arm64": "impeller_sdk_linux_arm64",
    "linux-x64": "impeller_sdk_linux_x64",
    "windows-arm64": "impeller_sdk_windows_arm64",
    "windows-x64": "impeller_sdk_windows_x64",
}
PLATFORM_ASSET_NAMES = {
    "darwin-arm64": "impeller-sdk-macos-arm64.tar.gz",
    "darwin-x64": "impeller-sdk-macos-x64.tar.gz",
    "linux-arm64": "impeller-sdk-linux-arm64.tar.gz",
    "linux-x64": "impeller-sdk-linux-x64.tar.gz",
    "windows-arm64": "impeller-sdk-windows-arm64.tar.gz",
    "windows-x64": "impeller-sdk-windows-x64.tar.gz",
}


def write_package_zon(root: Path, name: str, version: str, fingerprint: str | None) -> None:
    fingerprint_line = f"    .fingerprint = {fingerprint},\n" if fingerprint else ""
    root.joinpath("build.zig.zon").write_text(
        f""".{{
    .name = .{name},
    .version = "{version}",
{fingerprint_line}    .minimum_zig_version = "0.16.0",
    .paths = .{{
        "build.zig.zon",
        "include",
        "lib",
        "README.md",
        "LICENSE.sdk.md",
    }},
}}
""",
        encoding="utf-8",
    )


def normalize_tar_member(member: tarfile.TarInfo) -> tarfile.TarInfo:
    member.uid = 0
    member.gid = 0
    member.uname = ""
    member.gname = ""
    member.mtime = 0
    return member


def create_tarball(package_root: Path, package_name: str, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(output, "w:gz", format=tarfile.PAX_FORMAT) as archive:
        archive.add(package_root, arcname=package_name, filter=normalize_tar_member)


def zig_fetch_hash(zig: str, tarball: Path) -> str:
    result = subprocess.run(
        [zig, "fetch", str(tarball)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"{zig} fetch failed for {tarball}:\n{result.stdout}{result.stderr}"
        )
    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if not lines:
        raise RuntimeError(f"{zig} fetch did not print a package hash for {tarball}")
    return lines[-1]


def suggested_fingerprint(zig: str, tarball: Path) -> str | None:
    result = subprocess.run(
        [zig, "fetch", str(tarball)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    output = result.stdout + result.stderr
    match = re.search(r"suggested value: (0x[0-9a-fA-F]+)", output)
    if match:
        return match.group(1)
    if result.returncode != 0:
        raise RuntimeError(f"{zig} fetch failed for {tarball}:\n{output}")
    return None


def release_url_base(repository: str, tag: str) -> str:
    return f"https://github.com/{repository}/releases/download/{tag}"


def dependency_snippet(assets: list[dict[str, str]]) -> str:
    lines: list[str] = []
    for asset in assets:
        lines.extend(
            [
                f"        .{asset['dep_name']} = .{{",
                f"            .url = \"{asset['url']}\",",
                f"            .hash = \"{asset['hash']}\",",
                "            .lazy = true,",
                "        },",
            ]
        )
    return "\n".join(lines)


def update_zon(path: Path, snippet: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    try:
        start = lines.index(SDK_DEPS_START)
        end = lines.index(SDK_DEPS_END)
    except ValueError as error:
        raise RuntimeError(f"{path} does not contain generated SDK dependency markers") from error
    if start >= end:
        raise RuntimeError(f"{path} has invalid generated SDK dependency markers")

    replacement = [SDK_DEPS_START]
    if snippet:
        replacement.extend(snippet.splitlines())
    replacement.append(SDK_DEPS_END)
    updated = lines[:start] + replacement + lines[end + 1 :]
    path.write_text("\n".join(updated) + "\n", encoding="utf-8")


def write_github_output(path: Path, values: dict[str, str]) -> None:
    with path.open("a", encoding="utf-8") as file:
        for key, value in values.items():
            file.write(f"{key}={value}\n")


def resolve_engine_sha(args: argparse.Namespace) -> tuple[str, dict[str, object] | None, str | None]:
    if args.sha:
        return args.sha, None, None

    release = fetch_sdk.latest_release(args.channel, args.releases_url)
    framework_sha_value = release.get("hash")
    if not isinstance(framework_sha_value, str):
        raise RuntimeError(f"latest {args.channel} release does not contain a framework hash")
    engine_sha = fetch_sdk.engine_hash_for_flutter(framework_sha_value, args.flutter_repo_raw_url)
    return engine_sha, release, framework_sha_value


def package_platform(
    *,
    platform: str,
    engine_sha: str,
    args: argparse.Namespace,
    temp_root: Path,
    release_base_url: str,
) -> dict[str, str]:
    dep_name = PLATFORM_DEP_NAMES[platform]
    asset_name = PLATFORM_ASSET_NAMES[platform]
    archive_url = f"{args.base_url}/{engine_sha}/{platform}/impeller_sdk.zip"
    zip_path = temp_root / "archives" / f"impeller_sdk_{platform}.zip"
    package_root = temp_root / "packages" / dep_name
    tarball = args.out_dir / asset_name

    print(f"Downloading {platform}... ", end="", flush=True)
    if not fetch_sdk.artifact_exists(archive_url):
        raise RuntimeError(f"Impeller SDK archive not found: {archive_url}")
    fetch_sdk.download_file(archive_url, zip_path)
    print("OK")

    print(f"Packaging {platform}... ", end="", flush=True)
    fetch_sdk.remove_tree(package_root)
    fetch_sdk.stage_platform_sdk(zip_path, platform, package_root, True, temp_root)
    write_package_zon(package_root, dep_name, args.version, None)
    create_tarball(package_root, dep_name, tarball)
    fingerprint = suggested_fingerprint(args.zig, tarball)
    if fingerprint:
        write_package_zon(package_root, dep_name, args.version, fingerprint)
        create_tarball(package_root, dep_name, tarball)
    package_hash = zig_fetch_hash(args.zig, tarball)
    print("OK")

    return {
        "platform": platform,
        "dep_name": dep_name,
        "asset_name": asset_name,
        "path": str(tarball),
        "url": f"{release_base_url}/{asset_name}",
        "hash": package_hash,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sha", help="Flutter engine commit hash. Defaults to the latest release for --channel.")
    parser.add_argument("--channel", choices=fetch_sdk.RELEASE_CHANNELS, default=fetch_sdk.DEFAULT_CHANNEL)
    parser.add_argument("--version", default=DEFAULT_VERSION, help="Version written into generated SDK package manifests.")
    parser.add_argument("--out-dir", type=Path, default=Path("dist"), help="Directory for generated tarballs.")
    parser.add_argument("--zig", default="zig", help="Zig executable used to compute package hashes.")
    parser.add_argument("--release-repository", default=os.environ.get("GITHUB_REPOSITORY", "KercyDing/zig-impeller"))
    parser.add_argument("--release-tag", help="GitHub release tag for generated asset URLs. Defaults to sdk-<engine-sha8>.")
    parser.add_argument("--release-url-base", help="Override the base URL used in generated dependency entries.")
    parser.add_argument("--update-zon", type=Path, help="Update generated SDK dependency entries in build.zig.zon.")
    parser.add_argument("--metadata-out", type=Path, help="Write generated SDK metadata JSON.")
    parser.add_argument("--github-output", type=Path, default=Path(os.environ["GITHUB_OUTPUT"]) if "GITHUB_OUTPUT" in os.environ else None)
    parser.add_argument("--releases-url", default=fetch_sdk.DEFAULT_RELEASES_URL)
    parser.add_argument("--flutter-repo-raw-url", default=fetch_sdk.DEFAULT_FLUTTER_REPO_RAW_URL)
    parser.add_argument("--base-url", default=fetch_sdk.DEFAULT_BASE_URL)
    args = parser.parse_args()

    engine_sha, release, framework_sha = resolve_engine_sha(args)
    release_tag = args.release_tag or f"sdk-{engine_sha[:8]}"
    base_url = args.release_url_base or release_url_base(args.release_repository, release_tag)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    metadata_out = args.metadata_out or args.out_dir / "sdk-metadata.json"

    print(f"Packaging Impeller SDK for Flutter engine SHA: {engine_sha}")
    if release:
        version = release.get("version")
        release_date = release.get("release_date")
        if isinstance(version, str):
            print(f"Flutter {args.channel}: {version}")
        if isinstance(release_date, str):
            print(f"Release date: {release_date}")
        print(f"Flutter framework SHA: {framework_sha}")
    print(f"Release tag: {release_tag}")
    print(f"Output directory: {args.out_dir}")
    print()

    assets: list[dict[str, str]] = []
    with tempfile.TemporaryDirectory(prefix="impeller_sdk_package_") as temp_dir:
        temp_root = Path(temp_dir)
        for platform in fetch_sdk.DEFAULT_PLATFORMS:
            assets.append(
                package_platform(
                    platform=platform,
                    engine_sha=engine_sha,
                    args=args,
                    temp_root=temp_root,
                    release_base_url=base_url,
                )
            )

    snippet = dependency_snippet(assets)
    snippet_path = args.out_dir / "lazy-deps.zigzon"
    snippet_path.write_text(snippet + "\n", encoding="utf-8")

    metadata: dict[str, Any] = {
        "engine_sha": engine_sha,
        "framework_sha": framework_sha,
        "channel": args.channel if not args.sha else None,
        "release": release,
        "release_tag": release_tag,
        "release_url_base": base_url,
        "assets": assets,
    }
    metadata_out.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    if args.update_zon:
        update_zon(args.update_zon, snippet)

    if args.github_output:
        write_github_output(
            args.github_output,
            {
                "engine_sha": engine_sha,
                "engine_sha8": engine_sha[:8],
                "release_tag": release_tag,
                "metadata": str(metadata_out),
                "deps": str(snippet_path),
            },
        )

    print()
    print(f"Wrote {snippet_path}")
    print(f"Wrote {metadata_out}")
    if args.update_zon:
        print(f"Updated {args.update_zon}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
