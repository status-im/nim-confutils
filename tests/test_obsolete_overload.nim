import
  unittest2,
  ../confutils

type
  TestConf = object
    opt1 {.
      obsolete
      defaultValue: "opt1 default"
      name: "opt1"}: string

var registry {.threadvar.}: seq[string]

proc obsoleteCmdOpt(T: type, opt, msg: string) =
  registry.add opt

suite "test obsolete overload for type":
  test "obsolete option default":
    registry.setLen 0
    let conf = TestConf.load()
    check conf.opt1 == "opt1 default"
    check registry.len == 0

  test "obsolete option set":
    registry.setLen 0
    let conf = TestConf.load(cmdLine = @[
      "--opt1=foo"
    ])
    check conf.opt1 == "foo"
    check registry == @["opt1"]
