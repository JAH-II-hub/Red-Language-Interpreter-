# Red Plot Language Interpreter: How to Run

> **Windows only.** This program works properly only on Windows. It will not work correctly on Linux.

## 1. Get the files

Copy all five project files into one folder on your computer:

- `main.red`
- `grammar.red`
- `parser.red`
- `views.red`
- `graph_viewer.red`

## 2. Download Red

Download the Red 0.6.6 program from <https://www.red-lang.org/p/download.html>:

- `red-view-066.exe`

Save it in the same folder as the project files.

## 3. Run the program

1. Open **red-view-066.exe**.
2. Go to the project folder, for example:
   ```
   cd %C/path/to/project-folder
   ```
3. Start the program:
   ```
   do %main.red
   ```

## 4. Use the program

1. At the `Enter sentence>` prompt, type a sentence and press **Enter**. For example:
   ```
   start grid e5; bar b3,2; line a1,d4 end
   ```
2. If the sentence is valid, the leftmost derivation is shown.
3. Press **Enter** to display the parse tree.
4. Press **Enter** again to open the graph window.
5. Close the window (or click **Continue**) to return to the prompt and enter another sentence.

## 5. Exit

Type `STOP` in **uppercase** at the prompt and press **Enter**.