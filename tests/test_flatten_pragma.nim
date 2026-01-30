# confutils
# Copyright (c) 2018-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import std/os, unittest2, toml_serialization, ../confutils

const flattenFilePath = "tests" / "config_files"

template loadFile(T, file): untyped =
  proc (
    config: T, sources: ref SecondarySources
  ) {.raises: [ConfigurationError].} =
    sources.addConfigFile(Toml, InputFile(flattenFilePath / file))

type
  TopOptsConf = object
    opt1 {.
      desc: "top opt 1"
      defaultValue: "top_opt_1"
      name: "top-opt1" .}: string

    opt2 {.
      desc: "top opt 2"
      defaultValue: false
      name: "top-opt2" .}: bool

suite "test top opts":
  test "top opts":
    let conf = TopOptsConf.load(cmdLine = @[
      "--top-opt1=foobar"
    ])
    check:
      conf.opt1 == "foobar"
      conf.opt2 == false

  test "top opts file":
    let conf = TopOptsConf.load(secondarySources = loadFile(TopOptsConf, "flatten.toml"))
    check:
      conf.opt1 == "foo"
      conf.opt2 == true

suite "test flatten top opts":
  type
    TestConfFlat = object
      topOpts {.flatten.}: TopOptsConf

  test "top opts flat":
    let conf = TestConfFlat.load(cmdLine = @[
      "--top-opt1=foobar",
      "--top-opt2=true"
    ])
    check:
      conf.topOpts.opt1 == "foobar"
      conf.topOpts.opt2 == true

  test "top opts flat defaults":
    let conf = TestConfFlat.load(cmdLine = newSeq[string]())
    check:
      conf.topOpts.opt1 == "top_opt_1"
      conf.topOpts.opt2 == false

  test "top opts flat file":
    let conf = TestConfFlat.load(secondarySources = loadFile(TestConfFlat, "flatten.toml"))
    check:
      conf.topOpts.opt1 == "foo"
      conf.topOpts.opt2 == true

suite "test flatten top opts with extra opt":
  type
    TestConfFlat = object
      topOpts {.flatten.}: TopOptsConf
      outerArg1 {.
        defaultValue: "outerArg1 default"
        desc: "outerArg1 desc"
        name: "outer-arg1" }: string

  test "top opts arg":
    let conf = TestConfFlat.load(cmdLine = @[
      "--top-opt1=foobar",
      "--top-opt2=true",
      "--outer-arg1=bazquz"
    ])
    check:
      conf.topOpts.opt1 == "foobar"
      conf.topOpts.opt2 == true
      conf.outerArg1 == "bazquz"

  test "top opts arg defaults":
    let conf = TestConfFlat.load(cmdLine = newSeq[string]())
    check:
      conf.topOpts.opt1 == "top_opt_1"
      conf.topOpts.opt2 == false
      conf.outerArg1 == "outerArg1 default"

  test "top opts arg file":
    let conf = TestConfFlat.load(secondarySources = loadFile(TestConfFlat, "flatten.toml"))
    check:
      conf.topOpts.opt1 == "foo"
      conf.topOpts.opt2 == true
      conf.outerArg1 == "bar"

suite "test nested flatten top opts":
  type
    TopOptsConfFlat = object
      opts {.flatten.}: TopOptsConf
      opt3 {.
        desc: "top opt 3"
        defaultValue: "top_opt_3"
        name: "top-opt3" .}: string

    TestConfFlat = object
      topOpts {.flatten.}: TopOptsConfFlat
      outerArg1 {.
        defaultValue: "outerArg1 default"
        desc: "outerArg1 desc"
        name: "outer-arg1" }: string

  test "top opts nested":
    let conf = TestConfFlat.load(cmdLine = @[
      "--top-opt1=foo",
      "--top-opt2=true",
      "--top-opt3=bar",
      "--outer-arg1=baz"
    ])
    check:
      conf.topOpts.opts.opt1 == "foo"
      conf.topOpts.opts.opt2 == true
      conf.topOpts.opt3 == "bar"
      conf.outerArg1 == "baz"

  test "top opts nested defaults":
    let conf = TestConfFlat.load(cmdLine = newSeq[string]())
    check:
      conf.topOpts.opts.opt1 == "top_opt_1"
      conf.topOpts.opts.opt2 == false
      conf.topOpts.opt3 == "top_opt_3"
      conf.outerArg1 == "outerArg1 default"

  test "top opts nested file":
    let conf = TestConfFlat.load(
      secondarySources = loadFile(TestConfFlat, "flatten.toml")
    )
    check:
      conf.topOpts.opts.opt1 == "foo"
      conf.topOpts.opts.opt2 == true
      conf.topOpts.opt3 == "baz"
      conf.outerArg1 == "bar"

