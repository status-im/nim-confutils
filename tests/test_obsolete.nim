import
  unittest2,
  ../confutils

type
  TestConf = object
    opt1 {.
      obsolete
      defaultValue: "opt1 default"
      name: "opt1"}: string

#let conf = TestConf.load()
#echo conf.opt1

suite "test obsolete option":
  test "obsolete option default":
    let conf = TestConf.load()
    check conf.opt1 == "opt1 default"

  test "obsolete option set":
    let conf = TestConf.load(cmdLine = @[
      "--opt1=foo"
    ])
    check conf.opt1 == "foo"

type
  OverloadConf = object
    opt1 {.
      obsolete
      defaultValue: "opt1 default"
      name: "opt1"}: string
    opt2 {.
      obsolete
      defaultValue: "opt2 default"
      name: "opt2"}: string
    opt3 {.
      obsolete: "opt3 obsolete msg"
      defaultValue: "opt3 default"
      name: "opt3"}: string
    opt4 {.
      defaultValue: "opt4 default"
      name: "opt4"}: string

var registry {.threadvar.}: seq[string]

proc obsoleteCmdOpt(T: type OverloadConf, opt, msg: string) =
  registry.add opt
  if msg.len > 0:
    registry.add msg

suite "test obsolete option overload":
  test "the overload is called if opt is set":
    registry.setLen 0
    let conf = OverloadConf.load(cmdLine = @[
      "--opt1=foo"
    ])
    check conf.opt1 == "foo"
    check registry == @["opt1"]

  test "the overload is not called if opt not set":
    registry.setLen 0
    let conf = OverloadConf.load()
    check conf.opt1 == "opt1 default"
    check registry.len == 0

  test "the overload is called for all obsolete opts set":
    registry.setLen 0
    let conf = OverloadConf.load(cmdLine = @[
      "--opt1=foo",
      "--opt2=bar"
    ])
    check conf.opt1 == "foo"
    check conf.opt2 == "bar"
    check registry == @["opt1", "opt2"]

  test "the overload is called with obsolete msg":
    registry.setLen 0
    let conf = OverloadConf.load(cmdLine = @[
      "--opt3=foo"
    ])
    check conf.opt3 == "foo"
    check registry == @["opt3", "opt3 obsolete msg"]

  test "the logger setup is called":
    proc loggerSetup(c: OverloadConf) =
      doAssert c.opt1 == "opt1 default"
      registry.add "logger"

    registry.setLen 0
    let conf = OverloadConf.load(loggerSetup = loggerSetup)
    check conf.opt1 == "opt1 default"
    check registry == @["logger"]

  test "the logger setup is called before the overload":
    proc loggerSetup(c: OverloadConf) =
      doAssert c.opt1 == "foo"
      registry.add "logger"

    registry.setLen 0
    let conf = OverloadConf.load(
      cmdLine = @[
        "--opt1=foo"
      ],
      loggerSetup = loggerSetup
    )
    check conf.opt1 == "foo"
    check registry == @["logger", "opt1"]
