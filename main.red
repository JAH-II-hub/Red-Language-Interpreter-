Red [
    Title: "Red Plot Language Interpreter"
    Needs: 'View
    Author: "CMPS3111 Team"
    Purpose: {
        Interpreter and visualizer for the Red Plot Language.
        Conducts lexical/syntactic analysis, generates leftmost derivations,
        renders the parse tree, and displays the 2D graphical output.
    }
]

#include %grammar.red
#include %parser.red
#include %views.red

; Global UI references
source-field: none
result-area: none
status-label: none
view-tree-btn: none
view-graph-btn: none
grammar-area: none
main-panel: none
btn-panel: none

resize-main: func [win-size [pair!] /local w h inner-w res-y rem-h][
    w: win-size/x
    h: win-size/y
    if main-panel [
        main-panel/size: as-pair w h
        inner-w: max 660 (w - 24)
        
        if grammar-area [grammar-area/size: as-pair inner-w 215]
        if source-field [source-field/size: as-pair inner-w 28]
        if btn-panel    [btn-panel/size: as-pair inner-w 35]
        if status-label [status-label/size: as-pair inner-w 20]
        if result-area  [
            res-y: to-integer result-area/offset/y
            rem-h: max 150 (h - res-y - 25)
            result-area/size: as-pair inner-w rem-h
        ]
        show reduce [main-panel grammar-area source-field btn-panel status-label result-area]
    ]
]

; =========================================================================
; SUBPROGRAM (iii): Graphical Output
; Called after Subprogram (ii) if derivation is successful.
; Displays the graphical output representing the input program.
; Prompts the user to continue (which loops back to the main input prompt).
; =========================================================================
subprogram-graphical-output: does [
    if last-valid [
        draw-output
    ]
]

; =========================================================================
; SUBPROGRAM (ii): Parse Tree Visualizer
; Called if the derivation is successful.
; Draws the parse tree for derivation of the input string, displays the tree,
; and prompts the user to click to continue to the graphical output.
; =========================================================================
subprogram-parse-tree: does [
    if last-valid [
        show-parse-tree-window
    ]
]

; =========================================================================
; SUBPROGRAM (i): Leftmost Derivation
; Executes a leftmost derivation of the input string, showing each
; sentential form and the final generated sentence (or syntax error).
; If valid: indicates success and enables visualization buttons.
; If invalid: shows derivation attempt and error, then prompts for another string.
; =========================================================================
subprogram-derivation: func [source [string!] /local trimmed][
    trimmed: trim source
    result-area/text: ""
    show result-area
    last-valid: false

    ; Solution (C): Only the exact uppercase word STOP terminates the program
    if trimmed == "STOP" [
        quit
    ]

    ; Check for empty input
    if empty? trimmed [
        result-area/text: "Error: Please enter a graph sentence. Type STOP to exit."
        status-label/text: "Error: No sentence entered. Please type a sentence."
        view-tree-btn/enabled?: false
        view-graph-btn/enabled?: false
        show [result-area status-label view-tree-btn view-graph-btn]
        return false
    ]

    ; Perform leftmost derivation and syntax validation
    last-valid: parse-program trimmed

    if last-valid [
        result-area/text: rejoin [
            derivation-text
            "^/=== Derivation Successful! ==="
            "^/The input sentence is valid according to the language grammar."
            "^/Click 'View Parse Tree' or 'View Graph' to view visualizations."
        ]
        status-label/text: "✓ Derivation successful! Click 'View Parse Tree' or 'View Graph' to view visualizations."
        view-tree-btn/enabled?: true
        view-graph-btn/enabled?: true
    ]

    if not last-valid [
        result-area/text: rejoin [
            derivation-text
            "^/=== Derivation Unsuccessful ==="
            "^/Syntax error: " parse-error
            "^/Please enter another string to retry, or type STOP to exit."
        ]
        status-label/text: rejoin ["✗ Syntax error: " parse-error]
        view-tree-btn/enabled?: false
        view-graph-btn/enabled?: false
    ]

    show [result-area status-label view-tree-btn view-graph-btn]
    last-valid
]

; =========================================================================
; Pipeline Controller
; Advances sequentially through the required subprogram flow:
; Derivation -> Parse Tree -> Graphical Output -> Loop back to A
; =========================================================================
advance-pipeline: does [
    if last-valid [
        subprogram-parse-tree
    ]
]

; =========================================================================
; MAIN
; Displays the BNF grammar for the language and prompts for an input string.
; If input is "STOP" terminates; else calls Subprogram (i), (ii), and (iii).
; =========================================================================
main: does [
    view/flags layout [
        title "Red Plot Language Interpreter"
        backdrop snow
        on-resizing [
            resize-main face/size
        ]
        on-resize [
            resize-main face/size
        ]
        main-panel: panel 680x805 [
            below
            text "Red Plot Language Interpreter" font-size 18 bold
            text "Enter a graph sentence, then analyze it. Type STOP to exit." font-size 11
            text 660 "Example: start grid e5; bar b3,2; line a1,d4 end" font-size 10 italic
            
            text "A. BNF Grammar" font-size 13 bold
            grammar-area: area 660x215 grammar-text
            
            text "B. Input Sentence (Type STOP to exit)" font-size 13 bold
            source-field: field 660 "" on-enter [
                subprogram-derivation source-field/text
            ]
            
            btn-panel: panel 660x35 [
                across
                button "Analyze Sentence" 150 [
                    subprogram-derivation source-field/text
                ]
                view-tree-btn: button "View Parse Tree" 140 [
                    subprogram-parse-tree
                ]
                view-graph-btn: button "View Graph" 140 [
                    subprogram-graphical-output
                ]
            ]
            
            status-label: text 660 "Ready. Type a sentence above and press Enter (or click 'Analyze Sentence')." font-size 10 bold
            
            text "C. Leftmost Derivation Output" font-size 13 bold
            result-area: area 660x225 "Derivation output will appear here."
        ]
    ] 'resize
]

main