suite "test flatten option redefinition":
  test "redefine name top-opt1":
    type
      TopOptsConfConflict = object
        opt1 {.
          desc: "top opt 1"
          defaultValue: "top_opt_1"
          name: "top-opt1" .}: string

      TestConfConflict = object
        topOpts {.flatten.}: TopOptsConfConflict
        outerArg1 {.
          desc: "top opt 1"
          defaultValue: "top_opt_1"
          name: "top-opt1" .}: string

    check not compiles(TestConfConflict.load())

  test "redefine field opt1":
    type
      TopOptsConfConflict = object
        opt1 {.
          desc: "top opt 1"
          defaultValue: "top_opt_1" .}: string

      TestConfConflict = object
        topOpts {.flatten.}: TopOptsConfConflict
        opt1 {.
          desc: "top opt 1"
          defaultValue: "top_opt_1" .}: string

    check not compiles(TestConfConflict.load())

  test "redefine field name opt1":
    type
      TopOptsConfConflict = object
        topOpt1 {.
          desc: "top opt 1"
          defaultValue: "top_opt_1"
          name: "opt1" .}: string

      TestConfConflict = object
        topOpts {.flatten.}: TopOptsConfConflict
        opt1 {.
          desc: "top opt 1"
          defaultValue: "top_opt_1" .}: string

    check not compiles(TestConfConflict.load())

type
  OuterCmd = enum
    noCommand
    outerCmd1

suite "test flatten opts in subcommand":
  type
    TestConfCmd = object
      case cmd {.
        command
        defaultValue: OuterCmd.noCommand }: OuterCmd
      of OuterCmd.noCommand:
        opts {.flatten.}: TopOptsConf
        outerArg {.
          defaultValue: "outerArg default"
          desc: "outerArg desc"
          name: "outer-arg" }: string
      of OuterCmd.outerCmd1:
        opts1 {.flatten.}: TopOptsConf
        outerArg1 {.
          defaultValue: "outerArg1 default"
          desc: "outerArg1 desc"
          name: "outer-arg1" }: string

  test "top opts cmd":
    let conf = TestConfCmd.load(cmdLine = @[
      "--top-opt1=foobar",
      "--top-opt2=true",
      "--outer-arg=bazquz"
    ])
    check:
      conf.cmd == OuterCmd.noCommand
      conf.opts.opt1 == "foobar"
      conf.opts.opt2 == true
      conf.outerArg == "bazquz"

  test "top opts cmd 1":
    let conf = TestConfCmd.load(cmdLine = @[
      "outerCmd1",
      "--top-opt1=foobar",
      "--top-opt2=true",
      "--outer-arg1=bazquz"
    ])
    check:
      conf.cmd == OuterCmd.outerCmd1
      conf.opts1.opt1 == "foobar"
      conf.opts1.opt2 == true
      conf.outerArg1 == "bazquz"

  test "top opts cmd 1 defaults":
    let conf = TestConfCmd.load(cmdLine = @[
      "outerCmd1"
    ])
    check:
      conf.cmd == OuterCmd.outerCmd1
      conf.opts1.opt1 == "top_opt_1"
      conf.opts1.opt2 == false
      conf.outerArg1 == "outerArg1 default"

  test "top opts cmd file":
    let conf = TestConfCmd.load(
      secondarySources = loadFile(TestConfCmd, "flatten_cmd.toml")
    )
    check:
      conf.cmd == OuterCmd.noCommand
      conf.opts.opt1 == "foo"
      conf.opts.opt2 == true
      conf.outerArg == "bar"

  test "top opts cmd 1 file":
    let conf = TestConfCmd.load(
      cmdLine = @["outerCmd1"],
      secondarySources = loadFile(TestConfCmd, "flatten_cmd.toml")
    )
    check:
      conf.cmd == OuterCmd.outerCmd1
      conf.opts1.opt1 == "baz"
      conf.opts1.opt2 == true
      conf.outerArg1 == "quz"

