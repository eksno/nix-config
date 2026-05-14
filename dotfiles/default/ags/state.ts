import { Variable } from "astal"

export type LayerName = "home" | "num" | "nav"

const ORDER: LayerName[] = ["home", "num", "nav"]

// Manual cycle for now. Phase 2 swaps this for a DBus-driven update.
export const layer = Variable<LayerName>("home")

export function cycleLayer() {
    const i = ORDER.indexOf(layer.get())
    layer.set(ORDER[(i + 1) % ORDER.length])
}
