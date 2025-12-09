nim-confutils
=============

[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Github action](https://github.com/status-im/nim-confutils/workflows/CI/badge.svg)

## Introduction

Confutils is a Nim library for creating command line interfaces with as
little code as necessary. It focuses on providing a lot of compile-time
configurability and extensibility.

The CLI run-time configuration is generated at compile-time from a Nim
object type definition annotated with pragmas. This configuration
is then used to:

- Parse command-line options and arguments.
- Read values from environment variables.
- Load options from configuration files (and the Windows registry).
- Automaticly generate the help page.

Here is an example of a simple Confutils program:

```nim
# hello.nim

import confutils

type
  Hello = object
    name {.
      name: "name"
      desc: "Name to greet" .}: string
    count {.
      name: "count"
      defaultValue: 1
      desc: "Number of greetings" .}: int

proc hello(conf: Hello) =
  for x in 0 ..< conf.count:
    echo "Hello ", conf.name

proc main() =
  let conf = Hello.load(copyrightBanner="A simple hello program")
  hello(conf)

when isMainModule:
  main()
```

Running the program:

```
$ nim c -r hello.nim --name="World" --count=3
Hello World
Hello World
Hello World
```

It automatically generates nicely formatted help pages:

```
$ nim c -r hello.nim --help
A simple hello program

Usage: 

test2 [OPTIONS]...

The following options are available:

 --name       Name to greet.
 --count      Number of greetings [=1].
```

For simpler CLI utilities:

```nim
import confutils

cli do(
  name {.name: "name", desc: "Name to greet".}: string,
  count {.name: "count", defaultValue: 1, desc: "Number of greetings".}: int
):
  for x in 0 ..< count:
    echo "Hello ", name
```

For even simpler CLI utilities:

```nim
import confutils

proc hello(name: string, count: int) =
  for x in 0 ..< count:
    echo "Hello ", name

dispatch(hello)
```

Under the hood, using these APIs will result in calling `load` on an anonymous
configuration type having the same fields as the supplied proc params.
Any additional arguments given as `cli(args) do ...` and `dispatch(fn, args)`
will be passed to `load` without modification. Please note that this requires
all parameters types to be concrete (non-generic).

## Sub-commands

Confutils makes it easy to create CLIs in the style of `git` or `nimble`. The structure of the sub-command tree is encoded as a case object where the sub-command name is represented by an `enum` field having the `command` pragma. The sub-commands can be deeply nested. Any nested fields will be considered options of the particular sub-command. The top-level fields will be shared between all sub-commands. Each sub-command automatically provides a `--help` command.

```nim
# config.nim
import confutils/defs
import confutils/std/net

const defaultEth2TcpPort* = 9000

type
  BNStartUpCmd* {.pure.} = enum
    beaconNode
    deposits

  NimbusConf* = object
    # Global options.

    logLevel* {.
      desc: "Sets the log level"
      defaultValue: "INFO" .}: string

    # Subcommands.
    case cmd* {.
      command
      defaultValue: BNStartUpCmd.beaconNode .}: BNStartUpCmd

    of BNStartUpCmd.beaconNode:
      # Default subcommand when no subcommand is specified.
      # The options defined here are not global.

      listenAddress* {.
        desc: "Listening address for the Ethereum LibP2P and Discovery v5 traffic"
        defaultValueDesc: "*"
        name: "listen-address" .}: Option[IpAddress]

      tcpPort* {.
        desc: "Listening TCP port for Ethereum LibP2P traffic"
        defaultValue: defaultEth2TcpPort
        defaultValueDesc: $defaultEth2TcpPort
        name: "tcp-port" .}: Port

    of BNStartUpCmd.deposits:
      # deposits subcommand.

      totalDeposits* {.
        desc: "Number of deposits to generate"
        defaultValue: 1
        name: "count" .}: int
```

Then from our main module:

```nim
# main.nim
import confutils
import ./config

when isMainModule:
  let conf = NimbusConf.load()
  echo "Log-level: ", conf.logLevel
  case conf.cmd:
  of BNStartUpCmd.beaconNode:
    echo "Port: ", $conf.tcpPort.int
  of BNStartUpCmd.deposits:
    echo "Total deposits: ", conf.totalDeposits
```

Running the program:

```
$ nim c -r main.nim --loglevel=WARN deposits --count=123
Log level: WARN
Total deposits: 123
```

And that's it - calling `load` with default parameters will first process any
[command-line options](#handling-of-command-line-options) and then it will
try to load any missing options from the most appropriate
[configuration location](#handling-of-environment-variables-and-config-files)
for the platform. Diagnostic messages will be provided for many simple
configuration errors and the following help message will be produced
automatically when calling the program with `program --help`:

This covers the basic usage of the library and the rest of the documentation
will describe the various ways the default behavior can be tweaked or extended.

## Configuration field pragmas

A number of pragmas defined in `confutils/defs` can be attached to the
configuration fields to control the behavior of the library.

```nim
template desc*(v: string) {.pragma.}
```

A description of the configuration option that will appear in the produced
help messages.

-----------------

```nim
template longDesc*(v: string) {.pragma.}
```

A long description text that will appear below regular `desc`. You can use
one of `{'\n', '\r'}` to break it into multiple lines. But you can't use
`'\p'` as line break.

```text
 -x, --name   regular description [=defVal].
              longdesc line one.
              longdesc line two.
              longdesc line three.
```

-----------------

```nim
template name*(v: string) {.pragma.}
```

A long name of the option.
Typically, it will have to be be specified as `--longOptionName value`.
See [Handling of command-line options](#handling-of-command-line-options)
for more details.

-----------------

```nim
template abbr*(v: string) {.pragma.}
```

A short name of the option.
Typically, it will be required to be specified as `-x value`.
See [Handling of command-line options](#handling-of-command-line-options)
for more details.

-----------------

```nim
template defaultValue*(v: untyped) {.pragma.}
```

The default value of the option if no value was supplied by the user.

-----------------

```nim
template required* {.pragma.}
```

By default, all options without default values are considered required.
An exception to this rule are all `seq[T]` or `Option[T]` options for
which the "empty" value can be considered a reasonable default. You can
also extend this behavior to other user-defined types by providing the
following overloads:

```nim
template hasDefault*(T: type Foo): bool = true
template default*(T: type Foo): Foo = Foo(...)
```

The `required` pragma can be applied to fields having such defaultable
types to make them required.

-----------------

```nim
template command* {.pragma.}
```

This must be applied to an `enum` field that represents a possible sub-command.
See the section on [sub-commands](#Sub-commands) for more details.

-----------------

```nim
template argument* {.pragma.}
```

This field represents an argument to the program. If the program expects
multiple arguments, this pragma can be applied to multiple fields or to
a single `seq[T]` field depending on the desired behavior.

-----------------

```nim
template separator(v: string)* {.pragma.}
```

Using this pragma, a customizable separator text will be displayed just before
this field. E.g.:

```text
Network Options:     # this is a separator
  -a, --opt1 desc
  -b, --opt2 desc

----------------     # this is a separator too
  -c, --opt3 desc
```

## Configuration field types

The `confutils/defs` module provides a number of types frequently used
for configuration purposes:

#### `InputFile`, `InputDir`

Confutils will validate that the file/directory exists and that it can
be read by the current user.

#### `OutPath`

A valid path must be given.

## Custom argument parsing

Furthermore, you can extend the behavior of the library by providing
overloads such as:

```nim
proc parseCmdArg*(T: type Foo, p: string): T =
  ## This provides parsing and validation for fields having the `Foo` type.
  ## You should raise `ConfigurationError` in case of detected problems.
  toFoo(p)
```

## Config files

For config files, Confutils can work with any format supported by the
[nim-serialization](https://github.com/status-im/nim-serialization/) library
and it will use the standard serialization routines defined for the field
types in this format. Fields marked with the `command` or `argument` pragmas
will be ignored.

## Handling of command-line options

Confutils parser tries to follow the
[robustness principle](https://en.wikipedia.org/wiki/Robustness_principle)
by recognizing as many styles of passing command-line switches as possible.
A prefix of `--` is used to indicate a long option name, while the `-` prefix
uses the short option name. Multiple short options such as `-a`, `-b` and
`-c` can be combined into a single `-abc` string. The option names are matched
in case-insensitive fashion and certain characters
such as `_` will be ignored. The values can be separated from the
option names with a colon or an equal sign. `bool` flags default to
`false` and merely including them in the command line sets them to `true`.

## Handling of environment variables and config files

After parsing the command-line options, the default behavior of Confutils is
to try to fill any missing options by examining the contents of the environment
variables. If you want to use Confutils only as a command-line processor
or a config file parser for example, you can supply an empty value to the
`cmdLine` parameter of the `load` call.

More specifically, the `load` call supports the following parameters:

#### `cmdLine`

The command-line parameters of the program.
By default, these will be obtained through Nim's `os` module.

#### `envVarsPrefix`

The names of the environment variables are prefixed by the name of the
program by default and joined with the name of command line option, which is 
uppercased and characters `-` and spaces are replaced with underscore:

```nim
let env_variable_name = &"{prefix}_{key}".toUpperAscii.multiReplace(("-", "_"), (" ", "_"))
```

#### `secondarySources`

A callback to add secondary config file sources. The source must be
a [nim-serialization format](https://github.com/status-im/nim-serialization?#available-serialization-formats).

Confutils implements a Windows register decoder. The default
behavior of Windows is to obtain the configuration
from the Windows registry by looking at the following keys:

```
HKEY_CURRENT_USER/SOFTWARE/{appVendor}/{appName}/
HKEY_LOCAL_MACHINE/SOFTWARE/{appVendor}/{appName}/
```

## Customization of the help messages

The `load` call offers few more optional parameters for modifying the
produced help messages:

#### `copyrightBanner`

A copyright banner or a similar message that will appear before the
automatically generated help messages.

#### `version`

If you provide this parameter, Confutils will automatically respond
to the standard `--version` switch. If sub-commands are used, an
additional `version` top-level command will be inserted as well.

## Compile-time options

#### `confutilsNoColors`

If `-d:confutilsNoColors` is defined all output will be colorless.
Otherwise, native colors are used. ANSI escape sequences on UNIX.
On Windows the Windows API is used.

## Contributing

The development of Confutils is sponsored by [Status.im](https://status.im/)
through the use of [GitCoin](https://gitcoin.co/). Please take a look at our
tracker for any issues having the [bounty][BOUNTIES] tag.

When submitting pull requests, please add test cases for any new features
or fixes and make sure `nimble test` is still able to execute the entire
test suite successfully.

[BOUNTIES]: https://github.com/status-im/nim-confutils/issues?q=is%3Aissue+is%3Aopen+label%3Abounty

## License

Licensed and distributed under either of

* MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

* Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. This file may not be copied, modified, or distributed except according to those terms.

