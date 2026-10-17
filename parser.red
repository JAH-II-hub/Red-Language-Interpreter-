Red []

letter: charset valid-letters
digit: charset valid-digits
whitespace-character: charset [#" " #"^(tab)" #"^(line)"]
whitespace: [some whitespace-character]
optional-whitespace: [any whitespace-character]

compact-coordinate: func [coordinate [string!]][
    coordinate: replace/all coordinate " " ""
    coordinate: replace/all coordinate "^(tab)" ""
    coordinate: replace/all coordinate "^(line)" ""
    coordinate
]

bar-rule: [
    "bar" whitespace [letter optional-whitespace digit] optional-whitespace "," optional-whitespace digit
]

line-rule: [
    "line" whitespace [letter optional-whitespace digit] optional-whitespace "," optional-whitespace [letter optional-whitespace digit]
]

grid-rule: [
    "grid" whitespace [letter optional-whitespace digit]
]

fill-rule: [
    "fill" whitespace [letter optional-whitespace digit]
]

plot-rule: [bar-rule | line-rule | grid-rule | fill-rule]

graph-rule: [
    optional-whitespace "start" whitespace
    collect set plot-texts [
        keep copy plot-value plot-rule
        any [optional-whitespace ";" optional-whitespace keep copy plot-value plot-rule]
    ]
    optional-whitespace "end" optional-whitespace end
]

store-plot: func [plot-value [string!]][
    parse plot-value [
        "bar" whitespace copy coordinate [letter optional-whitespace digit] optional-whitespace "," optional-whitespace copy width digit
        (append/only plots reduce ["bar" compact-coordinate coordinate width])
        |
        "line" whitespace copy start-coordinate [letter optional-whitespace digit] optional-whitespace "," optional-whitespace copy end-coordinate [letter optional-whitespace digit]
        (append/only plots reduce ["line" compact-coordinate start-coordinate compact-coordinate end-coordinate])
        |
        "grid" whitespace copy coordinate [letter optional-whitespace digit]
        (append/only plots reduce ["grid" compact-coordinate coordinate])
        |
        "fill" whitespace copy coordinate [letter optional-whitespace digit]
        (append/only plots reduce ["fill" compact-coordinate coordinate])
    ]
]

format-plot: func [plot [block!]][
    value: rejoin [plot/1 " " compact-coordinate plot/2]
    if (length? plot) > 2 [append value rejoin ["," compact-coordinate plot/3]]
    value
]

record-derivation: func [value [string!]][
    append derivation rejoin ["⇒ " value]
]

parse-program: func [source [string!] /local current rest raw-plots end-found? trailing
                            grid-bound-x grid-bound-y has-grid? grid-str semi-cnt
                            cmd c1-str c2-str w-str plot-cnt plot-idx stmt bad-c
                            start-x top-y bar-w end-x end-char fx fy lx1 ly1 lx2 ly2][
    clear plots
    clear plot-texts
    clear derivation
    parse-error: ""
    last-valid: false

    source: lowercase trim source
    if empty? source [
        parse-error: "A graph sentence is required."
        return false
    ]

    ; Start derivation attempt
    append derivation "<graph>"
    current: copy "start <plot_stmts> end"
    record-derivation current

    ; 1. Must begin with keyword 'start' followed by whitespace
    rest: copy ""
    if not parse source ["start" whitespace copy rest to end][
        if parse source ["start" optional-whitespace end][
            parse-error: "Sentence contains keyword 'start' but no plot statements and 'end'."
            return false
        ]
        parse-error: "Sentence must begin with keyword 'start' followed by space."
        return false
    ]

    ; 2. Extract plot statements up to keyword 'end'
    raw-plots: copy []
    trailing: copy ""
    end-found?: false

    parse rest [
        any [
            optional-whitespace
            copy p to [";" | [whitespace "end"] | end]
            (if not empty? trim copy p [append raw-plots trim copy p])
            [
                ";" optional-whitespace
                |
                whitespace "end" optional-whitespace [end (end-found?: true) | copy trailing to end]
                |
                end
            ]
        ]
    ]

    if not end-found? [
        parse-error: "Sentence must conclude with keyword 'end' preceded by space."
        return false
    ]
    if not empty? trim trailing [
        parse-error: rejoin ["Unexpected tokens after 'end': '" trim trailing "'."]
        return false
    ]
    if empty? raw-plots [
        parse-error: "No plot statements found between 'start' and 'end'."
        return false
    ]

    ; Check semicolons vs raw-plots (prevent leading, double, or trailing semicolons)
    semi-cnt: 0
    parse rest [any [";" (semi-cnt: semi-cnt + 1) | skip]]
    if semi-cnt >= length? raw-plots [
        parse-error: "Invalid syntax: stray or trailing ';' found with no plot statement."
        return false
    ]

    ; Pre-scan for grid boundary
    has-grid?: false
    grid-bound-x: 10
    grid-bound-y: 9
    grid-str: "j9"

    foreach ps raw-plots [
        c-plot: trim copy ps
        if parse c-plot ["grid" whitespace copy g-c [letter optional-whitespace digit] optional-whitespace end][
            g-c: compact-coordinate g-c
            has-grid?: true
            grid-str: copy g-c
            grid-bound-x: index? find valid-letters to-string g-c/1
            grid-bound-y: to-integer to-string g-c/2
        ]
    ]

    plot-cnt: length? raw-plots
    plot-idx: 1

    foreach plot-str raw-plots [
        ; Leftmost derivation expansion of <plot_stmts>
        stmt: "<plot>"
        if plot-idx < plot-cnt [stmt: "<plot> ; <plot_stmts>"]
        current: replace current "<plot_stmts>" stmt
        record-derivation current

        ; Extract command
        cmd: none
        c1-str: copy ""
        c2-str: copy ""
        w-str: copy ""

        parse plot-str [
            copy cmd ["bar" | "line" | "grid" | "fill"] whitespace to end
            |
            copy cmd to [whitespace-character | end]
        ]

        if not find ["bar" "line" "grid" "fill"] cmd [
            parse-error: rejoin ["Unknown plot command '" cmd "'. Expected 'bar', 'line', 'grid', or 'fill'."]
            return false
        ]

        ; Expand leftmost non-terminal: <plot>
        if cmd = "grid" [
            current: replace current "<plot>" "grid <x><y>"
            record-derivation current

            if not parse plot-str ["grid" whitespace copy c1-str [letter optional-whitespace digit] optional-whitespace end][
                bad-c: copy ""
                parse plot-str ["grid" whitespace copy bad-c to end]
                parse-error: rejoin ["Invalid coordinate '" trim bad-c "' in 'grid'. Expected format: <x><y> where x in a-j, y in 0-9."]
                return false
            ]
            c1-str: compact-coordinate c1-str
            current: replace current "<x>" to-string c1-str/1
            record-derivation current
            current: replace current "<y>" to-string c1-str/2
            record-derivation current
            append/only plots reduce ["grid" c1-str]
        ]

        if cmd = "fill" [
            current: replace current "<plot>" "fill <x><y>"
            record-derivation current

            if not parse plot-str ["fill" whitespace copy c1-str [letter optional-whitespace digit] optional-whitespace end][
                bad-c: copy ""
                parse plot-str ["fill" whitespace copy bad-c to end]
                parse-error: rejoin ["Invalid coordinate '" trim bad-c "' in 'fill'. Expected format: <x><y> where x in a-j, y in 0-9."]
                return false
            ]
            c1-str: compact-coordinate c1-str
            current: replace current "<x>" to-string c1-str/1
            record-derivation current
            current: replace current "<y>" to-string c1-str/2
            record-derivation current

            fx: index? find valid-letters to-string c1-str/1
            fy: to-integer to-string c1-str/2
            if has-grid? [
                if any [fx > grid-bound-x fy > grid-bound-y][
                    parse-error: rejoin ["Range error in 'fill " c1-str "': coordinate exceeds grid boundary '" grid-str "'."]
                    return false
                ]
            ]
            append/only plots reduce ["fill" c1-str]
        ]

        if cmd = "line" [
            current: replace current "<plot>" "line <x><y>,<x><y>"
            record-derivation current

            if not parse plot-str ["line" whitespace copy c1-str [letter optional-whitespace digit] optional-whitespace "," optional-whitespace copy c2-str [letter optional-whitespace digit] optional-whitespace end][
                bad-c: copy ""
                parse plot-str ["line" whitespace copy bad-c to end]
                parse-error: rejoin ["Invalid parameters '" trim bad-c "' in 'line'. Expected format: <x><y>,<x><y>."]
                return false
            ]
            c1-str: compact-coordinate c1-str
            c2-str: compact-coordinate c2-str
            current: replace current "<x>" to-string c1-str/1
            record-derivation current
            current: replace current "<y>" to-string c1-str/2
            record-derivation current
            current: replace current "<x>" to-string c2-str/1
            record-derivation current
            current: replace current "<y>" to-string c2-str/2
            record-derivation current

            lx1: index? find valid-letters to-string c1-str/1
            ly1: to-integer to-string c1-str/2
            lx2: index? find valid-letters to-string c2-str/1
            ly2: to-integer to-string c2-str/2
            if has-grid? [
                if any [lx1 > grid-bound-x ly1 > grid-bound-y][
                    parse-error: rejoin ["Range error in 'line " c1-str "," c2-str "': start point " c1-str " exceeds grid boundary '" grid-str "'."]
                    return false
                ]
                if any [lx2 > grid-bound-x ly2 > grid-bound-y][
                    parse-error: rejoin ["Range error in 'line " c1-str "," c2-str "': end point " c2-str " exceeds grid boundary '" grid-str "'."]
                    return false
                ]
            ]
            append/only plots reduce ["line" c1-str c2-str]
        ]

        if cmd = "bar" [
            current: replace current "<plot>" "bar <x><y>,<y>"
            record-derivation current

            if not parse plot-str ["bar" whitespace copy c1-str [letter optional-whitespace digit] optional-whitespace "," optional-whitespace copy w-str digit optional-whitespace end][
                bad-c: copy ""
                parse plot-str ["bar" whitespace copy bad-c to end]
                parse-error: rejoin ["Invalid parameters '" trim bad-c "' in 'bar'. Expected format: <x><y>,<y> where y is digit 0-9."]
                return false
            ]
            c1-str: compact-coordinate c1-str
            w-str: trim w-str
            current: replace current "<x>" to-string c1-str/1
            record-derivation current
            current: replace current "<y>" to-string c1-str/2
            record-derivation current
            current: replace current "<y>" w-str
            record-derivation current

            start-x: index? find valid-letters to-string c1-str/1
            top-y: to-integer to-string c1-str/2
            bar-w: to-integer w-str
            end-x: start-x + bar-w
            end-char: to-char ((to-integer #"a") + end-x - 1)

            ; 1. Check absolute language boundary ('j' = 10)
            if end-x > 10 [
                parse-error: rejoin ["Range error in 'bar " c1-str "," w-str "': right boundary reaches '" end-char "0', which exceeds the maximum coordinate 'j0'."]
                return false
            ]

            ; 2. Check grid boundary if grid is present
            if has-grid? [
                if any [start-x > grid-bound-x top-y > grid-bound-y][
                    parse-error: rejoin ["Range error in 'bar " c1-str "," w-str "': start point " c1-str " exceeds grid boundary '" grid-str "'."]
                    return false
                ]
                if end-x > grid-bound-x [
                    parse-error: rejoin ["Range error in 'bar " c1-str "," w-str "': right boundary reaches '" end-char "0', which exceeds grid boundary '" grid-str "'."]
                    return false
                ]
            ]

            append/only plots reduce ["bar" c1-str w-str]
        ]

        plot-idx: plot-idx + 1
    ]

    last-valid: true
    true
]

derivation-text: func [][
    result: copy "LEFTMOST DERIVATION:^/"
    foreach step derivation [append result rejoin [step "^/"]]
    result
]