type
  Lvl1Cmd = enum
    lvlCmd1

suite "test one lvl flatten subcommand":
  type
    TopSubCmdConf = object
      case cmd {.command.}: Lvl1Cmd
      of Lvl1Cmd.lvlCmd1:
        lvl1Arg1 {.
          defaultValue: "lvl1Arg1 default"
          desc: "lvl1Arg1 desc"
          name: "lvl1-arg1" }: string

    TestConfSubCmdFlat = object
      topCmd {.flatten.}: TopSubCmdConf

  test "top cmd":
    let conf = TopSubCmdConf.load(cmdLine = @[
      "lvlCmd1",
      "--lvl1-arg1=foo"
    ])
    check:
      conf.cmd == Lvl1Cmd.lvlCmd1
      conf.lvl1Arg1 == "foo"

  test "top cmd flatten":
    let conf = TestConfSubCmdFlat.load(cmdLine = @[
      "lvlCmd1",
      "--lvl1-arg1=foo"
    ])
    check:
      conf.topCmd.cmd == Lvl1Cmd.lvlCmd1
      conf.topCmd.lvl1Arg1 == "foo"

  test "redefine cmd flatten opt":
    type
      TestConfSubCmdFlatConflict = object
        lvl1Arg1 {.
          defaultValue: "lvl1Arg1 default"
          desc: "lvl1Arg1 desc"
          name: "lvl1-arg1" }: string
        topCmd {.flatten.}: TopSubCmdConf

    check not compiles(TestConfSubCmdFlatConflict.load())

type
  TopCmd1 = enum
    topLvlCmd1
    topLvlCmd2

suite "test two lvls flatten subcommands":
  type
    TopSubCmdConf = object
      case cmd {.command.}: Lvl1Cmd
      of Lvl1Cmd.lvlCmd1:
        lvl1Arg1 {.
          defaultValue: "lvl1Arg1 default"
          desc: "lvl1Arg1 desc"
          name: "lvl1-arg1" }: string

    TestConfSubCmdFlat = object
      case cmd {.command.}: TopCmd1
      of TopCmd1.topLvlCmd1:
        topCmd1 {.flatten.}: TopSubCmdConf
      of TopCmd1.topLvlCmd2:
        topCmd2 {.flatten.}: TopSubCmdConf

  test "topLvlCmd1 lvlCmd1":
    let conf = TestConfSubCmdFlat.load(cmdLine = @[
      "topLvlCmd1",
      "lvlCmd1",
      "--lvl1-arg1=foo"
    ])
    check:
      conf.cmd == TopCmd1.topLvlCmd1
      conf.topCmd1.cmd == Lvl1Cmd.lvlCmd1
      conf.topCmd1.lvl1Arg1 == "foo"

  test "topLvlCmd2 lvlCmd1":
    let conf = TestConfSubCmdFlat.load(cmdLine = @[
      "topLvlCmd2",
      "lvlCmd1",
      "--lvl1-arg1=foo"
    ])
    check:
      conf.cmd == TopCmd1.topLvlCmd2
      conf.topCmd2.cmd == Lvl1Cmd.lvlCmd1
      conf.topCmd2.lvl1Arg1 == "foo"

type
  Lvl2Cmd = enum
    lvlCmd2

