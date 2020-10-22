import
  stew/shims/macros,
  serialization, ./reader, ./writer, ./utils

export
  serialization, reader, writer, utils

serializationFormat Envvar,
                    Reader = EnvvarReader,
                    Writer = EnvvarWriter,
                    PreferedOutput = void

template supports*(_: type Envvar, T: type): bool =
  # The Envvar format should support every type
  true

template decode*(_: type Envvar,
                 prefix: string,
                 RecordType: distinct type,
                 params: varargs[untyped]): auto =
  mixin init, ReaderType

  {.noSideEffect.}:
    var reader = unpackArgs(init, [EnvvarReader, prefix, params])
    reader.readValue(RecordType)

template encode*(_: type Envvar,
                 prefix: string,
                 value: auto,
                 params: varargs[untyped]) =
  mixin init, WriterType, writeValue

  {.noSideEffect.}:
    var writer = unpackArgs(init, [EnvvarWriter, prefix, params])
    writeValue writer, value

template loadFile*(_: type Envvar,
                   prefix: string,
                   RecordType: distinct type,
                   params: varargs[untyped]): auto =
  mixin init, ReaderType, readValue

  var reader = unpackArgs(init, [EnvvarReader, prefix, params])
  reader.readValue(RecordType)

template saveFile*(Format: type, prefix: string, value: auto, params: varargs[untyped]) =
  mixin init, WriterType, writeValue

  var writer = unpackArgs(init, [EnvvarWriter, prefix, params])
  writer.writeValue(value)
