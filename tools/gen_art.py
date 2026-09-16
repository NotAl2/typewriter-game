"""Generate every sprite in the game, plus the GDScript geometry constants.

    python tools/gen_art.py            regenerate all art
    python tools/gen_art.py --preview  also write a full-scene composite

Output is deterministic: the same source produces byte-identical PNGs, so a
tweak to one prop leaves the rest of the diff clean.

Every file written here is drop-in replaceable by hand-drawn art at the same
path and size - see ASSETS.md for the manifest.
"""

import json
import os
import sys

import layout as L
import gen_font
import art_room
import art_typewriter
import art_props
from palette import C
from pixel import Canvas

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
ART = os.path.join(ROOT, "assets", "art")
SCRIPTS = os.path.join(ROOT, "scripts")

MANIFEST = []


def save(name, cv):
    os.makedirs(ART, exist_ok=True)
    path = os.path.join(ART, name + ".png")
    cv.save(path)
    MANIFEST.append({"name": name, "w": cv.w, "h": cv.h})
    return path


def write_layout_gd():
    os.makedirs(SCRIPTS, exist_ok=True)
    path = os.path.join(SCRIPTS, "Layout.gd")
    with open(path, "w", newline="\n") as f:
        f.write(L.as_gdscript())
    return path


def write_manifest():
    path = os.path.join(ART, "manifest.json")
    with open(path, "w") as f:
        json.dump({"sprites": sorted(MANIFEST, key=lambda m: m["name"])}, f,
                  indent=1)
    return path


def load(name):
    from PIL import Image
    im = Image.open(os.path.join(ART, name + ".png")).convert("RGBA")
    cv = Canvas(im.width, im.height)
    cv.img = im
    cv.px = im.load()
    return cv


