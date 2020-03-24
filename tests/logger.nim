import
  ../confutils

type
  Command = enum
    pubsub = "A pub sub command"

  Conf = object
    logDir: string
    case cmd {.command.}: Command
    of pubsub:
      foo: string

let c = load Conf
echo c.cmd

