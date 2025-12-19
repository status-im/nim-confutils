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
  test "obsolete option set":
    registry.setLen 0
    let conf = OverloadConf.load(cmdLine = @[
      "--opt1=foo"
    ])
    check conf.opt1 == "foo"
    check registry == @["opt1"]
