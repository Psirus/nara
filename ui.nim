import os, lenientops, strformat

import imgui

import nordaudio
import nordmidi
import sampling
import formats
import filedialog

type
  Note = object
    octave: cint
    note: cint
  RecordingData = object
    midiLow: int
    midiHigh: int
    stride: int
    midiDevice: nordmidi.DeviceID
    audioDevice: nordaudio.DeviceIndex
    sampleDir: string
    progress: ptr float

var
  notes: seq[cstring] = @[cstring("C"), "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
  minNote = Note(octave: 3, note: 0)
  maxNote = Note(octave: 5, note: 0)
  stride: cint = 5

  audioInputs: seq[int]
  audioDeviceNames: seq[cstring]
  audioInputIndex: cint

  midiOutputs: seq[int]
  midiOutputNames: seq[cstring]
  midiOutputIndex: cint

  filename = ""
  recordingThread: Thread[RecordingData]
  progress = 0.0

proc init*() =
  discard nordaudio.initNoDebug()

  for i in 0..<getDeviceCount():
    let deviceInfo = nordaudio.getDeviceInfo(i)
    if deviceInfo.maxInputChannels > 0:
      audioInputs.add(i)
      audioDeviceNames.add(deviceInfo.name)

  for (i, dev) in getOutputDevices():
    midiOutputs.add(i)
    midiOutputNames.add(dev.name)

proc recording(data: RecordingData) {.thread.} =
  data.progress[] = 0.0

  var numNotes = 0
  for note in countup(data.midiLow, data.midiHigh, data.stride):
    numNotes.inc 

  for note in countup(data.midiLow, data.midiHigh, data.stride):
    sample(data.midiDevice, data.audioDevice, note, fmt"{data.sampleDir}/{toString(note)}.wav")
    data.progress[] += 1.0/numNotes


proc startRecording() =
  let sampleDir = joinPath(parentDir(filename), "samples")
  createDir(sampleDir)

  var data: RecordingData
  data.midiLow = toMidiNote(minNote.octave, minNote.note)
  data.midiHigh = toMidiNote(maxNote.octave, maxNote.note)
  data.stride = stride
  data.audioDevice = DeviceIndex(audioInputs[audioInputIndex])
  data.midiDevice = cast[nordmidi.DeviceID](midiOutputs[midiOutputIndex])
  data.sampleDir = sampleDir
  data.progress = progress.addr

  createThread[RecordingData](recordingThread, recording, data)

  var samples: seq[(int, string)]
  for note in countup(data.midiLow, data.midiHigh, data.stride):
    samples.add((note, fmt"samples/{toString(note)}.wav"))
  writeDecentSampler(filename, samples)

proc mainWindow*() =
  igText("Audio Input")
  igSameLine(300)
  igText("Midi output")
  igPushItemWidth(300)
  discard igListBox("##AudioListBox", audioInputIndex.addr, audioDeviceNames[0].addr, int32(audioDeviceNames.len))
  igSameLine()
  discard igListBox("##MidiListBox", midiOutputIndex.addr, midiOutputNames[0].addr, int32(midiOutputNames.len))
  igPopItemWidth()

  igText("Start note")
  igSameLine(200)
  igText("End note")
  igSameLine(400)
  igText("Stride")

  igPushItemWidth(80)
  igCombo("##minNote", minNote.note.addr, notes[0].addr, int32(notes.len))
  igSameLine()
  igInputInt("##minOctave", minNote.octave.addr)
  igSameLine(200)
  igCombo("##maxNote", maxNote.note.addr, notes[0].addr, int32(notes.len))
  igSameLine()
  igInputInt("##maxOctave", maxNote.octave.addr)
  igSameLine(400)
  igInputInt("##stride", stride.addr)
  igPopItemWidth()

  igText(cstring("Output file: " & $filename))
  igSameLine()

  if igButton("Choose file"):
    filedialog.activate()

  filedialog.draw(filename)

  if igButton("Start sampling"):
    startRecording()

  igProgressBar(progress, ImVec2(x: 0, y: 0))
