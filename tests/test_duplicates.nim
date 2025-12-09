import
  unittest2,
  ../confutils,
  ../confutils/defs

# duplicate name and abbr from different subcommand
# at the same level is allowed

# but hierarchical duplicate is not allowed

type
  Command = enum
    noCommand
    subCommand

  BranchCmd = enum
    branchA
    branchB

  TestConf* = object
    dataDir* {.abbr: "d" }: OutDir

    case cmd* {.
      command
      defaultValue: noCommand }: Command

    of noCommand:
      importDir* {.
        abbr: "i"
        name: "import"
      }: OutDir

      outputDir* {.
        abbr: "o"
        name: "output"
      }: OutDir

    of subCommand:
      importKey* {.
        abbr: "i"
        name: "import"
      }: OutDir

      case subcmd* {.
        command
        defaultValue: branchA }: BranchCmd

      of branchA:
        outputFolder* {.
          abbr: "o"
          name: "output"
        }: OutDir

      of branchB:
        importFolder* {.
          abbr: "f"
          name: "import-folder"
        }: OutDir

suite "test duplicates":
  test "no command":
    let conf = TestConf.load(cmdLine = @[
      "--dataDir=/data",
      "--import=/in",
      "--output=/out"
    ])
    check:
      conf.cmd == Command.noCommand
      conf.dataDir.string == "/data"
      conf.importDir.string == "/in"
      conf.outputDir.string == "/out"

  test "sub-command branchA":
    let conf = TestConf.load(cmdLine = @[
      "--dataDir=/data",
      "subCommand",
      "--import=/in",
      "--output=/out"
    ])
    check:
      conf.cmd == Command.subCommand
      conf.dataDir.string == "/data"
      conf.importKey.string == "/in"
      conf.subcmd == BranchCmd.branchA
      conf.outputFolder.string == "/out"

  test "sub-command branchB":
    let conf = TestConf.load(cmdLine = @[
      "--dataDir=/data",
      "subCommand",
      "--import=/in",
      "branchB",
      "--import-folder=/out"
    ])
    check:
      conf.cmd == Command.subCommand
      conf.dataDir.string == "/data"
      conf.importKey.string == "/in"
      conf.subcmd == BranchCmd.branchB
      conf.importFolder.string == "/out"
