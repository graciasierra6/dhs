"""Decompose the supplied reference dashboard into portable build assets.

This is a one-time reverse-engineering helper. The normal build uses the
generated templates and image-bank JSON files and does not need Python.
"""

from __future__ import annotations

import base64
import csv
import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "reference" / "reference_dashboard.html"
CSS_OUT = ROOT / "assets" / "css" / "reference_dashboard.css"
JS_OUT = ROOT / "assets" / "js" / "reference_dashboard.template.js"
SHELL_OUT = ROOT / "assets" / "templates" / "reference_dashboard.template.html"
PREVALENCE_BANK_OUT = ROOT / "artifacts" / "profile_images_prevalence.json"
CHANGE_BANK_OUT = ROOT / "artifacts" / "profile_images_change.json"
IMAGE_MANIFEST_OUT = ROOT / "artifacts" / "profile_images_manifest.csv"
REFERENCE_MANIFEST_OUT = ROOT / "artifacts" / "reference_manifest.json"
PAYLOAD_DIR = ROOT / "artifacts" / "reference_payloads"
FEATURE_REFERENCE = ROOT / "data" / "reference" / "admin1_feature_reference.csv"


def extract_tag(raw: str, tag: str) -> tuple[str, int, int]:
    pattern = re.compile(rf"<{tag}(?:\s[^>]*)?>(.*?)</{tag}>", re.DOTALL | re.IGNORECASE)
    matches = list(pattern.finditer(raw))
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one <{tag}> block, found {len(matches)}")
    match = matches[0]
    return match.group(1), match.start(), match.end()


def extract_json_constant(script: str, name: str):
    pattern = re.compile(
        rf"(?m)^\s*const\s+{re.escape(name)}\s*=\s*(\{{.*?\}}|\[.*?\]);\s*$",
        re.DOTALL,
    )
    match = pattern.search(script)
    if not match:
        raise ValueError(f"Could not locate JSON constant: {name}")
    return json.loads(match.group(1)), match


def data_uri_metadata(data_uri: str) -> tuple[str, bytes, str]:
    match = re.fullmatch(r"data:([^;]+);base64,([A-Za-z0-9+/=]+)", data_uri)
    if not match:
        raise ValueError("Unsupported image data URI")
    mime = match.group(1)
    payload = base64.b64decode(match.group(2), validate=True)
    return mime, payload, hashlib.sha256(payload).hexdigest()


