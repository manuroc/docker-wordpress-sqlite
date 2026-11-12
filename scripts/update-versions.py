#!/usr/bin/env python3
"""Updates the WordPress version (and its SHA1) and the two bundled plugins to their latest stable releases.

Edits Dockerfile and README.md in place, prints a short summary, and writes `changed` and `summary` to the
GitHub Actions output file when it is available. Uses only the Python standard library.
"""
import hashlib
import json
import os
import re
import sys
import urllib.request

PLUGINS = ["sqlite-database-integration", "atec-cache-apcu"]
TIMEOUT = 60


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "docker-wordpress-sqlite-updater"})
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        return response.read()


def version_key(version):
    return tuple(int(part) for part in version.split("."))


def latest_wordpress():
    data = json.loads(fetch("https://api.wordpress.org/core/version-check/1.7/"))
    version = data["offers"][0]["version"]
    if not re.fullmatch(r"\d+(\.\d+)+", version):
        raise SystemExit(f"Unexpected WordPress version from the API: {version!r}")
    return version


def wordpress_sha1(version):
    sha1 = fetch(f"https://wordpress.org/wordpress-{version}.tar.gz.sha1").decode().split()[0]
    if not re.fullmatch(r"[0-9a-f]{40}", sha1):
        raise SystemExit(f"Unexpected checksum for WordPress {version}: {sha1!r}")
    # Verify against the real tarball, as the checksum file and the archive come from the same server
    digest = hashlib.sha1(fetch(f"https://wordpress.org/wordpress-{version}.tar.gz")).hexdigest()
    if digest != sha1:
        raise SystemExit(f"Checksum mismatch for WordPress {version}: {digest} != {sha1}")
    return sha1


def latest_plugin(slug):
    data = json.loads(fetch(f"https://api.wordpress.org/plugins/info/1.0/{slug}.json"))
    version = data["version"]
    if not re.fullmatch(r"\d+(\.\d+)+", version):
        raise SystemExit(f"Unexpected version for plugin {slug}: {version!r}")
    return version


def main():
    dockerfile = open("Dockerfile").read()
    readme = open("README.md").read()
    changes = []

    current = re.search(r"^ENV WORDPRESS_VERSION=(\S+)$", dockerfile, re.M).group(1)
    latest = latest_wordpress()
    if version_key(latest) > version_key(current):
        sha1 = wordpress_sha1(latest)
        dockerfile = re.sub(r"^ENV WORDPRESS_VERSION=\S+$", f"ENV WORDPRESS_VERSION={latest}", dockerfile, flags=re.M)
        dockerfile = re.sub(r"^ENV WORDPRESS_SHA1=\S+$", f"ENV WORDPRESS_SHA1={sha1}", dockerfile, flags=re.M)
        readme = re.sub(r"(_WordPress version currently installed:_ \*\*)[^*]+(\*\*)", rf"\g<1>{latest}\g<2>", readme)
        changes.append(f"WordPress {current} -> {latest}")

    for slug in PLUGINS:
        pattern = re.compile(rf"(plugin/{re.escape(slug)}\.)(\d+(?:\.\d+)+)(\.zip)")
        match = pattern.search(dockerfile)
        if not match:
            print(f"Plugin {slug} not found in the Dockerfile, skipping", file=sys.stderr)
            continue
        current_plugin, latest_plugin_version = match.group(2), latest_plugin(slug)
        if version_key(latest_plugin_version) > version_key(current_plugin):
            dockerfile = pattern.sub(rf"\g<1>{latest_plugin_version}\g<3>", dockerfile)
            changes.append(f"{slug} {current_plugin} -> {latest_plugin_version}")

    if changes:
        open("Dockerfile", "w").write(dockerfile)
        open("README.md", "w").write(readme)

    summary = "; ".join(changes) if changes else "Everything is up to date"
    print(summary)
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a") as handle:
            handle.write(f"changed={'true' if changes else 'false'}\n")
            handle.write(f"summary={summary}\n")


if __name__ == "__main__":
    main()
