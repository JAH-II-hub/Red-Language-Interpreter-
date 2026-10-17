Red []

grammar-text: {
LANGUAGE GRAMMAR

<graph>      -> start <plot_stmts> end
<plot_stmts> -> <plot> | <plot> ; <plot_stmts>
<plot>       -> bar <x><y>,<y>
             | line <x><y>,<x><y>
             | grid <x><y>
             | fill <x><y>
<x>          -> a | b | c | d | e | f | g | h | i | j
<y>          -> 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
}

valid-letters: "abcdefghij"
valid-digits: "0123456789"
plots: copy []
plot-texts: copy []
derivation: copy []
parse-error: ""
last-valid: false
