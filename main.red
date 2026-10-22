Red [
    Title: "Red Plot Language Interpreter (Terminal Edition)"
    Needs: 'View
    Author: "Group 3: Red Plot Language Team"
    Purpose: {
        Terminal-based interpreter and visualizer for the Red Plot Language.
        Conducts lexical/syntactic analysis, generates leftmost derivations,
        renders the parse tree in the terminal, and displays the 2D graphical output.
    }
]

#include %grammar.red
#include %parser.red
#include %views.red

; =========================================================================
; SUBPROGRAM (iii): Graphical Output
; Called after Subprogram (ii) if derivation is successful.
; Displays the graphical output representing the input program.
; =========================================================================
subprogram-graphical-output: does [
    if last-valid [
        print "----------------------------------------------------------------------"
        print "                  SUBPROGRAM (iii): GRAPHICAL OUTPUT                  "
        print "----------------------------------------------------------------------"
        print "Opening Graphical Output window..."
        print "(Close the Graphical Output window to return to the terminal prompt)"
        draw-output
        print "Graphical output closed. Returning to main menu."
    ]
]

; =========================================================================
; SUBPROGRAM (ii): Parse Tree Visualizer
; Called if the derivation is successful.
; Draws the parse tree for derivation of the input string in the terminal.
; =========================================================================
subprogram-parse-tree: does [
    if last-valid [
        print ""
        print "======================================================================"
        print "                      SUBPROGRAM (ii): PARSE TREE                     "
        print "======================================================================"
        print ""
        tree: parse-tree-model
        print-ascii-tree tree "" true
        print ""
    ]
]

; =========================================================================
; SUBPROGRAM (i): Leftmost Derivation
; Executes a leftmost derivation of the input string, showing each
; sentential form and the final generated sentence (or syntax error).
; If valid: indicates success.
; If invalid: shows derivation attempt and error.
; =========================================================================
subprogram-derivation: func [source [string!] /local trimmed][
    trimmed: trim source
    last-valid: false

    ; Solution (C): Only the exact uppercase word STOP terminates the program
    if trimmed == "STOP" [
        print "^/Exiting program. Goodbye!^/"
        quit
    ]

    ; Friendly hint when user types stop in wrong case
    if (uppercase trimmed) == "STOP" [
        print "^/To exit the program, type STOP in uppercase.^/"
        return false
    ]

    ; Check for empty input
    if empty? trimmed [
        print "^/Error: Please enter a graph sentence. Type STOP to exit.^/"
        return false
    ]

    ; Perform leftmost derivation and syntax validation
    last-valid: parse-program trimmed

    print ""
    print "======================================================================"
    print "                 SUBPROGRAM (i): LEFTMOST DERIVATION                  "
    print "======================================================================"
    print derivation-text
    print "----------------------------------------------------------------------"

    either last-valid [
        print "=== Derivation Successful! ==="
        print "The input sentence is valid according to the language grammar."
    ][
        print "=== Derivation Unsuccessful ==="
        print rejoin ["Syntax / Validation error: " parse-error]
        print "Please enter another sentence to retry, or type STOP to exit."
    ]
    last-valid
]

; =========================================================================
; Displays BNF Grammar and Banner
; =========================================================================
display-bnf: does [
    print "======================================================================"
    print "                RED PLOT LANGUAGE INTERPRETER (TERMINAL)              "
    print "======================================================================"
    print grammar-text
    print "----------------------------------------------------------------------"
    print "Example: start grid e5; bar b3,2; line a1,d4 end"
    print "Type STOP to exit the program."
    print "----------------------------------------------------------------------"
]

; =========================================================================
; MAIN
; Displays the BNF grammar for the language and prompts for an input string.
; If input is "STOP" terminates; else calls Subprogram (i), (ii), and (iii).
; =========================================================================
main: does [
    forever [
        print ""
        display-bnf
        print ""
        input-str: ask "Enter sentence> "
        
        valid?: subprogram-derivation input-str
        
        if valid? [
            ask "Press [Enter] to display the Parse Tree... "
            subprogram-parse-tree
            
            ask "Press [Enter] to open the Graphical Output window... "
            subprogram-graphical-output
        ]
    ]
]

main
