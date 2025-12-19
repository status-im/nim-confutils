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

var registry {.threadvar.}: seq[string]

proc obsoleteCmdOpt(T: type OverloadConf, opt, msg: string) =
  registry.add opt
  if msg.len > 0:
    registry.add " "
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
