import ../../confutils

type
  TestConf = object
    arg1 {.
      argument
      desc: "arg1 desc"
      longDesc:
        "arg1 longdesc line one\n" &
        "longdesc line two\n" &
        "longdesc line three"
      name: "arg1" }: string
    opt1 {.
      defaultValue: "opt1 default"
      desc: "opt1 desc"
      name: "opt1"
      abbr: "o" }: string
    opt2 {.
      defaultValue: "opt2 default"
      desc: "opt2 desc"
      name: "opt2"
      abbr: "p" }: string
    opt3 {.
      defaultValue: "opt3 default"
      desc: "opt3 desc"
      name: "opt3" }: string

let c = TestConf.load(termWidth = int.high)
