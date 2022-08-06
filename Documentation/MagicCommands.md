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
```
%include FILEPATH
```

- Doesn't include a file twice, clarify what that means with an example, it does that for exclusivity of type objects. LLDB allows re-declaring of symbols, which is fine for local variables but not for type objects which get overwritten.
- Does it inject code in the middle of a Swift source file? I don't think so because they are parsed beforehand.
- Does this use `$cwd`?

## `%install`
```swift
%install SPEC PRODUCT [PRODUCT ...]
```

Build a Swift package for use inside a notebook. If a previous Jupyter session executed this command, import the cached build products. To avoid recompilation, ensure the SwiftPM flags match those originally used to build the package.

- `SPEC` - Specification to be inserted into a package manifest. Use SwiftPM version 4.2 syntax, such as `.package(url: "", .branch(""))`. Do not use version 5.0 syntax (`.package(url: "", branch: "")`). Place the specification between single quotes to avoid colliding with string literals, which use double quotes.
- `PRODUCT` - Any Swift module the debugger should compile and import.

Although this utilizes cached build products, LLDB does not automatically detect those products. `%install` tells the Jupyter kernel to locate and optionally recompile each `PRODUCT`. Always run the command before using external dependencies in a notebook.

To build packages stored on the local computer, pass `$cwd` into `.package(path: "")`. This keyword substitutes with the current working directory, which is always `/content`. The example below demonstrates directory substitution.

```swift
// Install the SimplePackage package that's in the kernel's working directory.
%install '.package(path: "$cwd/SimplePackage")' SimplePackage
```

## `%install-extra-include-command`
```
%install-extra-include-command EXECUTABLE [ARGUMENT ...]
```

- Link to forum thread that initiated this

## `%install-location`
```
%install-location DIRECTORY
```

- Link to PR that initiated this
- Has `$cwd` substitution (describe).

## `%install-swiftpm-flags`
```
%install-swiftpm-flags [FLAG ...]
```

- Appends the arguments to a growing list of flags every time you execute
- The `$clear` flag, was added to allow emptying SwiftPM flags. If you have `$clear` before other flags, it resets then adds the flags to the right of it.
- Explain workaround for `-Xcc -I/...` flags, but for now just hyperlink: [problem 4 in this comment](https://github.com/philipturner/swift-colab/issues/14#issuecomment-1158237894).

## `%system`
```
%system EXECUTABLE [ARGUMENT ...]
```

- Executes a command-line command, executes before the code in the cell
- Forwards stdout just like Python bash commands, but not stdin (tracked by https://github.com/philipturner/swift-colab/issues/17)
- Works in Python mode because it’s a Jupyter magic command. The Python mode version prints the output like a comma-separated list instead of actual stdout.

```swift
%system cd "sample_data" && touch "$(uname -m).sh"
```
The code above works and makes a file called `x86_64.sh` in `/content/sample_data`.
