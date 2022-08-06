# Magic Commands

The Swift kernel has various built-in commands for downloading dependencies and interacting with the operating system. These commands start with `%` and behave like the IPython [magic commands](http://ipython.org/ipython-doc/dev/interactive/magics.html). They take the role of inline Shell commands in Python notebooks, which start with `!`.

- [`%include`](#include)
- [`%install`](#install)
- [`%install-extra-include-command`](#install-extra-include-command)
- [`%install-location`](#install-location)
- [`%install-swiftpm-flags`](#install-swiftpm-flags)
- [`%system`](#system)

Magic commands are implemented in [PreprocessAndExecute.swift](https://github.com/philipturner/swift-colab/blob/main/Sources/JupyterKernel/SwiftKernel/PreprocessAndExecute.swift) and [ProcessInstalls.swift](https://github.com/philipturner/swift-colab/blob/main/Sources/JupyterKernel/SwiftKernel/ProcessInstalls.swift).

## Execution Behavior

Before executing a code block, the kernel extracts all magic commands and executes them in the order they appear. The commands are oblivious to the surrounding Swift code. In contrast, a Python notebook executes Shell commands according to the control flow of their surrounding code. For example, this code in a Swift notebook:
```swift
for _ in 0..<2 {
%system echo "A"
  print("B")
%system echo "C"
  print("D")
}
```
Produces (replacing newlines with spaces):
```
A C B D B D
```

While this code in a Python notebook:
```python
for i in range(2):
  !echo A
  print('B')
  !echo C
  print('D')
```
Produces (replacing newlines with spaces):
```
A B C D A B C D
```

> Everything below this point is a work in progress.

---

> TODO: Each command should have an example of usage in its description.

## `%include`
```swift
%include FILEPATH [--force]
```

Inject code from a source file into the interpreter. The code executes at the top of the current cell, even if the `%include` command appears below other Swift code.

- `FILEPATH` - File path relative to the current working directory (`/content`), omitting the first forward flash. If the file does not exist there, it looks inside `/opt/swift/include`.
- `--force`\* - The command silently fails if you already included it during the current Jupyter session. This protective mechanism prevents duplication of type objects. Use `--force` to override the mechanism and include the file multiple times.

> \*This feature does not currently exist. It will be enabled in Swift-Colab v2.3.

## `%install`
```swift
%install SPEC PRODUCT [PRODUCT ...]
```

Build a Swift package for use inside a notebook. If a previous Jupyter session executed this command, import the cached build products. To avoid recompilation, the SwiftPM flags should match those present when the `%install` command last executed.

- `SPEC` - Specification to insert into a package manifest. Use SwiftPM version 4.2\* syntax, such as `.package(url: "", .branch(""))`. Place the specification between single quotes to avoid colliding with string literals, which use double quotes.
- `PRODUCT` - Each exported Swift module the debugger should build and import.

> *Do not use version 5.0 syntax, such as `.package(url: "", branch: "")`. This syntax will be permitted in Swift-Colab v2.3.

Although the SwiftPM engine utilizes cached build products, LLDB does not automatically detect those products. `%install` tells the Jupyter kernel to locate and optionally recompile each `PRODUCT`. Always run the command before using external dependencies in a notebook.

To build packages stored on the local computer, pass `$cwd` into `.package(path: "")`. This keyword substitutes with the current working directory, which is always `/content`. The example below demonstrates directory substitution.

```swift
// Install the SimplePackage package that's in the kernel's working directory.
%install '.package(path: "$cwd/SimplePackage")' SimplePackage
```

## `%install-extra-include-command`
```swift
%install-extra-include-command EXECUTABLE [ARGUMENT ...]
```

- Link to forum thread that initiated this

## `%install-location`
```swift
%install-location DIRECTORY
```

- Link to PR that initiated this
- Has `$cwd` substitution (describe).

## `%install-swiftpm-flags`
```swift
%install-swiftpm-flags [FLAG ...]
```

- Appends the arguments to a growing list of flags every time you execute
- The `$clear` flag, was added to allow emptying SwiftPM flags. If you have `$clear` before other flags, it resets then adds the flags to the right of it.
- Explain workaround for `-Xcc -I/...` flags, but for now just hyperlink: [problem 4 in this comment](https://github.com/philipturner/swift-colab/issues/14#issuecomment-1158237894).

## `%system`
```swift
%system EXECUTABLE [ARGUMENT ...]
```

- Executes a command-line command, executes before the code in the cell
- Forwards stdout just like Python bash commands, but not stdin (tracked by https://github.com/philipturner/swift-colab/issues/17)
- Works in Python mode because it’s a Jupyter magic command. The Python mode version prints the output like a comma-separated list instead of actual stdout.

```swift
%system cd "sample_data" && touch "$(uname -m).sh"
```
The code above works and makes a file called `x86_64.sh` in `/content/sample_data`.