def main() -> None:
    raw = REFERENCE.read_text(encoding="utf-8")
    css, css_start, css_end = extract_tag(raw, "style")
    script, script_start, script_end = extract_tag(raw, "script")

    prevalence_bank, prevalence_match = extract_json_constant(script, "provinceImagesPrevalence")
    change_bank, change_match = extract_json_constant(script, "provinceImagesChange")
    if set(prevalence_bank) != set(change_bank):
        raise ValueError("Prevalence and change profile image banks have different areas")
    if len(prevalence_bank) != 74:
        raise ValueError(f"Expected 74 areas per image bank, found {len(prevalence_bank)}")

    payload_names = [
        "definitions",
        "indicatorRows",
        "classifications",
        "bivariateColors",
        "prevalenceRankBivariateColors",
        "statusLabels",
    ]
    payloads = {}
    payload_matches = {}
    for name in payload_names:
        value, match = extract_json_constant(script, name)
        payloads[name] = value
        payload_matches[name] = match

    js_template = script
    replacements = [
        (prevalence_match.start(1), prevalence_match.end(1), "{{PROVINCE_IMAGES_PREVALENCE}}"),
        (change_match.start(1), change_match.end(1), "{{PROVINCE_IMAGES_CHANGE}}"),
        (
            payload_matches["indicatorRows"].start(1),
            payload_matches["indicatorRows"].end(1),
            "{{INDICATOR_ROWS}}",
        ),
        (
            payload_matches["classifications"].start(1),
            payload_matches["classifications"].end(1),
            "{{CLASSIFICATIONS}}",
        ),
    ]
    for start, end, token in sorted(replacements, reverse=True):
        js_template = js_template[:start] + token + js_template[end:]

    shell = raw
    shell = shell[:script_start] + "<script>{{DASHBOARD_SCRIPT}}</script>" + shell[script_end:]
    shell = shell[:css_start] + "<style>{{DASHBOARD_CSS}}</style>" + shell[css_end:]
    missing_favicon_link = '<link rel="icon" type="image/png" href="favicon.png">'
    if shell.count(missing_favicon_link) != 1:
        raise ValueError("Expected exactly one unavailable relative favicon link")
    shell = shell.replace(missing_favicon_link, "")

    # The supplied file repeats the same 37 Nigeria path definitions twice.
    # Removing the identical duplicates preserves every rendered map while
    # restoring valid, unique DOM IDs in the reproducible build.
    seen_paths: dict[str, str] = {}
    removed_duplicate_paths = 0

    def unique_path(match: re.Match[str]) -> str:
        nonlocal removed_duplicate_paths
        path_id = match.group(1)
        tag = match.group(0)
        if path_id not in seen_paths:
            seen_paths[path_id] = tag
            return tag
        if seen_paths[path_id] != tag:
            raise ValueError(f"Duplicate path ID has different geometry: {path_id}")
        removed_duplicate_paths += 1
        return ""

    shell = re.sub(r'<path\s+id="([^"]+)"[^>]*>', unique_path, shell)
    if len(seen_paths) != 74 or removed_duplicate_paths != 37:
        raise ValueError(
            f"Expected 74 unique paths and 37 identical duplicates; found "
            f"{len(seen_paths)} unique and removed {removed_duplicate_paths}"
        )

    with FEATURE_REFERENCE.open("r", encoding="utf-8-sig", newline="") as handle:
        feature_rows = list(csv.DictReader(handle))
    slugs = {"DRC": "drc", "Ethiopia": "ethiopia", "Nigeria": "nigeria"}
    canonical_shape_id = {
        row["dashboard_name"]: f"#{slugs[row['country']]}-shape-{row['feature_index']}"
        for row in feature_rows
    }
    corrected_shape_links = 0

    def canonical_use(match: re.Match[str]) -> str:
        nonlocal corrected_shape_links
        tag = match.group(0)
        name_match = re.search(r'data-name="([^"]+)"', tag)
        href_match = re.search(r'\shref="([^"]+)"', tag)
        if not name_match or not href_match:
            raise ValueError("A map region is missing data-name or href")
        name = name_match.group(1)
        if name not in canonical_shape_id:
            raise ValueError(f"Map region is not in the boundary reference: {name}")
        target = canonical_shape_id[name]
        if href_match.group(1) != target:
            corrected_shape_links += 1
        tag = re.sub(r'\shref="[^"]+"', f' href="{target}"', tag, count=1)
        tag = re.sub(r'\sxlink:href="[^"]+"', f' xlink:href="{target}"', tag, count=1)
        return tag

    shell = re.sub(r'<use\s+class="map-region[^>]*>', canonical_use, shell)
    if corrected_shape_links != 43:
        raise ValueError(
            f"Expected to correct 43 reference name-to-shape links; corrected {corrected_shape_links}"
        )

    CSS_OUT.parent.mkdir(parents=True, exist_ok=True)
    JS_OUT.parent.mkdir(parents=True, exist_ok=True)
    SHELL_OUT.parent.mkdir(parents=True, exist_ok=True)
    PREVALENCE_BANK_OUT.parent.mkdir(parents=True, exist_ok=True)
    PAYLOAD_DIR.mkdir(parents=True, exist_ok=True)

    CSS_OUT.write_text(css, encoding="utf-8", newline="\n")
    JS_OUT.write_text(js_template, encoding="utf-8", newline="\n")
    SHELL_OUT.write_text(shell, encoding="utf-8", newline="\n")
    PREVALENCE_BANK_OUT.write_text(
        json.dumps(prevalence_bank, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
        newline="\n",
    )
    CHANGE_BANK_OUT.write_text(
        json.dumps(change_bank, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
        newline="\n",
    )
    for name, value in payloads.items():
        (PAYLOAD_DIR / f"{name}.json").write_text(
            json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8", newline="\n"
        )

    manifest_rows = []
    for chart_type, bank in (("prevalence", prevalence_bank), ("change", change_bank)):
        for area, data_uri in bank.items():
            mime, payload, digest = data_uri_metadata(data_uri)
            manifest_rows.append(
                {
                    "chart_type": chart_type,
                    "admin_name": area,
                    "mime_type": mime,
                    "bytes": len(payload),
                    "sha256": digest,
                }
            )
    with IMAGE_MANIFEST_OUT.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle, fieldnames=["chart_type", "admin_name", "mime_type", "bytes", "sha256"]
        )
        writer.writeheader()
        writer.writerows(manifest_rows)

    reference_manifest = {
        "reference_file": "reference/reference_dashboard.html",
        "reference_sha256": hashlib.sha256(REFERENCE.read_bytes()).hexdigest(),
        "reference_bytes": REFERENCE.stat().st_size,
        "profile_areas": len(prevalence_bank),
        "profile_images": len(manifest_rows),
        "indicator_rows": len(payloads["indicatorRows"]),
        "classifications": len(payloads["classifications"]),
        "svg_elements": len(re.findall(r"<svg\b", raw, flags=re.IGNORECASE)),
        "map_regions": len(re.findall(r"<use\b[^>]*class=\"[^\"]*map-region", raw, flags=re.IGNORECASE)),
        "external_data_requests": len(re.findall(r"\bfetch\s*\(", raw)),
        "unique_boundary_paths": len(seen_paths),
        "identical_duplicate_paths_removed": removed_duplicate_paths,
        "name_to_shape_links_corrected": corrected_shape_links,
        "unavailable_relative_favicon_links_removed": 1,
    }
    REFERENCE_MANIFEST_OUT.write_text(
        json.dumps(reference_manifest, indent=2), encoding="utf-8", newline="\n"
    )
    print(json.dumps(reference_manifest, indent=2))


if __name__ == "__main__":
    main()
