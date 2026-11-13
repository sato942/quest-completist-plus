"""Zip the addon as QuestCompletistPlus/<files>, the layout the game and CurseForge expect.

    python package.py        # writes dist/QuestCompletistPlus-<version>.zip

Standard library only. Uploads nothing.
"""
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
NAME = "QuestCompletistPlus"
FILES = ["QuestCompletistPlus.toc", "QuestCompletistPlus.lua"]

toc = (ROOT / NAME / f"{NAME}.toc").read_text(encoding="utf-8")
version = re.search(r"^## Version: (\S+)", toc, re.M).group(1)
lua = (ROOT / NAME / f"{NAME}.lua").read_text(encoding="utf-8")
if f'local VERSION = "{version}"' not in lua:
    raise SystemExit(f"the .lua file's VERSION is not the TOC's {version}")
listed = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith("#")]
if sorted(listed + [f"{NAME}.toc"]) != sorted(FILES):
    raise SystemExit(f"the TOC lists {listed}; this script packs {FILES}")

out = ROOT / "dist" / f"{NAME}-{version}.zip"
out.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for name in FILES:
        z.write(ROOT / NAME / name, f"{NAME}/{name}")
print(out, out.stat().st_size, "bytes")
