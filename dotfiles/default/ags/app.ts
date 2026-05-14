import { App } from "astal/gtk4"
import style from "./style.scss"
import Cheatsheet from "./widget/Cheatsheet"
import { layer, cycleLayer } from "./state"

App.start({
    css: style,
    requestHandler(request, res) {
        switch (request) {
            case "cycle":
                cycleLayer()
                res(`layer=${layer.get()}`)
                return
            case "layer":
                res(layer.get())
                return
            default:
                res(`unknown: ${request}`)
        }
    },
    main() {
        App.get_monitors().map(Cheatsheet)
    },
})
