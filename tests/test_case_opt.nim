# confutils
# Copyright (c) 2018-2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import unittest2, ../confutils

#type
#  StartupCommand* = enum
#    noCommand
#    cmdSlotProcessing
#    cmdBlockProcessing
#
#  BlockProcessingCat* = enum
#    catBlockHeader
#    catAttestations
#    catDeposits
#
#  ScenarioConf* = object
#    preState* {.
#      desc: "The name of your pre-state (without .ssz)"
#      name: "pre"
#      abbr: "p"
#      defaultValue: "pre".}: string
#    case cmd*{.
#      command
#      defaultValue: noCommand }: StartupCommand
#    of noCommand:
#      discard
#    of cmdSlotProcessing:
#      numSlots* {.
#        desc: "The number of slots the pre-state will be advanced by"
#        name: "num-slots"
#        abbr: "s"
#        defaultValue: 1.}: uint64
#    of cmdBlockProcessing:
#      case blockProcessingCat* {.
#        desc: "block transitions"
#        #name: "process-blocks" # Comment this to make it work
#        implicitlySelectable
#        required .}: BlockProcessingCat
#      of catBlockHeader:
#        discard
#      of catAttestations:
#        attestation*{.
#          desc: "Attestation filename (without .ssz)"
#          name: "attestation"
#          defaultValue: "attestation default".}: string
#      of catDeposits:
#        discard
#
#suite "test case option":
#  test "no command":
#    let conf = ScenarioConf.load(cmdLine = @[])
#    check:
#      conf.cmd == StartupCommand.noCommand
#      conf.preState == "pre"
#
#  test "case option has default value":
#    let conf = ScenarioConf.load(cmdLine = @[
#      "cmdBlockProcessing",
#      "--blockProcessingCat=catAttestations",
#      "--attestation=attestation"
#    ])
#    check:
#      conf.cmd == StartupCommand.cmdBlockProcessing
#      conf.blockProcessingCat == BlockProcessingCat.catAttestations
#      conf.attestation == "attestation"

type
  StartupCommand* = enum
    noCommand
    cmdSlotProcessing
    cmdBlockProcessing

  BlockProcessingCat* = enum
    catBlockHeader
    catAttestations
    catDeposits

  TestConf = object
    preState {.
      desc: "The name of your pre-state (without .ssz)"
      name: "pre"
      abbr: "p"
      defaultValue: "pre".}: string
    case blockProcessingCat {.
      desc: "block transitions"
      #name: "process-blocks" # Comment this to make it work
      implicitlySelectable
      required .}: BlockProcessingCat
    of catBlockHeader:
      discard
    of catAttestations:
      attestation{.
        desc: "Attestation filename (without .ssz)"
        name: "attestation"
        defaultValue: "attestation default".}: string
    of catDeposits:
      discard
    
    case block2 {.
      desc: "block transitions"
      #name: "process-blocks" # Comment this to make it work
      implicitlySelectable
      required .}: StartupCommand
    of noCommand:
      discard
    of cmdSlotProcessing:
      attestation2 {.
        desc: "Attestation filename (without .ssz)"
        name: "attestation2"
        defaultValue: "attestation default".}: string
    of cmdBlockProcessing:
      discard

suite "test case option":
#  test "case option has default value":
#    let conf = TestConf.load(cmdLine = @[
#      "--blockProcessingCat=catAttestations",
#      #"--attestation=attestation"
#    ])
#    check:
#      conf.blockProcessingCat == BlockProcessingCat.catAttestations
#      conf.attestation == "attestation default"
#
#  test "case option set value":
#    let conf = TestConf.load(cmdLine = @[
#      "--blockProcessingCat=catAttestations",
#      "--attestation=foobar"
#    ])
#    check:
#      conf.blockProcessingCat == BlockProcessingCat.catAttestations
#      conf.attestation == "foobar"
#
#  test "case option set value":
#    let conf = TestConf.load(cmdLine = @[
#      "--blockProcessingCat=catAttestations",
#      "--attestation=foobar",
#      "--pre=foo"
#    ])
#    check:
#      conf.blockProcessingCat == BlockProcessingCat.catAttestations
#      conf.attestation == "foobar"
#      conf.preState == "foo"

  test "case option set value":
    let conf = TestConf.load(cmdLine = @[
      "--blockProcessingCat=catAttestations",
      "--attestation=foobar",
      "--block2=cmdSlotProcessing",
      "--attestation2=bar"
    ])
    check:
      conf.blockProcessingCat == BlockProcessingCat.catAttestations
      conf.block2 == StartupCommand.cmdSlotProcessing
      conf.attestation == "foobar"
      conf.attestation2 == "bar"
