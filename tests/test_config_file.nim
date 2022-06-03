# nim-confutils
# Copyright (c) 2020 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT
#   * Apache License, Version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import
  options, unittest, os,
  stew/byteutils, ../confutils,
  ../confutils/[std/net]

import
  toml_serialization, json_serialization,
  ../confutils/winreg/winreg_serialization,
  ../confutils/envvar/envvar_serialization

type
  ValidatorPrivKey = object
    field_a: int
    field_b: string

  CheckPoint = int
  RuntimePreset = int
  GraffitiBytes = array[16, byte]
  WalletName = string

  VCStartUpCmd = enum
    VCNoCommand
    `import`

  ValidatorKeyPath = TypedInputFile[ValidatorPrivKey, Txt, "privkey"]

  TestConf* = object
    configFile* {.
      desc: "Loads the configuration from a config file"
      name: "config-file" }: Option[InputFile]

    logLevel* {.
      defaultValue: "DEBUG"
      desc: "Sets the log level."
      name: "log-level" }: string

    logFile* {.
      desc: "Specifies a path for the written Json log file"
      name: "log-file" }: Option[OutFile]

    dataDir* {.
      defaultValue: config.defaultDataDir()
      desc: "The directory where nimbus will store all blockchain data"
      abbr: "d"
      name: "data-dir" }: OutDir

    nonInteractive* {.
      desc: "Do not display interative prompts. Quit on missing configuration"
      name: "non-interactive" }: bool

    validators* {.
      required
      desc: "Attach a validator by supplying a keystore path"
      abbr: "v"
      name: "validator" }: seq[ValidatorKeyPath]

    validatorsDirFlag* {.
      desc: "A directory containing validator keystores"
      name: "validators-dir" }: Option[InputDir]

    secretsDirFlag* {.
      desc: "A directory containing validator keystore passwords"
      name: "secrets-dir" }: Option[InputDir]

    case cmd* {.
      command
      defaultValue: VCNoCommand }: VCStartUpCmd

    of VCNoCommand:
      graffiti* {.
        desc: "The graffiti value that will appear in proposed blocks. " &
              "You can use a 0x-prefixed hex encoded string to specify raw bytes."
        name: "graffiti" }: Option[GraffitiBytes]

      stopAtEpoch* {.
        defaultValue: 0
        desc: "A positive epoch selects the epoch at which to stop"
        name: "stop-at-epoch" }: uint64

      rpcPort* {.
        defaultValue: defaultEth2RpcPort
        desc: "HTTP port of the server to connect to for RPC - for the validator duties in the pull model"
        name: "rpc-port" }: Port

      rpcAddress* {.
        defaultValue: defaultAdminListenAddress(config)
        desc: "Address of the server to connect to for RPC - for the validator duties in the pull model"
        name: "rpc-address" }: ValidIpAddress

      retryDelay* {.
        defaultValue: 10
        desc: "Delay in seconds between retries after unsuccessful attempts to connect to a beacon node"
        name: "retry-delay" }: int

    of `import`:

      blocksFile* {.
        argument
        desc: "Import RLP encoded block(s) from a file, validate, write to database and quit"
        defaultValue: ""
        name: "blocks-file" }: InputFile

      `type`* {.
        desc: "Test nnkAccQuoted of public sub command entry"
        defaultValue: ""
        name: "import-type" }: string

      `seq` {.
        desc: "Test nnkAccQuoted of private sub command entry"
        defaultValue: ""
        name: "import-seq" }: string

func defaultDataDir(conf: TestConf): string =
  discard

func parseCmdArg*(T: type GraffitiBytes, input: string): T
                 {.raises: [ValueError, Defect].} =
  discard

func completeCmdArg*(T: type GraffitiBytes, input: string): seq[string] =
  @[]

func defaultAdminListenAddress*(conf: TestConf): ValidIpAddress =
  (static ValidIpAddress.init("127.0.0.1"))

const
  defaultEth2TcpPort* = 9000
  defaultEth2RpcPort* = 9090

const
  confPathCurrUser = "tests" / "config_files" / "current_user"
  confPathSystemWide = "tests" / "config_files" / "system_wide"

# User might also need to extend the serializer capability
# for each of the registered formats.
# This is especially true for distinct types and some special types
# not covered by the standard implementation

proc readValue(r: var TomlReader,
  value: var (InputFile | InputDir | OutFile | OutDir | ValidatorKeyPath)) =
  type T = type value
  value = T r.parseAsString()

proc readValue(r: var TomlReader, value: var ValidIpAddress) =
  value = ValidIpAddress.init(r.parseAsString())

proc readValue(r: var TomlReader, value: var Port) =
  value = r.parseInt(int).Port

proc readValue(r: var TomlReader, value: var GraffitiBytes) =
  value = hexToByteArray[value.len](r.parseAsString())

proc readValue(r: var EnvvarReader,
  value: var (InputFile | InputDir | OutFile | OutDir | ValidatorKeyPath)) =
  type T = type value
  value = r.readValue(string).T

proc readValue(r: var EnvvarReader, value: var ValidIpAddress) =
  value = ValidIpAddress.init(r.readValue(string))

proc readValue(r: var EnvvarReader, value: var Port) =
  value = r.readValue(int).Port

proc readValue(r: var EnvvarReader, value: var GraffitiBytes) =
  value = hexToByteArray[value.len](r.readValue(string))

proc readValue(r: var WinregReader,
  value: var (InputFile | InputDir | OutFile | OutDir | ValidatorKeyPath)) =
  type T = type value
  value = r.readValue(string).T

proc readValue(r: var WinregReader, value: var ValidIpAddress) =
  value = ValidIpAddress.init(r.readValue(string))

proc readValue(r: var WinregReader, value: var Port) =
  value = r.readValue(int).Port

proc readValue(r: var WinregReader, value: var GraffitiBytes) =
  value = hexToByteArray[value.len](r.readValue(string))

proc testConfigFile() =
  suite "config file test suite":
    putEnv("prefixdata-dir", "ENV VAR DATADIR")

    test "basic config file":
      let conf = TestConf.load(secondarySources = proc (config: TestConf, sources: auto) =
        sources.addConfigFile(Envvar, InputFile "prefix")

        if config.configFile.isSome:
          sources.addConfigFile(Toml, config.configFile.get)
        else:
          sources.addConfigFile(Toml, InputFile(confPathCurrUser / "testVendor" / "testApp.toml"))
          sources.addConfigFile(Toml, InputFile(confPathSystemWide / "testVendor" / "testApp.toml"))
      )

      # dataDir is in env var
      check conf.dataDir.string == "ENV VAR DATADIR"

      # logFile is in current user config file
      check conf.logFile.isSome()
      check conf.logFile.get().string == "TOML CU LOGFILE"

      # logLevel and rpcPort are in system wide config file
      check conf.logLevel == "TOML SW DEBUG"
      check conf.rpcPort.int == 1235

testConfigFile()
