"""Validate a tag and build client archives plus release metadata."""
import argparse
import json
import re
from pathlib import Path
from package import ROOT, VERSION, CLIENTS, build, artifact_name


def release(tag):
    if tag != "v" + VERSION:
        raise ValueError("Tag must match tools/package.py VERSION")
    core = (ROOT / "Core.lua").read_text(encoding="utf-8")
    if not re.search(r'S.version = "' + re.escape(VERSION) + r'"', core):
        raise ValueError("Core version does not match the release")
    for flavor, manifest in CLIENTS:
        toc = (ROOT / f"ShatterBar_{manifest}.toc").read_text(encoding="utf-8")
        if not re.search(r"^## Version: " + re.escape(VERSION) + r"$", toc, re.M):
            raise ValueError(f"Manifest version mismatch: {manifest}")
    build()
    releases = []
    flavors = {"retail": "mainline", "forever": "forever", "classic": "classic", "mists": "mists", "bcc": "bcc"}
    for flavor, manifest in CLIENTS:
        toc = (ROOT / f"ShatterBar_{manifest}.toc").read_text(encoding="utf-8")
        interface = int(re.search(r"^## Interface: (\d+)$", toc, re.M).group(1))
        releases.append({"filename": artifact_name(flavor), "nolib": False,
                         "metadata": [{"flavor": flavors[flavor], "interface": interface}]})
    (ROOT / "dist" / VERSION / "release.json").write_text(
        json.dumps({"releases": releases}, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", required=True)
    release(parser.parse_args().tag)
