# Magic Commands

> Some of this documentation is a work in progress.

The Swift kernel has various built-in commands for downloading dependencies and interacting with the operating system. These commands start with `%` and behave like the IPython [magic commands](http://ipython.org/ipython-doc/dev/interactive/magics.html). They take the role of inline Shell commands in Python notebooks, which start with `!`.

- [Syntax](#syntax)
- [Execution](#execution)
- [Commands](#commands)
  - [`%include`](#include)
  - [`%install`](#install)
  - [`%install-extra-include-command`](#install-extra-include-command)
  - [`%install-location`](#install-location)
  - [`%install-swiftpm-environment`](#install-swiftpm-environment)
  - [`%install-swiftpm-flags`](#install-swiftpm-flags)
  - [`%install-swiftpm-import`](#install-swiftpm-import)
  - [`%system`](#system)
  - [`%test`](#test)

Magic commands are implemented in [PreprocessAndExecute.swift](https://github.com/philipturner/swift-colab/blob/main/Sources/JupyterKernel/SwiftKernel/PreprocessAndExecute.swift) and the [SwiftPMEngine](https://github.com/philipturner/swift-colab/blob/main/Sources/JupyterKernel/SwiftPMEngine) directory.

## Syntax

Each magic command accepts arguments styled like command-line arguments, unless stated otherwise. Commands initially pass into Python Regex library (`re`), which extracts the `%` directive. A Shell lexer (`shlex`) parses the rest of the line.

> This styling is a feature coming in Swift-Colab v2.3. In the current release (v2.2), magic commands have varied and inconsistent restrictions on accepted formats.

Arguments may be entered with or without quotes, and both single and double quotes work. To facilitate appropriate syntax coloring and improve legibility, please wrap text-like arguments in double quotes. The Swift parser treats these like string literals. For command-line flags, do not use quotes.

```swift
// Include quotes for the file path.
// Omit quotes for the executable name.
%system unzip "x10-binary.zip"

// Include quotes for the '-L' argument, which contains a file path.
// Omit quotes for the command-line flag '-Xlinker'.
%install-swiftpm-flags -Xlinker "-L/content/Library/..."

// Omit quotes for the special '$clear' argument.
%install-swiftpm-flags $clear

// Include single quotes for inline Swift code.
// Omit quotes when specifying Swift module names.
%include '.package(url: "https://...", branch: "main")' Module
```

## Execution

Before executing a code block, the kernel extracts (almost\*) all magic commands and executes them in the order they appear. The commands are oblivious to the surrounding Swift code. In contrast, a Python notebook executes Shell commands according to the control flow of their surrounding code. This code in a Swift notebook:

> \*`%include` is an exception to this rule.

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

## Commands

### `%include`
```
%include PATH 
```

Inject code from a source file into the interpreter. The `%include` command substitutes with the source code located at `PATH`, inserting at the command's exact location\* within the notebook cell.

- `PATH` - File path relative to the current working directory (`/content`). If the file does not exist there, it looks inside `/opt/swift/include`.

Source code injected by `%include` may not contain magic commands.

`PATH` may omit the first forward slash; prefer this style when specifying just a file name. The path registers as `/content/PATH` internally. Prepending a slash creates `/content//PATH`, which resolves to the same location.

> \*In Swift-Colab v2.0-2.2, the code would execute at the top of the current cell, even if the `%include` command appeared below other Swift code. Furthermore, the command silently failed if you previously included `PATH` during the current Jupyter session. This protective mechanism prevented duplication of the `IPythonDisplay.socket` Python object in `EnableIPythonDisplay.swift`.
>
> The behavior deviated from [swift-jupyter](https://github.com/google/swift-jupyter) and the magic command's semantic meaning. Thus, is was restored in v2.3 (not yet released).

### `%install`
```
%install SPEC MODULE [MODULE ...]
```

Build a Swift package for use inside a notebook. If a previous Jupyter session executed this command, import the cached build products. To avoid recompilation, the SwiftPM flags should match those present when the `%install` command last executed.

- `SPEC` - Specification to insert into a package manifest. Prefer to use SwiftPM version 5.0\* syntax, such as `.package(url: "", branch: ""))`, although v4.2 syntax also works for backward compatibility. Place the specification between single quotes to avoid colliding with string literals, which use double quotes.
- `MODULE` - Each package product the debugger should build and import.

> \*v5.0 syntax will be supported in Swift-Colab v2.3. Until that happens, use v4.2 syntax such as `.package(url: "", .branch(""))`.

Although the SwiftPM engine utilizes cached build products, LLDB does not automatically detect exported modules. `%install` tells the Jupyter kernel to locate and optionally recompile each `MODULE`. Always run the command before using external dependencies in a notebook.

To build packages stored on the local computer, pass `$cwd` into `.package(path: "")`. This keyword substitutes with the current working directory, which is always `/content`. The example below demonstrates directory substitution.

```swift
// Install the SimplePackage package that's in the kernel's working directory.
%install '.package(path: "$cwd/SimplePackage")' SimplePackage
```

### `%install-extra-include-command`
```
%install-extra-include-command EXECUTABLE [ARGUMENT ...]
```

- Link to forum thread that initiated this

### `%install-location`
```
%install-location PATH
```

- Link to PR that initiated this
- Has `$cwd` substitution (describe).
- Long-term cache build products with Google Drive.
- Switching install location may impact future build performance, because it changes which cached build products are visible to the Jupyter kernel.
- Packages cached in the previous location are still available to `%install-swiftpm-import`. They are also available to the interpreter with `import Module`, but I'm not sure why. I haven't been able to prevent packages from being importable by switching the install location.

### `%install-swiftpm-environment`
```
%install-swiftpm-environment EXECUTABLE [ARGUMENT ...]
%install-swiftpm-environment export KEY=VALUE
```

> Coming in Swift-Colab v2.3.

Append a line of Bash code to execute before building the package.


### `%install-swiftpm-flags`
```
%install-swiftpm-flags [FLAG ...]
%install-swiftpm-flags $clear
```

- Appends the arguments to a growing list of flags every time you execute
- The `$clear` flag was added to allow emptying SwiftPM flags. If you have `$clear` before other flags, it resets then adds the flags to the right of it.
- Explain workaround for `-Xcc -I/...` flags, but for now just hyperlink: [problem 4 in this comment](https://github.com/philipturner/swift-colab/issues/14#issuecomment-1158237894).
- `$clear` also resets anything added by `%install-swiftpm-environment` or `%install-swiftpm-import`, but not `%install-location`.

### `%install-swiftpm-import`
```
%install-swiftpm-import MODULE [MODULE ...]
```

> Coming in Swift-Colab v2.3.

Treats a previously compiled module like a library built into the Swift toolchain. This lets a Swift package's source code import the module, without declaring a dependency in `Package.swift`.

- `MODULE` - The Swift module to automatically link. Before running `%install-swiftpm-import`, execute the `%include` command that declares this module

After running each `%install` command, the Jupyter kernel records each product's location. The record stays the same even after switching install locations with `%install-location`. During an `%install-swiftpm-import`, it queries each product's file path to link the corresponding `.so` and `.swiftmodule`.

A mechanism similar to `%install-swiftpm-import` injects `JupyterDisplay` into Swift packages. This module lets external packages seamlessly communicate with the notebook's Jupyter display. Use the convention below to conditionally import `MODULE` inside a Swift package.

```swift
#if canImport(JupyterDisplay)
import JupyterDisplay
#endif

#if canImport(JupyterDisplay)
// Use symbols defined in the 'JupyterDisplay' module.
#endif
```

### `%system`
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

### `%test`
```
%test SPEC
```

> Coming in Swift-Colab v2.3.

Run Swift package tests on the package specified by `SPEC`. This does not share build products with any corresponding `%install` command, but it does cache build products from previous test runs. If you both install and test the same package in a Jupyter notebook, you will spend twice as long waiting for compilation to finish.

- `SPEC` - Specification to insert into a package manifest. Prefer to use SwiftPM version 5.0\* syntax, such as `.package(url: "", branch: ""))`, although v4.2 syntax also works for backward compatibility. Place the specification between single quotes to avoid colliding with string literals, which use double quotes.

> \*v5.0 syntax will be supported in Swift-Colab v2.3. Until that happens, use v4.2 syntax such as `.package(url: "", .branch(""))`.

This command utilizes the same SwiftPM flags as `%install`, providing a convenient way to configure and run tests in Colaboratory. The following commands affect how tests compile:

```
%install-extra-include-command
%install-location
%install-swiftpm-environment
%install-swiftpm-flags
%install-swiftpm-import
```