def compose_scene(state="typing"):
    """Assemble the desk exactly as Desk.tscn does, for art review.

    This is a mirror of the scene graph, not the scene itself - if the two ever
    disagree, the scene wins and this needs updating.
    """
    sc = Canvas(L.VIEW_W, L.VIEW_H)
    sc.blit(load("bg_room"), 0, 0)
    sc.blit(load("desk"), 0, L.DESK_TOP_Y)

    # --- back desk props ---
    sc.blit(load("paper_stack"), L.PAPER_STACK_X, L.PAPER_STACK_Y)
    sc.blit(load("photo_frame"), L.PHOTO_X, L.PHOTO_Y)
    sc.blit(load("journal"), L.JOURNAL_X, L.JOURNAL_Y)
    sc.blit(load("candlestick"), L.CANDLE_X, L.CANDLE_Y)
    flame = load("flame")
    sc.blit(flame.sub(0, 0, L.FLAME_W, L.FLAME_H), L.FLAME_X, L.FLAME_Y)

    # --- the machine, back to front ---
    rows_typed = 3
    cols_typed = 11
    car_x = L.CARRIAGE_HOME_X - cols_typed * L.CHAR_ADV

    paper_visible = L.PAGE_MARGIN_TOP + rows_typed * L.LINE_H
    sheet_img = load("paper_sheet")
    sc.blit(sheet_img.sub(0, 0, L.SHEET_W, paper_visible),
            car_x + L.CARRIAGE_W // 2 - L.SHEET_W // 2,
            L.STRIKE_Y - paper_visible)

    sc.blit(load("tw_platen"), car_x + L.PLATEN_INSET_X, L.PLATEN_Y)
    sc.blit(load("tw_carriage"), car_x, L.CARRIAGE_Y)
    knob = load("tw_knob")
    kc = knob.h
    sc.blit(knob.sub(0, 0, kc, kc), car_x - kc // 2 + 4, L.PLATEN_Y - 2)
    sc.blit(knob.sub(0, 0, kc, kc), car_x + L.CARRIAGE_W - kc // 2 - 4,
            L.PLATEN_Y - 2)
    sc.blit(load("tw_return_lever"), car_x + L.RETURN_LEVER_OX,
            L.CARRIAGE_Y + L.RETURN_LEVER_OY)

    sc.blit(load("tw_basket"), L.BASKET_CX - L.BASKET_W // 2,
            L.BASKET_PIVOT_Y - L.BASKET_H)

    if state == "jam":
        jam = load("tw_typebar_jam")
        sc.blit(jam, L.BASKET_CX - jam.w // 2,
                L.BASKET_PIVOT_Y - jam.h // 2)
    else:
        sw = load("tw_typebar_swing")
        fw = sw.h
        f = sw.sub((L.TYPEBAR_FRAMES - 1) * fw, 0, fw, fw)
        sc.blit(f, L.BASKET_CX - fw // 2, L.BASKET_PIVOT_Y - fw // 2)

    sc.blit(load("tw_body"), L.TW_BODY_X, L.TW_BODY_Y)

    caps = load("tw_keycaps")
    n_keys = sum(len(r) for r in L.KEY_ROWS)
    for r, row in enumerate(L.KEY_ROWS):
        n = len(row)
        x0 = L.TW_CX - (n * L.KEY_SPACING_X) // 2
        for i in range(n):
            idx = sum(len(x) for x in L.KEY_ROWS[:r]) + i
            arc = int(L.KEY_ROW_ARC * ((i - (n - 1) / 2.0) / ((n - 1) / 2.0)) ** 2)
            down = (state == "typing" and r == 2 and i == 3)
            col = idx + (n_keys if down else 0)
            sc.blit(caps.sub(col * L.KEY_W, 0, L.KEY_W, L.KEY_H + 3),
                    x0 + i * L.KEY_SPACING_X,
                    L.KEYBOARD_TOP_Y + r * L.KEY_SPACING_Y + arc)
    sb = load("tw_spacebar")
    sc.blit(sb.sub(0, 0, L.SPACEBAR_W, L.SPACEBAR_H),
            L.TW_CX - L.SPACEBAR_W // 2, L.SPACEBAR_Y)

    # --- front desk props ---
    sc.blit(load("source_letter"), L.SOURCE_LETTER_X, L.SOURCE_LETTER_Y)
    sc.blit(load("inkwell"), L.INKWELL_X, L.INKWELL_Y)
    sc.blit(load("quill"), L.QUILL_X, L.QUILL_Y)
    sc.blit(load("envelope_closed"), L.ENVELOPE_X, L.ENVELOPE_Y)
    wax = load("wax_stick")
    sc.blit(wax.sub(0, 0, L.WAX_STICK_W, L.WAX_STICK_H),
            L.WAX_STICK_X, L.WAX_STICK_Y)
    sc.blit(load("seal_stamp"), L.SEAL_STAMP_X, L.SEAL_STAMP_Y)

    if state == "typing":
        hands = load("hands")
        sc.blit(hands.sub(L.HANDS_W, 0, L.HANDS_W, L.HANDS_H),
                L.HANDS_X, L.HANDS_Y)

    sc.blit(load("chair"), -34, L.VIEW_H - 62)

    # --- light ---
    glow = load("flame_glow")
    sc.blit(glow, L.FLAME_CX - glow.w // 2, L.FLAME_CY - glow.h // 2)
    sc.blit(load("vignette"), 0, 0)
    return sc


def contact_sheet():
    """One tall image of every sprite, on a mid-tone ground, for review."""
    from PIL import Image
    names = [m["name"] for m in sorted(MANIFEST, key=lambda m: m["name"])
             if m["name"] not in ("bg_room", "vignette")]
    imgs = [(n, Image.open(os.path.join(ART, n + ".png")).convert("RGBA"))
            for n in names]
    pad = 6
    cols_w = max(i.width for _, i in imgs) + pad * 2
    total_h = sum(i.height + pad for _, i in imgs) + pad
    out = Image.new("RGBA", (cols_w, total_h), (52, 34, 24, 255))
    y = pad
    for _, im in imgs:
        out.alpha_composite(im, (pad, y))
        y += im.height + pad
    return out


def main():
    print("fonts...")
    gen_font.main()

    print("room...")
    art_room.generate(save)
    print("typewriter...")
    art_typewriter.generate(save)
    print("props...")
    art_props.generate(save)

    print("layout -> %s" % write_layout_gd())
    write_manifest()
    print("%d sprites -> %s" % (len(MANIFEST), ART))

    if "--preview" in sys.argv:
        from PIL import Image
        for st in ("typing", "jam"):
            sc = compose_scene(st)
            sc.img.resize((L.VIEW_W * 2, L.VIEW_H * 2),
                          Image.NEAREST).save(
                os.path.join(ART, "_scene_%s.png" % st))
        contact_sheet().save(os.path.join(ART, "_contact_sheet.png"))
        print("previews -> _scene_typing.png, _scene_jam.png, _contact_sheet.png")


if __name__ == "__main__":
    main()
