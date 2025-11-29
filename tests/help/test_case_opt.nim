# confutils
# Copyright (c) 2018-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import ../../confutils

type
  StartupCommand* = enum
    noCommand
    cmdSlotProcessing
    cmdBlockProcessing

  BlockProcessingCat* = enum
    catBlockHeader
    catAttestations

  ScenarioConf* = object
    preState* {.
      desc: "The name of your pre-state (without .ssz)"
      name: "pre"
      abbr: "p"
      defaultValue: "pre".}: string
    case cmd*{.
      command
      defaultValue: noCommand }: StartupCommand
    of noCommand:
      discard
    of cmdSlotProcessing:
      numSlots* {.
        desc: "The number of slots the pre-state will be advanced by"
        name: "num-slots"
        abbr: "s"
        defaultValue: 1.}: uint64
    of cmdBlockProcessing:
      case blockProcessingCat* {.
        desc: "block transitions"
        #name: "process-blocks" # Comment this to make it work
        implicitlySelectable
        required .}: BlockProcessingCat
      of catBlockHeader:
        discard
      of catAttestations:
        attestation*{.
          desc: "Attestation filename (without .ssz)"
          name: "attestation".}: string

let scenario = ScenarioConf.load(termWidth = int.high)
