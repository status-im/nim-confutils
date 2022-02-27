import
  toml_serialization, ../defs as confutilsDefs

export
  toml_serialization, confutilsDefs

template readConfutilsType(T: type) =
  template readValue*(r: var TomlReader, val: var T) =
    val = T r.readValue(string)

readConfutilsType InputFile
readConfutilsType InputDir
readConfutilsType OutPath
readConfutilsType OutDir
readConfutilsType OutFile
