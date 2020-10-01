import
  strutils,
  stew/byteutils, testutils/fuzzing,
  ../confutils

template fuzzCliParsing*(Conf: type) =
  test:
    block:
      try:
        let cfg = Conf.load(cmdLine = split(fromBytes(string, payload)),
                            printUsage = false,
                            quitOnFailure = false)
      except ConfigurationError as err:
        discard

