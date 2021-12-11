import std/with
import math, os, strutils, strformat

import nordmidi
import nordaudio
import gintro/[gtk, gobject, gio]

import sampling
import formats

const
  labelMarginEnd = 25

type
  Note = object
    octave: int
    note: string
  RecordingData = object
    midiLow: int
    midiHigh: int
    stride: int
    midiDevice: nordmidi.DeviceID
    audioDevice: nordaudio.DeviceIndex
    progressBar: LevelBar
    sampleDir: string

var
  minNote = Note(octave: 3, note: "C")
  maxNote = Note(octave: 5, note: "C")
  stride = 5
  progressBar: LevelBar
  midiDevice: nordmidi.DeviceID
  audioDevice: nordaudio.DeviceIndex
  midiOutputs: seq[int]
  audioInputs: seq[int]
  recordingThread: Thread[RecordingData]
  filename: string
  sampleDir: string

proc chooseMidiDevice(box: ListBox, row: ListBoxRow) =
  midiDevice = cast[nordmidi.DeviceID](midiOutputs[row.getIndex()])

proc chooseAudioDevice(box: ListBox, row: ListBoxRow) =
  audioDevice = DeviceIndex(audioInputs[row.getIndex()])

proc createConnectionsBox(): Box =
  result = newBox(Orientation.horizontal)
  with result:
    marginStart = 25
    marginTop = 25
    marginEnd = 25
    hexpand = true

  let audioLabel = newLabel("Audio Input:")
  audioLabel.marginEnd = labelMarginEnd
  let audioInChooser = newListBox()
  audioInChooser.connect("row-selected", chooseAudioDevice)
  for i in 0..<getDeviceCount():
    let deviceInfo = nordaudio.getDeviceInfo(i)
    if deviceInfo.maxInputChannels > 0:
      let devLabel = newLabel(deviceInfo.name)
      let row = newListBoxRow()
      row.add(devLabel)
      audioInputs.add(i)
      audioInChooser.add(row)

  with audioInChooser:
    hexpand = true
    halign = Align.start

  result.add(audioLabel)
  result.add(audioInChooser)

  let midiLabel = newLabel("Midi Output:")
  midiLabel.marginEnd = labelMarginEnd
  let midiOutputChooser = newListBox()
  midiOutputChooser.connect("row-selected", chooseMidiDevice)
  for (i, dev) in getOutputDevices():
    let devLabel = newLabel(dev.name)
    let row = newListBoxRow()
    row.add(devLabel)
    midiOutputs.add(i)
    midiOutputChooser.add(row)

  with midiOutputChooser:
    hexpand = true
    halign = Align.start

  result.add(midiLabel)
  result.add(midiOutputChooser)


proc changeOctave(cb: ComboBoxText, selection: string) =
  let octave = parseInt(cb.getActiveText().split(" ")[1])
  case selection
  of "min":
    minNote.octave = octave
  of "max":
    maxNote.octave = octave
  else:
    raise newException(RangeDefect, "Change octave works on either 'min' or 'max'.")


proc changeNote(cb: ComboBoxText, selection: string) =
  case selection
  of "min":
    minNote.note = cb.getActiveText()
  of "max":
    maxNote.note = cb.getActiveText()
  else:
    raise newException(RangeDefect, "Change note works on either 'min' or 'max'.")


proc changeStride(sb: SpinButton) =
  stride = toInt(sb.value)


proc createNotesBox(): Box =
  result = newBox(Orientation.horizontal)
  with result:
    marginStart = 25
    marginTop = 25
    marginEnd = 25
    hexpand = true

  let noteLabelMin = newLabel("Min Note:")
  noteLabelMin.marginEnd = labelMarginEnd
  let octaveBoxMin = newComboBoxText()
  octaveBoxMin.connect("changed", changeOctave, "min")
  for i in -1..9:
    octaveBoxMin.appendText(cstring("Octave " & $i))
  octaveBoxMin.setActive(4)

  let noteBoxMin = newComboBoxText()
  noteBoxMin.connect("changed", changeNote, "min")
  for note in ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]:
    noteBoxMin.appendText(cstring(note))

  with noteBoxMin:
    active = 0
    hexpand = true
    halign = Align.start

  result.add(noteLabelMin)
  result.add(octaveBoxMin)
  result.add(noteBoxMin)

  let noteLabelMax = newLabel("Max Note:")
  noteLabelMax.marginEnd = labelMarginEnd
  let octaveBoxMax = newComboBoxText()
  octaveBoxMax.connect("changed", changeOctave, "max")
  for i in -1..9:
    octaveBoxMax.appendText(cstring("Octave " & $i))
  octaveBoxMax.setActive(6)

  let noteBoxMax = newComboBoxText()
  noteBoxMax.connect("changed", changeNote, "max")
  for note in ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]:
    noteBoxMax.appendText(cstring(note))

  with noteBoxMax:
    active = 0
    hexpand = true
    halign = Align.start

  result.add(noteLabelMax)
  result.add(octaveBoxMax)
  result.add(noteBoxMax)

  let strideLabel = newLabel("Stride:")
  strideLabel.marginEnd = labelMarginEnd
  let strideButton = newSpinButtonWithRange(1.0, 12.0, 1.0)
  strideButton.connect("changed", changeStride)
  with strideButton:
    value = 5.0
    hexpand = true
    halign = Align.start

  result.add(strideLabel)
  result.add(strideButton)

