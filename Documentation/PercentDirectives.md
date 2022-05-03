# Built-In "`%`" Directives

(there are commands, they are here because _ and they do _). Each should have a description and example of usage.

- Execute before all other code

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

- Doesn't include a file twice, clarify what that means with an example, explain why it does that

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
