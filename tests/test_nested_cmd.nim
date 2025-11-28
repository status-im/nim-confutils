# confutils
# Copyright (c) 2018-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import std/os, unittest2, toml_serialization, ../confutils

const configFilePath = "tests" / "config_files"

template loadFile(T, file): untyped =
  proc (
    config: T, sources: ref SecondarySources
  ) {.raises: [ConfigurationError].} =
    sources.addConfigFile(Toml, InputFile(configFilePath / file))

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
