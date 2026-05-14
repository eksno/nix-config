import { App, Astal, Gtk, Gdk } from "astal/gtk4"
import { bind } from "astal"
import Cairo from "cairo"
import { layer } from "../state"
import { LAYERS, COL_STAGGER, THUMB_STAGGER_OUTER_TO_INNER, Key, Layer } from "../data"

// ─────────────────────────────────────────────────────────────────────────
// Click-through: GTK4 layer-shell windows still receive pointer events by
// default. After realize, set the surface's input region to empty so all
// pointer events pass through to whatever is below.
// ─────────────────────────────────────────────────────────────────────────
function makeClickThrough(window: Gtk.Window) {
    const apply = () => {
        const surface = (window as any).get_surface?.()
        if (!surface) return
        try {
            const empty = new Cairo.Region()
            surface.set_input_region(empty)
        } catch (e) {
            console.error("set_input_region failed:", e)
        }
    }
    if ((window as any).get_surface?.()) apply()
    else window.connect("realize", apply)
}

// ─────────────────────────────────────────────────────────────────────────
// Atoms
// ─────────────────────────────────────────────────────────────────────────

function colClass(physicalIndex: number): string {
    // 0 = pinky, 4 = inner
    return ["col-pinky", "col-ring", "col-middle", "col-index", "col-inner"][physicalIndex] ?? ""
}

function KeyCell({ k, colIndex }: { k: Key; colIndex: number }) {
    const cls = ["key", colClass(colIndex)]
    if (k.d) cls.push("key-dim")
    // Mod glyph in bottom-right corner — overlay so it doesn't fight the main label.
    return <overlay cssClasses={cls}>
        <label cssClasses={["key-label"]} label={k.l} />
        {k.m
            ? <label
                type="overlay"
                cssClasses={["key-mod"]}
                label={k.m}
                halign={Gtk.Align.END}
                valign={Gtk.Align.END}
            />
            : <box type="overlay" />}
    </overlay>
}

function ThumbCell({ k, position }: { k: Key; position: "outer" | "mid" | "inner" }) {
    const cls = ["thumb", `thumb-${position}`]
    if (k.d) cls.push("key-dim")
    return <overlay cssClasses={cls}>
        <label cssClasses={["thumb-label"]} label={k.l} />
        {k.m
            ? <label
                type="overlay"
                cssClasses={["thumb-mod"]}
                label={k.m}
                halign={Gtk.Align.END}
                valign={Gtk.Align.END}
            />
            : <box type="overlay" />}
    </overlay>
}

// ─────────────────────────────────────────────────────────────────────────
// Rows
// ─────────────────────────────────────────────────────────────────────────

function HalfRow({ keys, side }: { keys: Key[]; side: "left" | "right" }) {
    // For left half, physical col 0 = pinky (first key). For right half,
    // first key (Y/H/N/etc.) is the inner column → physical col 4 = inner.
    return <box cssClasses={["half-row", `half-${side}`]} spacing={2} valign={Gtk.Align.START}>
        {keys.map((k, i) => {
            const physical = side === "left" ? i : 4 - i
            return <KeyCell k={k} colIndex={physical} />
        })}
    </box>
}

function ComboAnnotation({ label }: { label: string }) {
    return <label cssClasses={["combo-annot"]} label={label} valign={Gtk.Align.CENTER} />
}

function ThumbCluster({ keys, side }: { keys: Key[]; side: "left" | "right" }) {
    // Left: index 0 = outer, 2 = inner. Right: index 0 = inner, 2 = outer.
    return <box cssClasses={["thumb-cluster", `thumbs-${side}`]} spacing={3} valign={Gtk.Align.START}>
        {keys.map((k, i) => {
            const pos: "outer" | "mid" | "inner" =
                side === "left"
                    ? (["outer", "mid", "inner"] as const)[i]
                    : (["inner", "mid", "outer"] as const)[i]
            return <ThumbCell k={k} position={pos} />
        })}
    </box>
}

// ─────────────────────────────────────────────────────────────────────────
// Panel
// ─────────────────────────────────────────────────────────────────────────

function Panel({ data, name }: { data: Layer; name: string }) {
    const left = data.rows.map(r => r.slice(0, 5))
    const right = data.rows.map(r => r.slice(5, 10))
    const comboFor = (rowIdx: 0 | 1 | 2) =>
        data.combos?.find(c => c.row === rowIdx)?.label ?? ""

    return <box cssClasses={["panel"]} vertical valign={Gtk.Align.START} spacing={4}>
        <label cssClasses={["layer-name"]} label={name.toUpperCase()} />

        <box cssClasses={["matrix"]} spacing={6} halign={Gtk.Align.CENTER}>
            <box vertical spacing={2}>
                <HalfRow keys={left[0]} side="left" />
                <HalfRow keys={left[1]} side="left" />
                <HalfRow keys={left[2]} side="left" />
                <ThumbCluster keys={data.leftThumbs} side="left" />
            </box>

            <box cssClasses={["combo-col"]} vertical spacing={2} valign={Gtk.Align.START}>
                <ComboAnnotation label={comboFor(0)} />
                <ComboAnnotation label={comboFor(1)} />
                <ComboAnnotation label={comboFor(2)} />
                <box vexpand />
            </box>

            <box vertical spacing={2}>
                <HalfRow keys={right[0]} side="right" />
                <HalfRow keys={right[1]} side="right" />
                <HalfRow keys={right[2]} side="right" />
                <ThumbCluster keys={data.rightThumbs} side="right" />
            </box>
        </box>
    </box>
}

// ─────────────────────────────────────────────────────────────────────────
// Window
// ─────────────────────────────────────────────────────────────────────────

export default function Cheatsheet(gdkmonitor: Gdk.Monitor) {
    const { BOTTOM } = Astal.WindowAnchor

    const win = <window
        visible
        cssClasses={["cheatsheet"]}
        gdkmonitor={gdkmonitor}
        namespace="kbd-cheatsheet"
        anchor={BOTTOM}
        marginBottom={12}
        layer={Astal.Layer.OVERLAY}
        keymode={Astal.Keymode.NONE}
        exclusivity={Astal.Exclusivity.IGNORE}
        application={App}>
        <box cssClasses={["root"]}>
            {bind(layer).as(name => <Panel data={LAYERS[name]} name={name} />)}
        </box>
    </window> as Gtk.Window

    makeClickThrough(win)
    return win
}
