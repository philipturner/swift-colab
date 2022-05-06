# Built-In "`%`" Directives

Swift Colab notebooks have various built-in commands for downloading external libraries and interacting with the operating system. These mirror and substitute the usage of inline Shell code in Python notebooks, with slightly different behavior:

- They start with `%` instead of `!`. Instead of passing the code into a terminal, they function like IPython's ["magic" commands](http://ipython.org/ipython-doc/dev/interactive/magics.html), which also start with `%`.
- The Swift kernel extracts them from a code block and executes them separately. They execute before all other Swift code in a code block, even if the Swift code appears before them.
- Regardless of whether a Swift `for` loop surrounds a command, it always executes once. In the Python kernel, Shell code follows the program's control flow. This means it may never run or could run more than once.

The code that handles them can be found in LINK TO SOURCE FILE.

TODO: Each should have a description and example of usage.

- [`%include`](#include)
- [`%install`](#install)
- [`%install-extra-include-command`](#install-extra-include-command)
- [`%install-location`](#install-location)
- [`%install-swiftpm-flags`](#install-swiftpm-flags)
- [`%system`](#system)

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

- Swift 4.2-style package initializer for ergonomics and backward compatibility
- The `$cwd` substitution
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
- The `$cwd` substitution?

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
- Does it work with stuff like `mkdir`, `ls`, `touch`?
