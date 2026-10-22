Red [Needs: 'View]

cartesian-coord: func [coord [string!] /local pos][
    coord: compact-coordinate trim coord
    pos: find valid-letters to-string coord/1
    if none? pos [return [0 0]]
    reduce [(index? pos) - 1   to-integer to-string coord/2]
]

coordinate-values: func [coordinate [string!]][
    cartesian-coord coordinate
]

pt-on-side?: func [px [float!] py [float!] x1 [float!] y1 [float!] x2 [float!] y2 [float!] seed-above? [logic!] /local l-dx l-dy val][
    l-dx: x2 - x1
    l-dy: y2 - y1
    either l-dx = 0.0 [
        either seed-above? [px >= x1] [px <= x1]
    ][
        val: (l-dx * (py - y1)) - (l-dy * (px - x1))
        either seed-above? [val >= -0.0001] [val <= 0.0001]
    ]
]

line-intersect: func [ax [float!] ay [float!] bx [float!] by [float!] x1 [float!] y1 [float!] x2 [float!] y2 [float!] /local denom num t ix iy][
    denom: ((x2 - x1) * (by - ay)) - ((y2 - y1) * (bx - ax))
    if denom = 0.0 [return reduce [ax ay]]
    num: ((x2 - x1) * (y1 - ay)) - ((y2 - y1) * (x1 - ax))
    t: num / denom
    ix: ax + (t * (bx - ax))
    iy: ay + (t * (by - ay))
    reduce [ix iy]
]

clip-polygon: func [poly [block!] x1 [float!] y1 [float!] x2 [float!] y2 [float!] seed-above? [logic!] /local output prev-pt prev-in? curr-pt curr-in? ipt][
    output: copy []
    if empty? poly [return output]
    prev-pt: last poly
    prev-in?: pt-on-side? prev-pt/1 prev-pt/2 x1 y1 x2 y2 seed-above?

    foreach curr-pt poly [
        curr-in?: pt-on-side? curr-pt/1 curr-pt/2 x1 y1 x2 y2 seed-above?
        if curr-in? [
            if not prev-in? [
                ipt: line-intersect prev-pt/1 prev-pt/2 curr-pt/1 curr-pt/2 x1 y1 x2 y2
                append/only output ipt
            ]
            append/only output copy curr-pt
        ]
        if not curr-in? [
            if prev-in? [
                ipt: line-intersect prev-pt/1 prev-pt/2 curr-pt/1 curr-pt/2 x1 y1 x2 y2
                append/only output ipt
            ]
        ]
        prev-pt: curr-pt
        prev-in?: curr-in?
    ]
    output
]

draw-graph: func [/local has-grid? grid-x grid-y auto-max-x auto-max-y max-x max-y
                         bar-colors line-colors bar-num line-num
                         cell-size origin-x origin-y canvas-w canvas-h
                         avail-w avail-h screen-pt bar-shapes line-shapes
                         draw-block ax-start ax-end ay-start ay-end
                         pt p-bot p-top p-left p-right letter-str num-str
                         x1 y-top w top-left bottom-right top-right coord-label
                         p1 p2 pt1 pt2 col in-bar? fp c-tl c-br f-pt current-fill
                         end-x-pt end-y-pt gp bp bw lp ep sp b-col
                         fill-pts target-bar has-line? div-line
                         l-dx l-dy seed-above? y-line fill-col is-vert? fill-right?
                         target-fp rect-poly clipped-poly poly-pts v][ 
    has-grid?: false
    grid-x: 4
    grid-y: 4
    auto-max-x: 4
    auto-max-y: 4
    bar-shapes: copy []
    line-shapes: copy []
    fill-pts: copy []

    ; 1. Analyze plots to determine extent, shapes, and grid presence
    foreach plot plots [
        if plot/1 = "grid" [
            has-grid?: true
            gp: cartesian-coord plot/2
            grid-x: gp/1
            grid-y: gp/2
        ]
        if plot/1 = "bar" [
            bp: cartesian-coord plot/2
            bw: to-integer plot/3
            auto-max-x: max auto-max-x (bp/1 + bw)
            auto-max-y: max auto-max-y bp/2
            append/only bar-shapes reduce [bp/1 bp/2 bw]
        ]
        if plot/1 = "line" [
            lp: cartesian-coord plot/2
            ep: cartesian-coord plot/3
            auto-max-x: max auto-max-x (max lp/1 ep/1)
            auto-max-y: max auto-max-y (max lp/2 ep/2)
            append/only line-shapes reduce [lp/1 lp/2 ep/1 ep/2]
        ]
        if plot/1 = "fill" [
            sp: cartesian-coord plot/2
            auto-max-x: max auto-max-x sp/1
            auto-max-y: max auto-max-y sp/2
            append/only fill-pts sp
        ]
    ]

    either has-grid? [
        max-x: max grid-x auto-max-x
        max-y: max grid-y auto-max-y
    ][
        max-x: max 4 auto-max-x
        max-y: max 4 auto-max-y
    ]
    if max-x > 9 [max-x: 9]
    if max-y > 9 [max-y: 9]
    if max-x < 1 [max-x: 1]
    if max-y < 1 [max-y: 1]

    canvas-w: 920
    canvas-h: 540
    origin-x: 85
    avail-w: canvas-w - origin-x - 60
    avail-h: canvas-h - 75 - 55

    cell-size: min 75 (min (to-integer (avail-w / max-x)) (to-integer (avail-h / max-y)))
    if cell-size < 35 [cell-size: 35]
    origin-y: 55 + (max-y * cell-size)

    screen-pt: func [x [integer! float!] y [integer! float!]][
        as-pair (to-integer (origin-x + (x * cell-size) + 0.5)) (to-integer (origin-y - (y * cell-size) + 0.5))
    ]

    draw-block: copy []

    ; 2. Render Region Fill (Smooth vector polygon, bounded by lines and boxes)
    fill-col: 255.230.140
    foreach fp fill-pts [
        ; Check if fp is inside any bar
        target-bar: none
        foreach b bar-shapes [
            if all [
                fp/1 >= b/1
                fp/1 <= (b/1 + b/3)
                fp/2 >= 0
                fp/2 <= b/2
            ][
                target-bar: b
                break
            ]
        ]

        ; If NOT in a bar: fill the open grid region as a smooth polygon
        if none? target-bar [
            has-line?: not empty? line-shapes
            rect-poly: reduce [
                reduce [0.0 0.0]
                reduce [to-float max-x 0.0]
                reduce [to-float max-x to-float max-y]
                reduce [0.0 to-float max-y]
            ]

            either has-line? [
                div-line: line-shapes/1
                l-dx: to-float (div-line/3 - div-line/1)
                l-dy: to-float (div-line/4 - div-line/2)
                is-vert?: (l-dx = 0.0)
                either is-vert? [
                    fill-right?: (fp/1 >= div-line/1)
                    seed-above?: fill-right?
                ][
                    y-line: (to-float div-line/2) + ((l-dy / l-dx) * (to-float (fp/1 - div-line/1)))
                    seed-above?: ((to-float fp/2) >= y-line)
                ]

                clipped-poly: clip-polygon rect-poly (to-float div-line/1) (to-float div-line/2) (to-float div-line/3) (to-float div-line/4) seed-above?
                if (length? clipped-poly) >= 3 [
                    poly-pts: copy []
                    foreach v clipped-poly [
                        append poly-pts screen-pt v/1 v/2
                    ]
                    append draw-block reduce ['fill-pen fill-col 'pen fill-col 'polygon]
                    append draw-block poly-pts
                ]
            ][
                ; No line: fill entire grid rectangle
                append draw-block reduce [
                    'fill-pen fill-col 'pen fill-col
                    'box (screen-pt 0 max-y) (screen-pt max-x 0)
                ]
            ]
        ]
    ]

    ; 3. Cartesian Grid lines (only when grid was explicitly declared)
    if has-grid? [
        append draw-block reduce ['pen 220.224.230 'line-width 1]
        repeat xi (max-x + 1) [
            x-val: xi - 1
            p-bot: screen-pt x-val 0
            p-top: screen-pt x-val max-y
            append draw-block reduce ['line p-bot p-top]
        ]
        repeat yi (max-y + 1) [
            y-val: yi - 1
            p-left: screen-pt 0 y-val
            p-right: screen-pt max-x y-val
            append draw-block reduce ['line p-left p-right]
        ]
    ]

    ; 4. Cartesian Axes with arrows (only when grid was explicitly declared)
    if has-grid? [
        end-x-pt: screen-pt max-x 0
        ax-start: screen-pt 0 0
        ax-end: as-pair (end-x-pt/x + 25) (ax-start/y)
        append draw-block reduce [
            'line-width 2 'pen 40.40.40 'line ax-start ax-end
            'triangle ax-end as-pair (ax-end/x - 8) (ax-end/y - 4) as-pair (ax-end/x - 8) (ax-end/y + 4)
        ]

        end-y-pt: screen-pt 0 max-y
        ay-start: screen-pt 0 0
        ay-end: as-pair (ay-start/x) (end-y-pt/y - 25)
        append draw-block reduce [
            'line-width 2 'pen 40.40.40 'line ay-start ay-end
            'triangle ay-end as-pair (ay-end/x - 4) (ay-end/y + 8) as-pair (ay-end/x + 4) (ay-end/y + 8)
        ]

        append draw-block reduce ['pen 40.40.40 'text as-pair (ax-end/x + 5) (ax-end/y - 8) "X"]
        append draw-block reduce ['pen 40.40.40 'text as-pair (ay-end/x - 7) (ay-end/y - 22) "Y"]

        ; 5. Ticks & Labels aligned directly on grid lines
        repeat xi (max-x + 1) [
            x-val: xi - 1
            pt: screen-pt x-val 0
            letter-str: to-string pick valid-letters (x-val + 1)
            append draw-block reduce [
                'line-width 2 'pen 40.40.40 'line pt as-pair pt/x (pt/y + 6)
                'text as-pair (pt/x - 4) (pt/y + 9) letter-str
            ]
        ]
        repeat yi (max-y + 1) [
            y-val: yi - 1
            pt: screen-pt 0 y-val
            num-str: to-string y-val
            append draw-block reduce [
                'line-width 2 'pen 40.40.40 'line pt as-pair (pt/x - 6) pt/y
                'text as-pair (pt/x - 22) (pt/y - 7) num-str
            ]
        ]
    ]

    ; 6. Bars (Smooth polygon fill clipped to dividing line + fill-pen transparent outline)
    bar-colors: [255.179.186 255.223.186 255.255.186 186.255.201 186.225.255]
    bar-num: 0

    foreach b bar-shapes [
        bar-num: bar-num + 1
        b-col: pick bar-colors (1 + ((bar-num - 1) // length? bar-colors))
        x1: b/1
        y-top: b/2
        w: b/3

        top-left: screen-pt x1 y-top
        bottom-right: screen-pt (x1 + w) 0
        top-right: screen-pt (x1 + w) y-top

        ; Draw solid white background for the bar so grid behind is masked
        append draw-block reduce [
            'line-width 1 'pen 245.248.252 'fill-pen 255.255.255
            'box top-left bottom-right
        ]

        ; Check if this bar is targeted by any fill point inside it
        target-fp: none
        foreach fp fill-pts [
            if all [fp/1 >= x1  fp/1 <= (x1 + w)  fp/2 >= 0  fp/2 <= y-top][
                target-fp: fp
                break
            ]
        ]

        if target-fp [
            ; Use smooth polygon clipping -- no more jagged strips!
            has-line?: not empty? line-shapes
            either has-line? [
                div-line: line-shapes/1
                l-dx: to-float (div-line/3 - div-line/1)
                l-dy: to-float (div-line/4 - div-line/2)
                is-vert?: (l-dx = 0.0)
                either is-vert? [
                    seed-above?: (target-fp/1 >= div-line/1)
                ][
                    y-line: (to-float div-line/2) + ((l-dy / l-dx) * (to-float (target-fp/1 - div-line/1)))
                    seed-above?: ((to-float target-fp/2) >= y-line)
                ]

                rect-poly: reduce [
                    reduce [to-float x1  0.0]
                    reduce [to-float (x1 + w)  0.0]
                    reduce [to-float (x1 + w)  to-float y-top]
                    reduce [to-float x1  to-float y-top]
                ]

                clipped-poly: clip-polygon rect-poly (to-float div-line/1) (to-float div-line/2) (to-float div-line/3) (to-float div-line/4) seed-above?
                if (length? clipped-poly) >= 3 [
                    poly-pts: copy []
                    foreach v clipped-poly [
                        append poly-pts screen-pt v/1 v/2
                    ]
                    append draw-block reduce ['fill-pen b-col 'pen b-col 'polygon]
                    append draw-block poly-pts
                ]
            ][
                ; No line going through bar: fill the entire bar
                append draw-block reduce [
                    'line-width 1 'pen b-col 'fill-pen b-col
                    'box top-left bottom-right
                ]
            ]
        ]

        ; Crisp bar outline -- fill-pen transparent avoids aborting the Direct2D draw pipeline
        append draw-block reduce [
            'line-width 2 'pen 30.30.30 'fill-pen transparent
            'box top-left bottom-right
        ]

        ; Vertex markers exactly on Cartesian intersections
        append draw-block reduce [
            'pen 30.30.30 'fill-pen 220.40.40 'circle top-left 5
            'pen 30.30.30 'text as-pair (top-left/x + 7) (top-left/y - 18) rejoin ["(" pick valid-letters (x1 + 1) "," y-top ")"]
            'pen 30.30.30 'fill-pen 220.40.40 'circle top-right 4
        ]
    ]
    ; 7. Lines (Endpoints plotted on intersections)
    line-colors: [200.0.0 0.80.200 0.150.0 128.0.128 220.100.0]
    line-num: 0
    foreach l line-shapes [
        line-num: line-num + 1
        pt1: screen-pt l/1 l/2
        pt2: screen-pt l/3 l/4
        col: pick line-colors (1 + ((line-num - 1) // length? line-colors))

        append draw-block reduce [
            'line-width 3 'pen col 'line pt1 pt2
            'pen 30.30.30 'fill-pen col 'circle pt1 5
            'pen 30.30.30 'text as-pair (pt1/x + 7) (pt1/y - 18) rejoin ["(" pick valid-letters (l/1 + 1) "," l/2 ")"]
            'pen 30.30.30 'fill-pen col 'circle pt2 5
            'pen 30.30.30 'text as-pair (pt2/x + 7) (pt2/y - 18) rejoin ["(" pick valid-letters (l/3 + 1) "," l/4 ")"]
        ]
    ]

    ; 8. Fill Target Marker at exact intersection
    foreach fp fill-pts [
        f-pt: screen-pt fp/1 fp/2
        append draw-block reduce [
            'line-width 2 'pen 200.50.0 'fill-pen 255.200.0 'circle f-pt 6
            'pen 180.40.0 'text as-pair (f-pt/x + 8) (f-pt/y - 8) rejoin ["fill (" pick valid-letters (fp/1 + 1) "," fp/2 ")"]
        ]
    ]

    ; 9. Information caption
    append draw-block reduce [
        'pen 120.120.120
        'text as-pair 85 (canvas-h - 35) "Cartesian System: Points land on grid line intersections. Fills bounded strictly by lines and boxes."
    ]

    draw-block
]

open-graph-window: func [/local win-size canvas-size draw-block][
    win-size: 960x650
    canvas-size: 920x540
    draw-block: draw-graph
    view layout [
        title "Red Plot Language - Graphical Output"
        backdrop snow
        on-key-down [if event/key = #"^M" [unview]]
        panel win-size [
            across
            text "Graphical Output" font-size 14 bold
            pad 20x0
            button "Continue ➔  (or press Enter)" 240 [unview]
            return
            text "Grid, bars, lines, and filled regions rendered below:" font-size 11 italic
            return
            canvas: base canvas-size white draw draw-block
        ]
    ]
]

draw-output: func [/local boot-str script-dir plots-file viewer-file red-view-exe candidates][
    ; If already running inside red-view-066.exe, open directly
    boot-str: to-string system/options/boot
    if find boot-str "red-view" [
        open-graph-window
        exit
    ]

    ; Running in console mode (red-cli-066.exe)
    ; Launch graph_viewer.red in red-view-066.exe for full Direct2D rendering
    script-dir: either system/options/script [first split-path system/options/script] [%./]
    plots-file: clean-path join script-dir %_current_plots.red
    viewer-file: clean-path join script-dir %graph_viewer.red

    save plots-file plots

    red-view-exe: none
    candidates: [
        %"c:/Users/johnh/Downloads/red-view-066.exe"
        %"../red-view-066.exe"
        %"red-view-066.exe"
    ]
    foreach c candidates [
        if exists? c [red-view-exe: to-local-file clean-path c break]
    ]

    either red-view-exe [
        call/wait rejoin [{"} red-view-exe {" "} to-local-file viewer-file {"}]
        if exists? plots-file [delete plots-file]
    ][
        open-graph-window
    ]
]

tree-leaf: func [label [string!]][reduce [label copy []]]

tree-coordinate: func [coordinate [string!] /local node][
    coordinate: compact-coordinate coordinate
    node: reduce ["<x><y>" copy []]
    append/only node/2 reduce ["<x>" reduce [tree-leaf to-string coordinate/1]]
    append/only node/2 reduce ["<y>" reduce [tree-leaf to-string coordinate/2]]
    node
]

tree-plot: func [plot [block!] /local node][
    node: reduce ["<plot>" copy []]
    append/only node/2 tree-leaf plot/1
    append/only node/2 tree-coordinate plot/2
    if plot/1 = "bar" [
        append/only node/2 tree-leaf ","
        append/only node/2 reduce ["<y>" reduce [tree-leaf to-string plot/3]]
    ]
    if plot/1 = "line" [
        append/only node/2 tree-leaf ","
        append/only node/2 tree-coordinate plot/3
    ]
    node
]

parse-tree-model: func [/local statements plot-index plot-count][
    statements: copy []
    plot-index: 1
    plot-count: length? plots
    foreach plot plots [
        append/only statements tree-plot plot
        if plot-index < plot-count [append/only statements tree-leaf ";"]
        plot-index: plot-index + 1
    ]
    reduce [
        "<graph>"
        reduce [
            ["start" []]
            reduce ["<plot_stmts>" statements]
            ["end" []]
        ]
    ]
]

print-ascii-tree: func [node [block!] prefix [string!] is-last? [logic!] /local label children child-count i next-prefix child][
    label: node/1
    children: either (length? node) > 1 [node/2] [copy []]
    
    either empty? prefix [
        print label
    ][
        print rejoin [prefix (either is-last? ["`-- "] ["|-- "]) label]
    ]
    
    child-count: length? children
    if child-count > 0 [
        next-prefix: rejoin [prefix (either is-last? ["    "] ["|   "])]
        if empty? prefix [next-prefix: "  "]
        i: 1
        foreach child children [
            print-ascii-tree child next-prefix (i = child-count)
            i: i + 1
        ]
    ]
]
