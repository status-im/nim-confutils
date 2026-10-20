# confutils
# Copyright (c) 2018-2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/os, unittest2, toml_serialization, toml_serialization/pkg/results,
  ../confutils

const configFilePath = "tests" / "config_files"

template loadFile(T, file): untyped =
  proc (
    config: T, sources: ref SecondarySources
  ) {.raises: [ConfigurationError].} =
    sources.addConfigFileWithParams(
      Toml, InputFile(configFilePath / file), flags = {TomlInlineTableNewline}
    )

template loadContent(T, cont): untyped =
  proc (
    config: T, sources: ref SecondarySources
  ) {.raises: [ConfigurationError].} =
    sources.addConfigFileContentWithParams(
      Toml, cont, flags = {TomlInlineTableNewline}
    )

type
  OuterCmd = enum
    noCommand
    outerCmd1

  InnerCmd = enum
    innerCmd1 = "Inner cmd 1"
    innerCmd2 = "Inner cmd 2"

  TestConf = object
    case cmd {.
      command
      defaultValue: OuterCmd.noCommand }: OuterCmd
    of OuterCmd.noCommand:
      outerArg {.
        defaultValue: "outerArg default"
        desc: "outerArg desc"
        name: "outer-arg" }: string
    of OuterCmd.outerCmd1:
      outerArg1 {.
        defaultValue: "outerArg1 default"
        desc: "outerArg1 desc"
        name: "outer-arg1" }: string
      case innerCmd {.command.}: InnerCmd
      of InnerCmd.innerCmd1:
        innerArg1 {.
          defaultValue: "innerArg1 default"
          desc: "innerArg1 desc"
          name: "inner-arg1" }: string
      of InnerCmd.innerCmd2:
        innerArg2 {.
          defaultValue: "innerArg2 default"
          desc: "innerArg2 desc"
          name: "inner-arg2" }: string

  TestConfNonFirstDefault = object
    case cmd {.
      command
      defaultValue: OuterCmd.outerCmd1 }: OuterCmd
    of OuterCmd.noCommand:
      outerArg {.
        defaultValue: "outerArg default"
        desc: "outerArg desc"
        name: "outer-arg" }: string
    of OuterCmd.outerCmd1:
      outerArg1 {.
        defaultValue: "outerArg1 default"
        desc: "outerArg1 desc"
        name: "outer-arg1" }: string

  NumberedCmd = enum
    numberedCmd0 = 0
    numberedCmd1 = (1, "Numbered cmd 1")

  NumberedCmdAlias = NumberedCmd

  TestConfNumbered = object
    case cmd {.
      command
      defaultValue: NumberedCmd.numberedCmd0 }: NumberedCmdAlias
    of NumberedCmd.numberedCmd0:
      numberedArg0 {.
        defaultValue: "numberedArg0 default"
        desc: "numberedArg0 desc"
        name: "numbered-arg0" }: string
    of NumberedCmd.numberedCmd1:
      numberedArg1 {.
        defaultValue: "numberedArg1 default"
        desc: "numberedArg1 desc"
        name: "numbered-arg1" }: string

suite "test nested cmd":
  test "no command":
    let conf = TestConf.load(cmdLine = @[
       "--outer-arg=foobar"
    ])
    check:
      conf.cmd == OuterCmd.noCommand
      conf.outerArg == "foobar"

  test "subcommand outerCmd1 innerCmd1":
    let conf = TestConf.load(cmdLine = @[
      "outerCmd1",
      "innerCmd1",
      "--inner-arg1=foobar"
    ])
    check:
      conf.cmd == OuterCmd.outerCmd1
      conf.innerCmd == InnerCmd.innerCmd1
      conf.innerArg1 == "foobar"

  test "subcommand outerCmd1 innerCmd2":
    let conf = TestConf.load(cmdLine = @[
      "outerCmd1",
      "innerCmd2",
      "--inner-arg2=foobar"
    ])
    check:
      conf.cmd == OuterCmd.outerCmd1
      conf.innerCmd == InnerCmd.innerCmd2
      conf.innerArg2 == "foobar"