proc openFileChooser(button: Button, fileEntry: Entry) =
  let fileChooser = newFileChooserNative("Select output file", nil, FileChooserAction.save)
  let homeDir = getHomeDir()
  discard fileChooser.setCurrentFolder(homeDir)
  let response = ResponseType(fileChooser.run())
  if response == ResponseType.accept:
    filename = fileChooser.getFilename()
    sampleDir = joinPath(parentDir(filename), "samples")
    let displayed = filename.replace(homeDir, "~/")
    fileEntry.widthChars = len(displayed)
    fileEntry.text = cstring(displayed)


proc recording(data: RecordingData) {.thread.} =
  data.progressBar.value = data.progressBar.value + cdouble(1.0)
  for note in countup(data.midiLow, data.midiHigh, data.stride):
    sample(data.midiDevice, data.audioDevice, note, fmt"{data.sampleDir}/{toString(note)}.wav")
    data.progressBar.value = data.progressBar.value + cdouble(1.0)

  data.progressBar.value = 0.0
  data.progressBar.hide()

proc startRecording(button: Button) =
  progressBar.show()
  createDir(sampleDir)

  var data: RecordingData
  data.midiLow = toMidiNote(minNote.octave, minNote.note)
  data.midiHigh = toMidiNote(maxNote.octave, maxNote.note)
  data.stride = stride
  data.audioDevice = audioDevice
  data.midiDevice = midiDevice
  data.progressBar = progressBar
  data.sampleDir = sampleDir

  createThread[RecordingData](recordingThread, recording, data)

  progressBar.max_value = ceil((data.midiHigh - data.midiLow) / stride)

  var samples: seq[(int, string)]
  for note in countup(data.midiLow, data.midiHigh, data.stride):
    samples.add((note, fmt"samples/{toString(note)}.wav"))
  writeDecentSampler(filename, samples)

proc createStartStopBox(window: Window): Box =
  result = newBox(Orientation.horizontal)
  with result:
    marginStart = 25
    marginTop = 25
    marginEnd = 25
    hexpand = true

  let fileBox = newBox(Orientation.horizontal)
  let fileEntry = newEntry()
  fileEntry.setPlaceHolderText("Output file name ...")
  let chooseButton = newButton("Choose output file")
  chooseButton.connect("pressed", openFileChooser, fileEntry)
  with fileBox:
    hexpand = true
    halign = Align.start
    add(fileEntry)
    add(chooseButton)



  let recordButton = newButton()
  recordButton.connect("clicked", startRecording)
  let recordBox = newBox(Orientation.horizontal)
  let recordIcon = newImageFromIconName("media-record", int(IconSize.button))
  recordIcon.marginEnd = 10
  let recordLabel = newLabel("Start sampling")
  recordBox.add(recordIcon)
  recordBox.add(recordLabel)
  recordButton.add(recordBox)

  with recordButton:
    hexpand = true
    halign = Align.start

  result.add(fileBox)
  result.add(recordButton)


proc appActivate(app: Application) =
  let window = newApplicationWindow(app)
  with window:
    title = "Nara"
    defaultSize = (800, 600)

  let columnBox = newBox(Orientation.vertical)

  let connectionsBox = createConnectionsBox()
  let notesBox = createNotesBox()
  let startStopBox = createStartStopBox(window)

  columnBox.add(connectionsBox)
  columnBox.add(notesBox)
  columnBox.add(startStopBox)

  progressBar = newLevelBarForInterval(0, 1)
  with progressBar:
    mode = LevelBarMode.discrete
    marginStart = 25
    marginEnd = 25
    marginTop = 25

  columnBox.add(progressBar)

  window.add(columnBox)
  showAll(window)
  progressBar.hide()

proc main =
  discard nordaudio.initNoDebug()

  let app = newApplication("org.psirus.nara")
  connect(app, "activate", appActivate)
  discard run(app)

main()
