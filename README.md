nim-confutils
=============

[![Build Status](https://travis-ci.org/status-im/nim-confutils.svg?branch=master)](https://travis-ci.org/status-im/nim-confutils)
[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Github action](https://github.com/status-im/nim-confutils/workflows/CI/badge.svg)

## Introduction

Confutils is a library that aims to solve the configuration problem
with a holistic approach. The run-time configuration of a program
is described as a plain Nim object type from which the library
automatically derives the code for handling command-line options,
configuration files and other platform-specific sources such as the
Windows registry.

The library focuses on providing a lot of compile-time configurability
and extensibility with a strong adherence to the DRY principle.

Let's illustrate the API with a highly annotated example. Our configuration
might be described in a separate module looking like this:

```nim
# config.nim
import
  confutils/defs

type
  NimbusConf* = object
    #
    # This is our configuration type.
    #
    # Each field will be considered a configuration option that may appear
    # on the command-line, whitin an environment variable or a configuration
    # file, or elsewhere. Custom pragmas are used to annotate the fields with
    # additional metadata that is used to augment the behavior of the library.
    #
    logLevel* {.
      defaultValue: LogLevel.INFO
      desc: "Sets the log level" }: LogLevel

    #
    # This program uses a CLI interface with sub-commands (similar to git).
    #
    # The `StartUpCommand` enum provides the list of available sub-commands,
    # but since we are specifying a default value of `noCommand`, the user
    # can also launch the program without entering any particular command.
    # The default command will also be omitted from help messages.
    #
    # Please note that the `logLevel` option above will be shared by all
    # sub-commands. The rest of the nested options will be relevant only
    # when the designated sub-command is being invoked.
    #
    case cmd* {.
      command
      defaultValue: noCommand }: StartUpCommand

    of noCommand:
      dataDir* {.
        defaultValue: getConfigDir() / "nimbus"
        desc: "The directory where nimbus will store all blockchain data."
        abbr: "d" }: DirPath

      bootstrapNodes* {.
        desc: "Specifies one or more bootstrap nodes to use when connecting to the network."
        abbr: "b"
        name: "bootstrap-node" }: seq[string]

      bootstrapNodesFile* {.
        defaultValue: ""
        desc: "Specifies a line-delimited file of bootsrap Ethereum network addresses"
        abbr: "f" }: InputFile

      tcpPort* {.
        desc: "TCP listening port" }: int

      udpPort* {.
        desc: "UDP listening port" }: int

      validators* {.
        required
        desc: "A path to a pair of public and private keys for a validator. " &
              "Nimbus will automatically add the extensions .privkey and .pubkey."
        abbr: "v"
        name: "validator" }: seq[PrivateValidatorData]

      stateSnapshot* {.
        desc: "Json file specifying a recent state snapshot"
        abbr: "s" }: Option[BeaconState]

    of createChain:
      chainStartupData* {.
        desc: ""
        abbr: "c" }: ChainStartupData

      outputStateFile* {.
        desc: "Output file where to write the initial state snapshot"
        name: "out"
        abbr: "o" }: OutFilePath

  StartUpCommand* = enum
    noCommand
    createChain

  #
  # The configuration can use user-defined types that feature custom
  # command-line parsing and serialization routines.
  #
  PrivateValidatorData* = object
    privKey*: ValidatorPrivKey
    randao*: Randao

```

Then from our main module, we just need to call `confutils.load` which must be
given our configuration type as a parameter:

```nim
# main.nim
import
  confutils, config

when isMainModule:
  let conf = NimbusConf.load()
  initDatabase conf.dataDir
```

And that's it - calling `load` with default parameters will first process any
[command-line options](#handling-of-command-line-options) and then it will
try to load any missing options from the most appropriate
[configuration location](#handling-of-environment-variables-and-config-files)
for the platform. Diagnostic messages will be provided for many simple
configuration errors and the following help message will be produced
automatically when calling the program with `program --help`:

```
Usage: beacon_node [OPTIONS] <command>

The following options are supported:

  --logLevel=LogLevel                        : Sets the log level
  --dataDir=DirPath                          : The directory where nimbus will store all blockchain data.
  --bootstrapNode=seq[string]                : Specifies one or more bootstrap nodes to use when connecting to the network.
  --bootstrapNodesFile=FilePath              : Specifies a line-delimited file of bootsrap Ethereum network addresses
  --tcpPort=int                              : TCP listening port
  --udpPort=int                              : UDP listening port
  --validator=seq[PrivateValidatorData]      : A path to a pair of public and private keys for a validator. Nimbus will automatically add the extensions .privkey and .pubkey.
  --stateSnapshot=Option[BeaconState]        : Json file specifying a recent state snapshot

Available sub-commands:

  beacon_node createChain

  --out=OutFilePath                          : Output file where to write the initial state snapshot

```

For simpler CLI utilities, Confutils also provides the following convenience APIs:

```nim
import
  confutils

cli do (validators {.
          desc: "number of validators"
          abbr: "v" }: int,

        outputDir {.
          desc: "output dir to store the generated files"
          abbr: "o" }: OutPath,

        startupDelay {.
          desc: "delay in seconds before starting the simulation" } = 0):

  if validators < 64:
    echo "The number of validators must be greater than EPOCH_LENGTH (64)"
    quit(1)
```

```nim
import
  confutils

proc main(foo: string, bar: int) =
  ...

dispatch(main)
```

Under the hood, using these APIs will result in calling `load` on an anonymous
configuration type having the same fields as the supplied proc params.
Any additional arguments given as `cli(args) do ...` and `dispatch(fn, args)`
will be passed to `load` without modification. Please note that this requires
all parameters types to be concrete (non-generic).

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

```nim
template longDesc*(v: string) {.pragma.}
```

A long description text that will appear below regular desc. You can use
one of {'\n', '\r'} to break it into multiple lines. But you can't use
'\p' as line break.

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

This must be applied to an enum field that represents a possible sub-command.
See the section on [sub-commands](#Using-sub-commands) for more details.

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

#### `ConfigFilePath[Format]`

A file system path pointing to a configuration file in the specific format.
The actual configuration can be loaded by calling `load(path, ConfigType)`.
When the format is `WindowsRegistry` the path should indicate a registry key.

#### `OutPath`

A valid path must be given.

--------------

Furthermore, you can extend the behavior of the library by providing
overloads such as:

```nim
proc parseCmdArg*(T: type Foo, p: string): T =
  ## This provides parsing and validation for fields having the `Foo` type.
  ## You should raise `ConfigurationError` in case of detected problems.
  ...

proc humaneTypeName*[T](_: type MyList[T]): string =
  ## The returned string will be used in the help messages produced by the
  ## library to describe the expected type of the configuration option.
  mixin humaneTypeName
  return "list of " & humaneTypeName(T)
```

For config files, Confutils can work with any format supported by the
[nim-serialization](https://github.com/status-im/nim-serialization/) library
and it will use the standard serialization routines defined for the field
types in this format. Fields marked with the `command` or `argument` pragmas
will be ignored.

## Handling of command-line options

Confutils includes parsers that can mimic several traditional styles of
command line interfaces. You can select the parser being used by specifying
the `CmdParser` option when calling the configuration loading APIs.

The default parser of Confutils is called `MixedCmdParser`. It tries to follow
the [robustness principle](https://en.wikipedia.org/wiki/Robustness_principle)
by recognizing as many styles of passing command-line switches as possible.
A prefix of `--` is used to indicate a long option name, while the `-` prefix
uses the short option name. Multiple short options such as `-a`, `-b` and
`-c` can be combined into a single `-abc` string. Both the long and the short
forms can also be prefixed with `/` in the style of Windows utilities. The
option names are matched in case-insensitive fashion and certain characters
such as `_` and `-` will be ignored. The values can be separated from the
option names with a space, colon or an equal sign. `bool` flags default to
`false` and merely including them in the command line sets them to `true`.

Other provided choices are `UnixCmdParser`, `WindowsCmdParser` and `NimCmdParser`
which are based on more strict grammars following the most established
tradition of the respective platforms. All of the discussed parsers are
defined in terms of the lower-level parametric type `CustomCmdParser` that
can be tweaked further for a more custom behavior.

Please note that the choice of `CmdParser` will also affect the formatting
of the help messages. Please see the definition of the standard [Windows][WIN_CMD]
or [Posix][POSIX_CMD] command-line help syntax for mode details.

[WIN_CMD]: https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/command-line-syntax-key
[POSIX_CMD]: http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html

### Using sub-commands

As seen in the [introduction example](#introduction), Confutils makes it
easy to create command-line interfaces featuring sub-commands in the style
of `git` or `nimble`. The structure of the sub-command tree is encoded as
a Nim case object where the sub-command name is represented by an `enum`
field having the `command` pragma. Any nested fields will be considered
options of the particular sub-command. The top-level fields will be shared
between all sub-commands.

For each available choice of command and options, Confutils will automatically
provide a `help` command and the following additional switches:

* `-h` will print a short syntax reminder for the command
* `--help` will print a full help message (just like the `help` command)

## Handling of environment variables and config files

After parsing the command line options, the default behavior of Confutils is
to try to fill any missing options by examining the contents of the environment
variables plus two per-user and system-wide configuration locations derived from
the program name. If you want to use Confutils only as a command-line processor
or a config file parser for example, you can supply an empty/nil value to the
`cmdLine`, `envTable` or `configFileEnumerator` parameters of the `load` call.

More specifically, the `load` call supports the following parameters:

#### `cmdLine`, `envTable`

The command-line parameters and the environment table of the program.
By default, these will be obtained through Nim's `os` module.

#### `EnvValuesFormat`, `envVarsPrefix`

A nim-serialization format used to deserialize the values of environment
variables. The default format is called `CmdLineFormat` and it uses the
same `parseCmdArg` calls responsible for parsing the command-line.

The names of the environment variables are prefixed by the name of the
program by default. They are matched in case-insensitive fashion and
certain characters such as `-` and `_` are ignored.

#### `configFileEnumerator`

A function responsible for returning a sequence of `ConfigFilePath` objects.
To support heterogenous config file types, you can also return a tuple of
sequences. The default behavior of Windows is to obtain the configuration
from the Windows registry by looking at the following keys:

```
HKEY_CURRENT_USER/SOFTWARE/{appVendor}/{appName}/
HKEY_LOCAL_MACHINE/SOFTWARE/{appVendor}/{appName}/
```

On Posix systems, the default behavior is attempt to load the configuration
from the following files:

```
/$HOME/.config/{appName}.{ConfigFileFormat.extension}
/etc/{appName}.{ConfigFileForamt.extension}
```

#### `ConfigFileFormat`

A [nim-serialization](https://github.com/status-im/nim-serialization) format
that will be used by default by Confutils.

## Customization of the help messages

The `load` call offers few more optional parameters for modifying the
produced help messages:

#### `bannerBeforeHelp`

A copyright banner or a similar message that will appear before the
automatically generated help messages.

#### `bannerAfterHelp`

A copyright banner or a similar message that will appear after the
automatically generated help messages.

#### `version`

If you provide this parameter, Confutils will automatically respond
to the standard `--version` switch. If sub-commands are used, an
additional `version` top-level command will be inserted as well.

## Compile-time options

#### `confutils_colors`

This option controls the use of colors appearing in the help messages
produced by Confutils. Possible values are:

- `NativeColors` (used by default)

  In this mode, Windows builds will produce output suitable for the console
  application in older versions of Windows. On Unix-like systems, this is
  equivalent to specifying `AnsiColors`.

- `AnsiColors`

  Output suitable for terminals supporting the standard ANSI escape codes:
  https://en.wikipedia.org/wiki/ANSI_escape_code

  This includes most terminal emulators on modern Unix-like systems,
  Windows console replacements such as ConEmu, and the native Console
  and PowerShell applications on Windows 10.

- `None` or `NoColors`

  All output will be colorless.

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

