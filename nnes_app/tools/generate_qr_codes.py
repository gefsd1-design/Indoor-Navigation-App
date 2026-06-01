from __future__ import annotations

from pathlib import Path

import qrcode

ROOM_IDS = [
    "TIH_Board",
    "Cafeteria",
    "CEO_Room",
    "Meeting_Room",
    "GNSS_Lab",
    "LiDAR_Lab",
    "Washrooms",
    "Computational_Lab",
    "Gym_Room",
    "GIS_Lab",
    "CV_Lab",
    "PD_Room",
    "Admin_Room",
    "GEO_Intel_Lab",
    "Discussion_Area",
]

BASE_DIR = Path(__file__).resolve().parents[1]
OUTPUT_DIR = BASE_DIR / "assets" / "qr"
ANCHOR_DIR = BASE_DIR / "assets" / "office_dataset" / "TIH Photos"
ANCHOR_OUTPUT_DIR = OUTPUT_DIR / "anchors"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
ANCHOR_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

for room_id in ROOM_IDS:
    qr = qrcode.QRCode(
        version=2,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=10,
        border=2,
    )
    qr.add_data(room_id)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    img.save(OUTPUT_DIR / f"{room_id}.png")

anchor_files = sorted(ANCHOR_DIR.glob("*.jpg"))
anchor_payloads = [item.stem for item in anchor_files]

for payload in anchor_payloads:
    qr = qrcode.QRCode(
        version=2,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=8,
        border=2,
    )
    qr.add_data(payload)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    img.save(ANCHOR_OUTPUT_DIR / f"{payload}.png")

html = [
    "<!doctype html>",
    "<html>",
    "<head>",
    "<meta charset=\"utf-8\" />",
    "<title>NNES QR Markers</title>",
    "<style>",
    "body { font-family: Arial, sans-serif; padding: 24px; }",
    ".grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px; }",
    ".card { border: 1px solid #ccc; padding: 16px; text-align: center; }",
    ".card img { width: 180px; height: 180px; }",
    ".label { margin-top: 8px; font-weight: bold; }",
    "</style>",
    "</head>",
    "<body>",
    "<h1>NNES QR Markers</h1>",
    "<div class=\"grid\">",
]

for room_id in ROOM_IDS:
    html.append("<div class=\"card\">")
    html.append(f"<img src=\"{room_id}.png\" alt=\"{room_id}\" />")
    html.append(f"<div class=\"label\">{room_id}</div>")
    html.append("</div>")

html.extend(["</div>", "<h2>Anchor Image QR Codes</h2>", "<div class=\"grid\">\n"])

for payload in anchor_payloads:
    html.append("<div class=\"card\">")
    html.append(f"<img src=\"anchors/{payload}.png\" alt=\"{payload}\" />")
    html.append(f"<div class=\"label\">{payload}</div>")
    html.append("</div>")

html.extend(["</div>", "</body>", "</html>"])

(OUTPUT_DIR / "qr_sheet.html").write_text("\n".join(html), encoding="utf-8")
print(
    f"Generated {len(ROOM_IDS)} room QR codes and {len(anchor_payloads)} anchor QR codes in {OUTPUT_DIR}"
)
