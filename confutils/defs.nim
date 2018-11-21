type
  DirPath* = distinct string
  ConfigurationError* = object of CatchableError

template desc*(v: string) {.pragma.}
template shorthand*(v: string) {.pragma.}
template defaultValue*(v: untyped) {.pragma.}

