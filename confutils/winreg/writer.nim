import
  typetraits, options, strutils, tables,
  serialization,
  ./utils

type
  WinregWriter* = object
    hKey: HKEY
    path: string
    key: string

proc init*(T: type WinregWriter,
           hKey: HKEY, path: string): T =
  result.hKey = hKey
  result.path = path

proc writeValue*(w: var WinregWriter, value: auto) =
  mixin enumInstanceSerializedFields, writeValue, writeFieldIMPL

  when value is (SomePrimitives or range):
    setValue(w.hKey, w.path, w.key, value)
  elif value is (seq or array or openArray):
    when uTypeIsPrimitives(type value):
      setValue(w.hKey, w.path, w.key, value)
    elif uTypeIsRecord(type value):
      # TODO: reduce allocation
      discard
    else:
      const typeName = typetraits.name(value.type)
      {.fatal: "Failed to convert to Winreg array an unsupported type: " & typeName.}
  elif value is (object or tuple):
    discard
  else:
    const typeName = typetraits.name(value.type)
    {.fatal: "Failed to convert to Winreg an unsupported type: " & typeName.}
