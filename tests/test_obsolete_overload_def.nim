
# this is in its own module to test there
# is no ambiguous (import) call error for obsoleteCmdOpt

var registry* {.threadvar.}: seq[string]

proc obsoleteCmdOpt*(T: type[object], opt, msg: string) =
  registry.add opt
