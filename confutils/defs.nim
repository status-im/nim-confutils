type
  ConfigurationError* = object of CatchableError

  TypedInputFile*[ContentType = Unspecified,
                  Format = Unspecified,
                  defaultExt: static string] = distinct string

  # InputFile* = TypedInputFile[Unspecified, Unspecified, ""]
  # TODO temporary work-around, see parseCmdArg
  InputFile* = distinct string

  InputDir* = distinct string
  OutPath* = distinct string
  OutDir* = distinct string
  OutFile* = distinct string

  Unspecified* = object
  Txt* = object

template `/`*(dir: InputDir|OutDir, path: string): auto =
  string(dir) / path

template desc*(v: string) {.pragma.}
template name*(v: string) {.pragma.}
template abbr*(v: string) {.pragma.}
template defaultValue*(v: untyped) {.pragma.}
template required* {.pragma.}
template command* {.pragma.}
template argument* {.pragma.}

template implicitlySelectable* {.pragma.}
  ## This can be applied to a case object discriminator
  ## to allow the value of the discriminator to be determined
  ## implicitly when the user specifies any of the sub-options
  ## that depend on the disciminator value.

