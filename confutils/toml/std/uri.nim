import
  std/uri,
  toml_serialization, toml_serialization/lexer

export
  uri, toml_serialization

proc readValue*(r: var TomlReader, val: var Uri)
               {.raises: [SerializationError, IOError, Defect].} =
  val =  try: parseUri(r.readValue(string))
         except ValueError as err:
           r.lex.raiseUnexpectedValue("URI")

