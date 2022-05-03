# Built-In "`%`" Directives

(there are commands, they are here because _ and they do _). Each should have a description and example of usage.

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

## `%install-extra-include-command`
```
%install-extra-include-command
```

## `%install-location`
```
%install-location
```

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
