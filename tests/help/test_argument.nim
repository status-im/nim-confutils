import ../../confutils

type
  Lvl1Cmd* = enum
    noCommand
    argAfterOpt
    argBeforeOpt
    argAroundOpt

  TestConf* = object
    case cmd* {.
      command
      defaultValue: Lvl1Cmd.noCommand }: Lvl1Cmd
    of Lvl1Cmd.noCommand:
      discard
    of Lvl1Cmd.argAfterOpt:
      opt1* {.
        defaultValue: "opt1 default"
        desc: "opt1 desc"
        name: "arg-after-opt-opt1" }: string
      arg1* {.
        argument
        desc: "arg1 desc"
        name: "arg-after-opt-arg1" }: string
    of Lvl1Cmd.argBeforeOpt:
      arg2* {.
        argument
        desc: "arg2 desc"
        name: "arg-before-opt-arg2" }: string
      opt2* {.
        defaultValue: "opt2 default"
        desc: "opt2 desc"
        name: "arg-before-opt-opt2" }: string
    of Lvl1Cmd.argAroundOpt:
      arg4* {.
        argument
        desc: "arg4 desc"
        name: "arg-around-opt-arg4" }: string
      opt3* {.
        defaultValue: "opt3 default"
        desc: "opt3 desc"
        name: "arg-around-opt-opt3" }: string
      arg5* {.
        argument
        desc: "arg5 desc"
        name: "arg-around-opt-arg5" }: string

when isMainModule:
  let c = TestConf.load(termWidth = int.high)
