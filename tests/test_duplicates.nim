import
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

let c = TestConf.load()
discard c
