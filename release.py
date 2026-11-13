"""Upload the packed addon to its CurseForge project ("Quest Completist Plus").

    python package.py                                   # first: writes dist/QuestCompletistPlus-<version>.zip
    python release.py --project <id>                    # dry run: checks the zip, the token, and the game version
    python release.py --project <id> --upload           # uploads the file

The token is read from the CURSEFORGE_API_TOKEN environment variable and never printed.
The file's changelog is that version's section of CHANGELOG.md. Standard library only.
"""
import argparse
import json
import os
import re
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent
NAME = "QuestCompletistPlus"
API = "https://wow.curseforge.com/api"
GAME_VERSION = "1.60.1"  # CurseForge's name for the WoW Forever version


def request(url, data=None, headers=None):
    token = os.environ.get("CURSEFORGE_API_TOKEN", "")
    if not token:
        raise SystemExit("CURSEFORGE_API_TOKEN is not set")
    req = urllib.request.Request(url, data=data, headers={"X-Api-Token": token, **(headers or {})})
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def changelog(version):
    text = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    match = re.search(rf"^## {re.escape(version)}\b.*?\n(.*?)(?=^## |\Z)", text, re.M | re.S)
    if not match or not match.group(1).strip():
        raise SystemExit(f"CHANGELOG.md has no section for {version}")
    return match.group(1).strip()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--project", type=int, required=True, help="the CurseForge project's number")
    ap.add_argument("--upload", action="store_true")
    ap.add_argument("--game-version", default=GAME_VERSION)
    ap.add_argument("--release-type", choices=["alpha", "beta", "release"], default="release")
    args = ap.parse_args()

    toc = (ROOT / NAME / f"{NAME}.toc").read_text(encoding="utf-8")
    version = re.search(r"^## Version: (\S+)", toc, re.M).group(1)
    path = ROOT / "dist" / f"{NAME}-{version}.zip"
    if not path.is_file():
        raise SystemExit(f"{path} is missing: run python package.py")
    notes = changelog(version)
    matches = [v for v in request(f"{API}/game/versions") if v.get("name") == args.game_version]
    if len(matches) != 1:
        raise SystemExit(f"game version {args.game_version!r} matched {len(matches)} entries")
    print(f"{path.name}, {path.stat().st_size} bytes, game version {args.game_version} (id {matches[0]['id']}), "
          f"{args.release_type}, project {args.project}")
    print("changelog:")
    print(notes)
    if not args.upload:
        print("dry run: nothing uploaded")
        return

    boundary = uuid.uuid4().hex
    metadata = json.dumps({"changelog": notes, "changelogType": "markdown",
                           "displayName": f"Quest Completist Plus {version}",
                           "gameVersions": [matches[0]["id"]], "releaseType": args.release_type})
    body = b"".join([
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"metadata\"\r\n\r\n{metadata}\r\n".encode("utf-8"),
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{path.name}\"\r\n"
        "Content-Type: application/zip\r\n\r\n".encode("utf-8"),
        path.read_bytes(),
        f"\r\n--{boundary}--\r\n".encode("utf-8"),
    ])
    result = request(f"{API}/projects/{args.project}/upload-file", body,
                     {"Content-Type": f"multipart/form-data; boundary={boundary}"})
    print(f"uploaded: CurseForge file id {result.get('id')}")


if __name__ == "__main__":
    main()
