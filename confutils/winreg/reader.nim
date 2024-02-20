# confutils
# Copyright (c) 2018-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  tables, typetraits, options,
  serialization/[object_serialization, errors],
  ./utils, ./types

type
  WinregReader* = object
    hKey: HKEY
    path: string
    key: seq[string]

  WinregReaderError* = object of WinregError

  GenericWinregReaderError* = object of WinregReaderError
    deserializedField*: string
    innerException*: ref CatchableError

{.push gcsafe, raises: [].}

proc handleReadException*(r: WinregReader,
                          Record: type,
                          fieldName: string,
                          field: auto,
                          err: ref CatchableError) {.gcsafe, raises: [WinregError].} =
  var ex = new GenericWinregReaderError
  ex.deserializedField = fieldName
  ex.innerException = err
  raise ex

proc init*(T: type WinregReader,
           hKey: HKEY, path: string): T =
  result.hKey = hKey
  result.path = path

proc readValue*[T](r: var WinregReader, value: var T)
      {.gcsafe, raises: [SerializationError, IOError].} =
  mixin readValue
  # TODO: reduce allocation

  when T is (SomePrimitives or range or string):
    let path = constructPath(r.path, r.key)
    discard getValue(r.hKey, path, r.key[^1], value)

  elif T is Option:
    template getUnderlyingType[T](_: Option[T]): untyped = T
    type UT = getUnderlyingType(value)
    let path = constructPath(r.path, r.key)
    if pathExists(r.hKey, path, r.key[^1]):
      value = some(r.readValue(UT))

  elif T is (seq or array):
    when uTypeIsPrimitives(T):
      let path = constructPath(r.path, r.key)
      discard getValue(r.hKey, path, r.key[^1], value)

    else:
      let key = r.key[^1]
      for i in 0..<value.len:
        r.key[^1] = key & $i
        r.readValue(value[i])

  elif T is (object or tuple):
    type T = type(value)
    when T.totalSerializedFields > 0:
      let fields = T.fieldReadersTable(WinregReader)
      var expectedFieldPos = 0
      r.key.add ""
      value.enumInstanceSerializedFields(fieldName, field):
        when T is tuple:
          r.key[^1] = $expectedFieldPos
          var reader = fields[][expectedFieldPos].reader
          expectedFieldPos += 1

        else:
          r.key[^1] = fieldName
          var reader = findFieldReader(fields[], fieldName, expectedFieldPos)

        if reader != nil:
          reader(value, r)
      discard r.key.pop()

  else:
    const typeName = typetraits.name(T)
    {.fatal: "Failed to convert from Winreg an unsupported type: " & typeName.}

{.pop.}
