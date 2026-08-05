#!/usr/bin/env python3
"""Generate flat solid-color launcher icons with METERS wordmark."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
BRANDING = ROOT / "branding" / "icons"
MAC_SIZES = (16, 32, 64, 128, 256, 512, 1024)
APPS = {
    "dashboard": "dashboard_app",
    "entry": "entry_app",
    "admin": "admin_app",
}

# Solid backgrounds + contrasting METERS text.
ICON_SPECS = {
    # Admin: gray bg → white text
    "admin": {
        "bg": (107, 114, 128),  # slate gray
        "fg": (255, 255, 255),
    },
    # Dashboard (viewer): gold bg → deep ink text
    "dashboard": {
        "bg": (201, 162, 39),  # brand gold
        "fg": (44, 34, 8),  # dark on-accent
    },
    # Entry: blue bg → white text
    "entry": {
        "bg": (11, 31, 58),  # navy blue
        "fg": (255, 255, 255),
    },
}


def _load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def make_meter_icon(
    bg: tuple[int, int, int],
    fg: tuple[int, int, int],
    size: int = 1024,
) -> Image.Image:
    # Full-bleed solid square — OS applies its own mask/rounding.
    # Keep wordmark inside Android adaptive safe zone (~66% center).
    img = Image.new("RGBA", (size, size), (*bg, 255))
    draw = ImageDraw.Draw(img)
    text = "METERS"

    # -10% vs prior (0.78 / 0.209) for clearer mobile launcher wordmark.
    target_width = int(size * 0.702)
    font_size = int(size * 0.188)
    font = _load_font(font_size)
    while font_size > 8:
        bbox = draw.textbbox((0, 0), text, font=font)
        width = bbox[2] - bbox[0]
        if width <= target_width:
            break
        font_size -= 2
        font = _load_font(font_size)

    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    x = (size - text_w) // 2 - bbox[0]
    y = (size - text_h) // 2 - bbox[1]
    draw.text((x, y), text, font=font, fill=fg)
    return img


def make_dashboard_icon(size: int = 1024) -> Image.Image:
    spec = ICON_SPECS["dashboard"]
    return make_meter_icon(spec["bg"], spec["fg"], size)


def make_entry_icon(size: int = 1024) -> Image.Image:
    spec = ICON_SPECS["entry"]
    return make_meter_icon(spec["bg"], spec["fg"], size)


def make_admin_icon(size: int = 1024) -> Image.Image:
    spec = ICON_SPECS["admin"]
    return make_meter_icon(spec["bg"], spec["fg"], size)


GENERATORS = {
    "dashboard": make_dashboard_icon,
    "entry": make_entry_icon,
    "admin": make_admin_icon,
}


def write_macos_set(app_key: str, master: Image.Image) -> None:
    app_folder = APPS[app_key]
    target = (
        ROOT
        / "apps"
        / app_folder
        / "macos"
        / "Runner"
        / "Assets.xcassets"
        / "AppIcon.appiconset"
    )
    target.mkdir(parents=True, exist_ok=True)
    for px in MAC_SIZES:
        resized = master.resize((px, px), Image.Resampling.LANCZOS)
        path = target / f"app_icon_{px}.png"
        # Rewrite fully so Finder/Dock notice a new asset.
        if path.exists():
            path.unlink()
        resized.save(path, format="PNG")


def write_branding_assets(app_key: str, master: Image.Image) -> None:
    BRANDING.mkdir(parents=True, exist_ok=True)
    master.save(BRANDING / f"{app_key}_1024.png", format="PNG")

    app_folder = APPS[app_key]
    assets_dir = ROOT / "apps" / app_folder / "assets" / "branding"
    assets_dir.mkdir(parents=True, exist_ok=True)
    out = assets_dir / "app_icon_simple.png"
    if out.exists():
        out.unlink()
    master.save(out, format="PNG")


def write_windows_icon(app_key: str, master: Image.Image) -> None:
    app_folder = APPS[app_key]
    ico_path = (
        ROOT / "apps" / app_folder / "windows" / "runner" / "resources" / "app_icon.ico"
    )
    ico_path.parent.mkdir(parents=True, exist_ok=True)
    sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    frames = [master.resize(size, Image.Resampling.LANCZOS) for size in sizes]
    frames[0].save(
        ico_path,
        format="ICO",
        sizes=[frame.size for frame in frames],
        append_images=frames[1:],
    )


def main() -> None:
    for key, generator in GENERATORS.items():
        master = generator(1024)
        write_branding_assets(key, master)
        write_macos_set(key, master)
        write_windows_icon(key, master)
        print(f"Generated icons for {key}")


if __name__ == "__main__":
    main()
