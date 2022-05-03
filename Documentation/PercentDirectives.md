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
- How to prevent a package from recompiling
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
%install-swiftpm-flags
```

- The `$clear` flag, why it was added

## `%system`
```
%system
```
