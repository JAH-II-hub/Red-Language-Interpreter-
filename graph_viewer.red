Red [
    Title: "Red Plot Language - Graphical Output Viewer"
    Needs: 'View
]

#include %grammar.red
#include %parser.red
#include %views.red

; Load active plot data saved by terminal_base/main.red
script-dir: either system/options/script [first split-path system/options/script] [%./]
plots-file: clean-path join script-dir %_current_plots.red

if exists? plots-file [
    plots: load plots-file
]

open-graph-window
quit
