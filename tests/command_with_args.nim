import
  confutils, options

type
  Cmd = enum
    fizz = "command A"
    buzz = "command B"

  Conf = object
    case cmd {.command.}: Cmd
    of fizz:
      option {.desc: "some option".}: Option[string]
      anotherOption {.desc: "another option"
                      defaultValue: "some value".}: string
      thirdOption {.desc: "third option"
                    defaultValue: "another value"
                    defaultValueDesc: "some description".}: string
      arg1 {.
        argument
        desc: "argument 1" .}: string
      argument2 {.
        argument
        desc: "argument 2" .}: int
    of buzz:
      discard

echo load(Conf)
