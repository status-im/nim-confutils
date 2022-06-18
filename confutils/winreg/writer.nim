import
  typetraits, options, tables,
  serialization,
  ./utils, ./types

type
  WinregWriter* = object
    hKey: HKEY
    path: string
    key: seq[string]

proc init*(T: type WinregWriter,
           hKey: HKEY, path: string): T =
  result.hKey = hKey
  result.path = path

proc writeValue*(w: var WinregWriter, value: auto) =
  mixin enumInstanceSerializedFields, writeValue, writeFieldIMPL
  # TODO: reduce allocation

  when value is (SomePrimitives or range or string):
    let path = constructPath(w.path, w.key)
    discard setValue(w.hKey, path, w.key[^1], value)
  elif value is Option:
    if value.isSome:
      w.writeValue value.get
  elif value is (seq or array or openArray):
    when uTypeIsPrimitives(type value):
      let path = constructPath(w.path, w.key)
      discard setValue(w.hKey, path, w.key[^1], value)
    elif uTypeIsRecord(type value):
      let key = w.key[^1]
      for i in 0..<value.len:
        w.key[^1] = key & $i
        w.writeValue(value[i])
    else:
      const typeName = typetraits.name(value.type)
      {.fatal: "Failed to convert to Winreg array an unsupported type: " & typeName.}
  elif value is (object or tuple):
    type RecordType = type value
    w.key.add ""
    value.enumInstanceSerializedFields(fieldName, field):
      w.key[^1] = fieldName
      w.writeFieldIMPL(FieldTag[RecordType, fieldName], field, value)
    discard w.key.pop()
  else:
    const typeName = typetraits.name(value.type)
    {.fatal: "Failed to convert to Winreg an unsupported type: " & typeName.}
