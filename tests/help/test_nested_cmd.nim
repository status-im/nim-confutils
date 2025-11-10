import ../../confutils

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

let c = TestConf.load()
