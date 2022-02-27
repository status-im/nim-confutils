import
  stew/shims/net,
  toml_serialization, toml_serialization/lexer

export
  net, toml_serialization

proc readValue*(r: var TomlReader, val: var ValidIpAddress)
               {.raises: [SerializationError, IOError, Defect].} =
  val =  try: ValidIpAddress.init(r.readValue(string))
         except ValueError as err:
           r.lex.raiseUnexpectedValue("IP address")

proc readValue*(r: var TomlReader, val: var Port)
               {.raises: [SerializationError, IOError, Defect].} =
  let port = try: r.readValue(uint16)
             except ValueError:
               r.lex.raiseUnexpectedValue("Port")

  val = Port port