suite "test nested cmd default args":
  test "no command default":
    let conf = TestConf.load(cmdLine = newSeq[string]())
    check:
      conf.cmd == OuterCmd.noCommand
      conf.outerArg == "outerArg default"

  test "subcommand outerCmd1 innerCmd1":
    let conf = TestConf.load(cmdLine = @[
      "outerCmd1",
      "innerCmd1"
    ])
    check:
      conf.cmd == OuterCmd.outerCmd1
      conf.innerCmd == InnerCmd.innerCmd1
      conf.outerArg1 == "outerArg1 default"
      conf.innerArg1 == "innerArg1 default"

  test "subcommand outerCmd1 innerCmd2":
    let conf = TestConf.load(cmdLine = @[
      "outerCmd1",
      "innerCmd2"
    ])
    check:
      conf.cmd == OuterCmd.outerCmd1
      conf.innerCmd == InnerCmd.innerCmd2
      conf.outerArg1 == "outerArg1 default"
      conf.innerArg2 == "innerArg2 default"

suite "test nested cmd non-first default":
  test "no command":
    let conf = TestConfNonFirstDefault.load(cmdLine = @[
      "--outer-arg1=foobar"
    ])
    check:
      conf.cmd == OuterCmd.outerCmd1
      conf.outerArg1 == "foobar"

  test "no command default":
    let conf = TestConfNonFirstDefault.load(cmdLine = newSeq[string]())
    check:
      conf.cmd == OuterCmd.outerCmd1
      conf.outerArg1 == "outerArg1 default"

suite "test nested cmd enum values":
  test "no command default":
    let conf = TestConfNumbered.load(cmdLine = newSeq[string]())
    check:
      conf.cmd == NumberedCmd.numberedCmd0
      conf.numberedArg0 == "numberedArg0 default"

  test "subcommand numberedCmd1":
    let conf = TestConfNumbered.load(cmdLine = @[
      "numberedCmd1",
      "--numbered-arg1=foobar"
    ])
    check:
      conf.cmd == NumberedCmd.numberedCmd1
      conf.numberedArg1 == "foobar"

suite "test nested cmd toml":
  test "no command default":
    let conf = TestConf.load(secondarySources = loadFile(TestConf, "nested_cmd.toml"))
    check:
      conf.cmd == OuterCmd.noCommand
      conf.outerArg == "toml outer-arg"

  test "subcommand outerCmd1 innerCmd1":
    let conf = TestConf.load(
      secondarySources = loadFile(TestConf, "nested_cmd.toml"),
      cmdLine = @[
        "outerCmd1",
        "innerCmd1"
      ]
    )
    check:
      conf.cmd == OuterCmd.outerCmd1
      conf.innerCmd == InnerCmd.innerCmd1
      conf.outerArg1 == "toml outer-arg1"
      conf.innerArg1 == "toml inner-arg1"

  test "subcommand outerCmd1 innerCmd2":
    let conf = TestConf.load(
      secondarySources = loadFile(TestConf, "nested_cmd.toml"),
      cmdLine = @[
        "outerCmd1",
        "innerCmd2"
      ]
    )
    check:
      conf.cmd == OuterCmd.outerCmd1
      conf.innerCmd == InnerCmd.innerCmd2
      conf.outerArg1 == "toml outer-arg1"
      conf.innerArg2 == "toml inner-arg2"

  test "subcommand outerCmd1 innerCmd2":
    let tomlCont = readFile(configFilePath / "nested_cmd.toml")
    let conf = TestConf.load(
      secondarySources = loadContent(TestConf, tomlCont),
      cmdLine = @[
        "outerCmd1",
        "innerCmd2"
      ]
    )
    check:
      conf.cmd == OuterCmd.outerCmd1
      conf.innerCmd == InnerCmd.innerCmd2
      conf.outerArg1 == "toml outer-arg1"
      conf.innerArg2 == "toml inner-arg2"
