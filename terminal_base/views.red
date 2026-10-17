Red [Needs: 'View]

cell-index: func [x [integer!] y [integer!] width [integer!] height [integer!]][
    1 + x + ((height - 1 - y) * width)
]

cell-value: func [cells [block!] x [integer!] y [integer!] width [integer!] height [integer!]][
    pick cells cell-index x y width height
]

set-cell: func [cells [block!] x [integer!] y [integer!] value [integer!] width [integer!] height [integer!]][
    if all [x >= 0 x < width y >= 0 y < height][
        poke cells cell-index x y width height value
    ]
]

coordinate-values: func [coordinate [string!]][
    coordinate: compact-coordinate trim coordinate
    letter-position: find valid-letters to-string coordinate/1
    if none? letter-position [return [0 0]]
    reduce [index? letter-position to-integer to-string coordinate/2]
]

absolute-integer: func [value [integer!]][
    if value < 0 [value: 0 - value]
    value
]

mark-bar: func [cells [block!] plot [block!] width [integer!] height [integer!]][
    point: coordinate-values plot/2
    start-x: point/1 - 1
    top-y: point/2
    bar-width: to-integer plot/3
    repeat x-offset bar-width [
        repeat y-value top-y [
            set-cell cells start-x + x-offset - 1 y-value - 1 1 width height
        ]
    ]
]

mark-line: func [cells [block!] plot [block!] width [integer!] height [integer!]][
    start: coordinate-values plot/2
    finish: coordinate-values plot/3
    start-x: start/1 - 1
    finish-x: finish/1 - 1
    delta-x: finish-x - start-x
    delta-y: finish/2 - start/2
    steps: max absolute-integer delta-x absolute-integer delta-y
    if steps = 0 [set-cell cells start-x start/2 1 width height return true]
    repeat step steps + 1 [
        ratio: (step - 1) / steps
        x: to-integer (start-x + (delta-x * ratio) + 0.5)
        y: to-integer (start/2 + (delta-y * ratio) + 0.5)
        set-cell cells x y 1 width height
    ]
]

flood-fill: func [cells [block!] start-x [integer!] start-y [integer!] width [integer!] height [integer!]][
    if any [start-x < 0 start-x >= width start-y < 0 start-y >= height][return true]
    target: cell-value cells start-x start-y width height
    replacement: 2
    if target = replacement [return true]
    queue: copy [0x0]
    queue/1: as-pair start-x start-y
    set-cell cells start-x start-y replacement width height
    while [not empty? queue][
        point: take queue
        neighbors: reduce [
            as-pair point/x + 1 point/y
            as-pair point/x - 1 point/y
            as-pair point/x point/y + 1
            as-pair point/x point/y - 1
        ]
        foreach neighbor neighbors [
            if all [
                neighbor/x >= 0 neighbor/x < width
                neighbor/y >= 0 neighbor/y < height
                (cell-value cells neighbor/x neighbor/y width height) = target
            ][
                set-cell cells neighbor/x neighbor/y replacement width height
                append queue neighbor
            ]
        ]
    ]
]

fill-bar: func [cells [block!] shape [block!] width [integer!] height [integer!]][
    start-x: shape/1
    start-y: shape/2
    bar-width: shape/3
    bar-height: shape/4
    repeat x-offset bar-width [
        repeat y-offset bar-height [
            set-cell cells (start-x + x-offset - 1) (start-y - y-offset) 2 width height
        ]
    ]
]

bar-containing-point: func [shapes [block!] point [block!]][
    foreach shape shapes [
        if all [
            ((point/1 - 1) >= shape/1)
            ((point/1 - 1) < (shape/1 + shape/3))
            (point/2 <= shape/2)
            (point/2 >= (shape/2 - shape/4))
        ][return copy shape]
    ]
    none
]

draw-graph: func [/local width height bar-colors line-colors bar-number line-number
                         grid-point cell-size cell-width cell-height origin cells
                         bar-shapes line-shapes filled-shapes grid-visible?
                         command point bar-color shape start-point end-point line-color
                         selected-shape draw-block state top-left bottom-right
                         left right top bottom x-position line-count y-position label
                         start-x start-y end-x end-y][
    width: 9
    height: 9
    bar-colors: [255.179.186 255.223.186 255.255.186 186.255.201 186.225.255]
    line-colors: [red blue black green]
    bar-number: 0
    line-number: 0
    grid-visible?: true

    foreach plot plots [
        if plot/1 = "grid" [
            grid-point: coordinate-values plot/2
            width: grid-point/1 - 1
            height: grid-point/2
        ]
    ]
    if width < 1 [width: 1]
    if height < 1 [height: 1]
    cell-size: to-integer 630 / width
    if (400 / height) < cell-size [cell-size: to-integer 400 / height]
    cell-width: cell-size
    cell-height: cell-size
    origin: 50x430
    cells: copy []
    loop width * height [append cells 0]
    bar-shapes: copy []
    line-shapes: copy []
    filled-shapes: copy []

    foreach plot plots [
        command: plot/1
        if command = "bar" [
            point: coordinate-values plot/2
            bar-number: bar-number + 1
            bar-color: pick bar-colors 1 + ((bar-number - 1) // length? bar-colors)
            shape: reduce [(point/1 - 1) point/2 (to-integer plot/3) point/2 bar-color]
            append/only bar-shapes shape
            mark-bar cells plot width height
        ]
        if command = "line" [
            mark-line cells plot width height
            start-point: coordinate-values plot/2
            end-point: coordinate-values plot/3
            line-number: line-number + 1
            line-color: pick line-colors 1 + ((line-number - 1) // length? line-colors)
            append/only line-shapes reduce [(start-point/1 - 1) start-point/2 (end-point/1 - 1) end-point/2 line-color]
        ]
    ]

    foreach plot plots [
        if plot/1 = "fill" [
            point: coordinate-values plot/2
            selected-shape: none
            foreach candidate bar-shapes [
                if all [
                    ((point/1 - 1) >= candidate/1)
                    ((point/1 - 1) < (candidate/1 + candidate/3))
                    (point/2 <= candidate/2)
                    (point/2 >= (candidate/2 - candidate/4))
                ][selected-shape: copy candidate]
            ]
            if none? selected-shape [
                flood-fill cells point/1 - 1 point/2 width height
            ]
            if not none? selected-shape [
                append/only filled-shapes selected-shape
            ]
        ]
    ]

    draw-block: copy [pen gray]
    repeat y height [
        repeat x width [
            state: cell-value cells x - 1 y - 1 width height
            if state = 2 [
                top-left: as-pair origin/x + ((x - 1) * cell-width) + 1 origin/y - (y * cell-height) + 1
                bottom-right: as-pair origin/x + (x * cell-width) - 1 origin/y - ((y - 1) * cell-height) - 1
                append draw-block reduce ['fill-pen gold 'box top-left bottom-right]
            ]
        ]
    ]

    foreach shape filled-shapes [
        left: origin/x + ((shape/1) * cell-width)
        right: left + ((shape/3) * cell-width)
        top: origin/y - ((shape/2) * cell-height)
        bottom: origin/y
        append draw-block reduce [
            'fill-pen shape/5
            'box as-pair left + 1 top + 1 as-pair right - 1 bottom - 1
        ]
    ]

    if grid-visible? [
        repeat x width + 1 [
            x-position: origin/x + ((x - 1) * cell-width)
            append draw-block reduce ['pen gray 'line as-pair x-position origin/y as-pair x-position origin/y - (height * cell-height)]
        ]
        line-count: height + 1
        repeat y line-count [
            y-position: origin/y - ((y - 1) * cell-height)
            append draw-block reduce ['pen gray 'line as-pair origin/x y-position as-pair origin/x + (width * cell-width) y-position]
        ]
        repeat x width + 1 [
            label: to-string pick valid-letters x
            append draw-block reduce ['text as-pair origin/x + ((x - 1) * cell-width) + 5 origin/y + 30 label]
        ]
        repeat y height + 1 [
            append draw-block reduce ['text as-pair 20 origin/y - ((y - 1) * cell-height) + 5 to-string (y - 1)]
        ]
    ]

    foreach shape bar-shapes [
        left: origin/x + ((shape/1) * cell-width)
        right: left + ((shape/3) * cell-width)
        top: origin/y - ((shape/2) * cell-height)
        bottom: origin/y
        append draw-block reduce [
            'fill-pen shape/5
            'box as-pair left top as-pair right bottom
            'line-width 3
            'pen black
            'line as-pair left top as-pair right top
            'line as-pair right top as-pair right bottom
            'line as-pair right bottom as-pair left bottom
            'line as-pair left bottom as-pair left top
        ]
    ]

    foreach shape line-shapes [
        start-x: origin/x + ((shape/1) * cell-width)
        start-y: origin/y - ((shape/2) * cell-height)
        end-x: origin/x + ((shape/3) * cell-width)
        end-y: origin/y - ((shape/4) * cell-height)
        append draw-block reduce [
            'line-width 3
            'pen shape/5
            'line as-pair start-x start-y as-pair end-x end-y
        ]
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
        panel win-size [
            across
            text "Graphical Output" font-size 14 bold
            pad 20x0
            button "Continue (Enter Another Sentence) ➔" 240 [unview]
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
