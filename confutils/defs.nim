type
  DirPath* = distinct string
  OutFilePath* = distinct string
  ConfigurationError* = object of CatchableError

template desc*(v: string) {.pragma.}
template longform*(v: string) {.pragma.}
template shortform*(v: string) {.pragma.}
template defaultValue*(v: untyped) {.pragma.}
template required* {.pragma.}
template command* {.pragma.}
template argument* {.pragma.}

