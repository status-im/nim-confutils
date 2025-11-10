import ../../confutils

type
  OuterCmd = enum
    noCommand
    outerCmd1

  InnerCmd = enum
    innerCmd1 = "Inner cmd 1"
    innerCmd2 = "Inner cmd 2"

  TestConf = object
    topArg1 {.
      defaultValue: "topArg1 default"
      desc: "topArg1 desc"
      name: "top-arg1" }: string

    case cmd {.
      command
      defaultValue: OuterCmd.noCommand }: OuterCmd
    of OuterCmd.noCommand:
      noCommandArg1 {.
        defaultValue: "noCommandArg1 default"
        desc: "noCommandArg1 desc"
        name: "no-command-arg1" }: string
    of OuterCmd.outerCmd1:
      topOuterCmd1Arg1 {.
        defaultValue: "topOuterCmd1Arg1 default"
        desc: "topOuterCmd1Arg1 desc"
        name: "top-outercmd1-arg1" }: string

      case innerCmd {.command.}: InnerCmd
      of InnerCmd.innerCmd1:
        innerCmd1Arg1 {.
          defaultValue: "innerCmd1Arg1 default"
          desc: "innerCmd1Arg1 desc"
          name: "innercmd1-arg1" }: string
      of InnerCmd.innerCmd2:
        innerCmd2Arg1 {.
          defaultValue: "innerCmd2Arg1 default"
          desc: "innerCmd2Arg1 desc"
          name: "innercmd2-arg1" }: string

let c = TestConf.load(termWidth = int.high)




