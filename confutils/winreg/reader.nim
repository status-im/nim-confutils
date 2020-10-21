import
  tables, strutils, typetraits, options,
  serialization/[object_serialization, errors],
  ./utils

type
  WinregReader* = object
    hKey: HKEY
    path: string

  WinregReaderError* = object of WinregError

  GenericWinregReaderError* = object of WinregReaderError
    deserializedField*: string
    innerException*: ref CatchableError

proc handleReadException*(r: WinregReader,
                          Record: type,
                          fieldName: string,
                          field: auto,
                          err: ref CatchableError) =
  var ex = new GenericWinregReaderError
  ex.deserializedField = fieldName
  ex.innerException = err
  raise ex

proc init*(T: type WinregReader,
           hKey: HKEY, path: string): T =
  result.hKey = hKey
  result.path = path

proc readValue*[T](r: var WinregReader, value: var T)
                  {.raises: [SerializationError, IOError, Defect].} =
  mixin readValue

  when T is (SomePrimitives or range):
    getValue(w.hKey, w.path, w.key, value)
  elif T is (seq or array):
    when uTypeIsPrimitives(T):
      getValue(w.hKey, w.path, w.key, value)
    elif uTypeIsRecord(T):
      # TODO: reduce allocation
      discard
    else:
      const typeName = typetraits.name(T)
      {.fatal: "Failed to convert from Winreg array an unsupported type: " & typeName.}
  elif T is (object or tuple):
    discard
  else:
    const typeName = typetraits.name(T)
    {.fatal: "Failed to convert from Winreg an unsupported type: " & typeName.}