suite "test nested flatten subcommands":
  type
    TopSubCmdConf2 = object
      case cmd {.command.}: Lvl2Cmd
      of Lvl2Cmd.lvlCmd2:
        lvl2Arg1 {.
          defaultValue: "lvl2Arg1 default"
          desc: "lvl2Arg1 desc"
          name: "lvl2-arg1" }: string

    TopSubCmdConf = object
      case cmd {.command.}: Lvl1Cmd
      of Lvl1Cmd.lvlCmd1:
        lvl1Arg1 {.
          defaultValue: "lvl1Arg1 default"
          desc: "lvl1Arg1 desc"
          name: "lvl1-arg1" }: string

        topCmd2 {.flatten.}: TopSubCmdConf2

    TestConfSubCmdFlat = object
      case cmd {.command.}: TopCmd1
      of TopCmd1.topLvlCmd1:
        topCmd1 {.flatten.}: TopSubCmdConf
      of TopCmd1.topLvlCmd2:
        discard

  test "topLvlCmd1 defaults":
    let conf = TestConfSubCmdFlat.load(cmdLine = @[
      "topLvlCmd1",
      "lvlCmd1",
      "lvlCmd2"
    ])
    check:
      conf.cmd == TopCmd1.topLvlCmd1
      conf.topCmd1.cmd == Lvl1Cmd.lvlCmd1
      conf.topCmd1.topCmd2.cmd == Lvl2Cmd.lvlCmd2
      conf.topCmd1.lvl1Arg1 == "lvl1Arg1 default"
      conf.topCmd1.topCmd2.lvl2Arg1 == "lvl2Arg1 default"

  test "topLvlCmd1 lvlCmd1 lvlCmd2":
    let conf = TestConfSubCmdFlat.load(cmdLine = @[
      "topLvlCmd1",
      "lvlCmd1",
      "lvlCmd2",
      "--lvl1-arg1=foo",
      "--lvl2-arg1=bar"
    ])
    check:
      conf.cmd == TopCmd1.topLvlCmd1
      conf.topCmd1.cmd == Lvl1Cmd.lvlCmd1
      conf.topCmd1.topCmd2.cmd == Lvl2Cmd.lvlCmd2
      conf.topCmd1.lvl1Arg1 == "foo"
      conf.topCmd1.topCmd2.lvl2Arg1 == "bar"

suite "test flatten default value override":
  proc opt1Str: string = "override"

  const opt1Const = opt1Str()
  const opt2Const = true
  const opt3Const = 123

  type
    OptsConf = object
      opt1 {.
        desc: "top opt 1"
        defaultValue: "top_opt_1"
        name: "top-opt1" .}: string

      opt2 {.
        desc: "top opt 2"
        defaultValue: false
        name: "top-opt2" .}: bool

      opt3 {.
        desc: "top opt 3"
        defaultValue: 111
        name: "top-opt3" .}: int

    TestDefaultLitConf = object
      opts {.flatten: (opt1: "override", opt2: true, opt3: 123).}: OptsConf

    TestDefaultConstConf = object
      opts {.flatten: (opt1: opt1Const, opt2: opt2Const, opt3: opt3Const).}: OptsConf

    TestDefaultNestedConf = object
      opts {.flatten: (opt1: "nested").}: TestDefaultLitConf

    TestDefaultFile = object
      opts {.flatten: (opt1: "file").}: TopOptsConf

  test "override with literals":
    let conf = TestDefaultLitConf.load(cmdLine = @[])
    check:
      conf.opts.opt1 == "override"
      conf.opts.opt2 == true
      conf.opts.opt3 == 123

  test "override with literals set opts":
    let conf = TestDefaultLitConf.load(cmdLine = @[
      "--top-opt1=foo",
      "--top-opt2=false"
    ])
    check:
      conf.opts.opt1 == "foo"
      conf.opts.opt2 == false
      conf.opts.opt3 == 123

  test "override with const":
    let conf = TestDefaultConstConf.load(cmdLine = @[])
    check:
      conf.opts.opt1 == opt1Const
      conf.opts.opt2 == opt2Const
      conf.opts.opt3 == opt3Const

  test "override deeply nested":
    let conf = TestDefaultNestedConf.load(cmdLine = @[])
    check:
      conf.opts.opts.opt1 == "nested"
      conf.opts.opts.opt2 == true
      conf.opts.opts.opt3 == 123

  test "defaults from file":
    let conf = TestDefaultFile.load(secondarySources = loadFile(TestDefaultFile, "flatten.toml"))
    check:
      conf.opts.opt1 == "foo"
      conf.opts.opt2 == true
