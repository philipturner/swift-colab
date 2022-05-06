# Magic Commands

> TODO: Each should have an example of usage in its description.

The Swift interpreter has various built-in commands for downloading dependencies and interacting with the operating system. These start with `%` and behave like the IPython [magic commands](http://ipython.org/ipython-doc/dev/interactive/magics.html). They take the role of inline Shell commands in Python notebooks, which start with `!`.

- [Execution Behavior](#execution-behavior)
- [`%include`](#include)
- [`%install`](#install)
- [`%install-extra-include-command`](#install-extra-include-command)
- [`%install-location`](#install-location)
- [`%install-swiftpm-flags`](#install-swiftpm-flags)
- [`%system`](#system)

Magic commands are implemented in [PreprocessAndExecute.swift](https://github.com/philipturner/swift-colab/blob/main/Sources/JupyterKernel/SwiftKernel/PreprocessAndExecute.swift) and [ProcessInstalls.swift](https://github.com/philipturner/swift-colab/blob/main/Sources/JupyterKernel/SwiftKernel/ProcessInstalls.swift).

## Execution Behavior

Before executing a code block, the kernel extracts all magic commands and executes them in the order they appear. They are oblivious to the surrounding Swift code, whereas Python Shell commands follow the control flow of Python code.

This code in a Swift notebook: (TODO: does "echo" work?)
```swift
for i in 0..<2 {
%system command-that-prints "A"
  print("B")
%system command-that-prints "C"
  print("D")
}
```
Produces (replacing newlines with spaces):
```
A C B D B D
```

While this code in a Python notebook:
```python
for i in range 2:
  !echo A
  print('B')
  !echo C
  print('D')
```
Produces (replacing newlines with spaces):
```
A B C D A B C D
```

## `%include`
```
%include FILEPATH
```

- Doesn't include a file twice, clarify what that means with an example, it does that for exclusivity of type objects. LLDB allows re-declaring of symbols, which is fine for local variables but not for type objects which get overwritten.
- Does it inject code in the middle of a Swift source file? I don't think so because they are parsed beforehand.

## `%install`
```
%install SPEC PRODUCT [PRODUCT ...]
```

- The command that downloads Swift packages.
- Swift 4.2-style package initializer for ergonomics and backward compatibility.
- Has `$cwd` substitution (describe).
- How to prevent a package from recompiling (same toolchain, same SwiftPM flags)
- This is also the command that loads a package into LLDB, so must run before calling `import XXX`

## `%install-extra-include-command`
```
%install-extra-include-command
```

- Link to forum thread that initiated this

## `%install-location`
```
%install-location
```

- Link to PR that initiated this
- Has `$cwd` substitution (describe).

## `%install-swiftpm-flags`
```
%install-swiftpm-flags [FLAG ...]
```

- Appends the arguments to a growing list of flags every time you execute
- The `$clear` flag, was added to allow emptying SwiftPM flags. If you have `$clear` before other flags, it resets then adds the flags to the right of it.

## `%system`
```
%system EXECUTABLE [ARGUMENT ...]
```

- Executes a command-line command, executes before the code in the cell
- Does not forward print output (yet), so better to use bash in Python mode right now
```swift
%system cd "sample_data" && touch "$(uname -m).sh"
```
The code above works and makes a file called `x86_64.sh` in `/content/sample_data`.
