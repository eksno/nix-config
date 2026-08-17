// Toucan 36-key keymap data per layer.
// Mirrors ~/repos/zmk-qwerty-36/config/toucan.keymap.
//
// Each Key has:
//   l : main label (the tap action)
//   m?: hold-action mod glyph rendered in the bottom-right corner
//       (⌘⌥⌃⇧ for home-row mods, ↳num/↳nav/↳sp for thumb layer-taps,
//        or another key glyph like ⌃V for tap=⌃C/hold=⌃V)
//   d?: true = &trans (dim, falls through to home)
//
// Column order across each side: pinky → ring → middle → index → inner.
// Right side: inner → index → middle → ring → pinky (mirrored).

import { LayerName } from "./state"

export type Key = { l: string; m?: string; d?: boolean }
export type Layer = {
    rows: [Key[], Key[], Key[]]   // 3 rows × 5 keys per side; left is rows[r][0..4], right rows[r][5..9]
    leftThumbs: Key[]              // 3 keys outer→inner (Esc, ⌫, Tab on home)
    rightThumbs: Key[]             // 3 keys inner→outer (↵, ␣, ⌘ on home)
    combos?: { row: 0 | 1 | 2; label: string }[]
}

export const LAYERS: Record<LayerName, Layer> = {
    home: {
        rows: [
            [
                { l: "Q" }, { l: "W" }, { l: "E" }, { l: "R" }, { l: "T" },
                { l: "Y" }, { l: "U" }, { l: "I" }, { l: "O" }, { l: "P" },
            ],
            [
                { l: "A", m: "⌘" }, { l: "S", m: "⌥" }, { l: "D", m: "⌃" }, { l: "F", m: "⇧" }, { l: "G" },
                { l: "H" }, { l: "J", m: "⇧" }, { l: "K", m: "⌃" }, { l: "L", m: "⌥" }, { l: ";", m: "⌘" },
            ],
            [
                { l: "Z" }, { l: "X" }, { l: "C" }, { l: "V" }, { l: "B" },
                { l: "N" }, { l: "M" }, { l: "," }, { l: "." }, { l: "/" },
            ],
        ],
        leftThumbs: [
            { l: "Esc", m: "↳sp" },
            { l: "⌫",   m: "↳num" },
            { l: "Tab", m: "↳nav" },
        ],
        rightThumbs: [
            { l: "↵", m: "↳nav" },
            { l: "␣", m: "↳num" },
            { l: "⌘", m: "↳sp" },
        ],
        combos: [
            { row: 0, label: "−" },     // R+U
            { row: 1, label: "CAPS" },  // F+J
            { row: 2, label: "_" },     // V+M
        ],
    },

    num: {
        rows: [
            [
                { l: "!" }, { l: "@" }, { l: "{" }, { l: "}" }, { l: "|" },
                { l: "+" }, { l: "7" }, { l: "8" }, { l: "9" }, { l: "*" },
            ],
            [
                { l: "#", m: "⌘" }, { l: "$", m: "⌥" }, { l: "(", m: "⌃" }, { l: ")", m: "⇧" }, { l: "`" },
                { l: "-" }, { l: "4", m: "⇧" }, { l: "5", m: "⌃" }, { l: "6", m: "⌥" }, { l: ":", m: "⌘" },
            ],
            [
                { l: "%" }, { l: "^" }, { l: "[" }, { l: "]" }, { l: "~" },
                { l: "=" }, { l: "1" }, { l: "2" }, { l: "3" }, { l: "\\" },
            ],
        ],
        leftThumbs: [
            { l: "/" }, { l: "?" }, { l: "Del" },
        ],
        rightThumbs: [
            { l: "↵" }, { l: "␣" }, { l: "0" },
        ],
    },

    nav: {
        rows: [
            [
                { l: "F1" }, { l: "F2" }, { l: "F3" }, { l: "F4" }, { l: "T", d: true },
                { l: "Y", d: true }, { l: "U", d: true }, { l: "PgD" }, { l: "PgU" }, { l: "P", d: true },
            ],
            [
                { l: "F5", m: "⌘" }, { l: "F6", m: "⌥" }, { l: "F7", m: "⌃" }, { l: "F8", m: "⇧" }, { l: "⌃C", m: "⌃V" },
                { l: "H", d: true }, { l: "←", m: "⇧" }, { l: "↓", m: "⌃" }, { l: "↑", m: "⌥" }, { l: "→", m: "⌘" },
            ],
            [
                { l: "F9" }, { l: "F10" }, { l: "F11" }, { l: "F12" }, { l: "PrSc" },
                { l: "N", d: true }, { l: "M", d: true }, { l: ",", d: true }, { l: ".", d: true }, { l: "/", d: true },
            ],
        ],
        leftThumbs: [
            { l: "BTclr" }, { l: "BT→" }, { l: "Tab", d: true },
        ],
        rightThumbs: [
            { l: "↵", d: true }, { l: "␣", d: true }, { l: "⌘", d: true },
        ],
    },
}

// Column stagger from row baseline (px). Pinky drops the most, middle floats.
// Indexed by physical column 0..4 (pinky..inner) regardless of side — for the
// right side, the array is read in reverse since columns mirror.
export const COL_STAGGER = [8, 4, 0, 4, 6] // pinky, ring, middle, index, inner

// Thumb arc (px). Outer thumbs are slightly lower than inner.
export const THUMB_STAGGER_OUTER_TO_INNER = [6, 3, 2]
