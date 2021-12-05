import nordmidi
import nordaudio
import gintro/[gtk, gobject, gio]
import std/with
import strutils, strformat
import sampling

const
  labelMarginEnd = 25

type
  Note = object
    octave: int
    note: string

var
  minNote = Note(octave: 3, note: "C")
  maxNote = Note(octave: 5, note: "C")
  stride = 5
  progressBar: LevelBar
  midiDevice: nordmidi.DeviceID
  audioDevice: nordaudio.DeviceIndex
  midiOutputs: seq[int]
  audioInputs: seq[int]

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

proc numNotes(): int =
  let midiLow = toMidiNote(minNote.octave, minNote.note)
  let midiHigh = toMidiNote(maxNote.octave, maxNote.note)
  return (midiHigh - midiLow) div stride

proc updateProgressBar() =
  if progressBar == nil:
    return
  progressBar.maxValue = toFloat(numNotes())

proc changeOctave(cb: ComboBoxText, selection: string) =
  let octave = parseInt(cb.getActiveText().split(" ")[1])
  case selection
  of "min":
    minNote.octave = octave
  of "max":
    maxNote.octave = octave
  else:
    raise newException(RangeDefect, "Change octave works on either 'min' or 'max'.")

  updateProgressBar()

proc changeNote(cb: ComboBoxText, selection: string) =
  case selection
  of "min":
    minNote.note = cb.getActiveText()
  of "max":
    maxNote.note = cb.getActiveText()
  else:
    raise newException(RangeDefect, "Change note works on either 'min' or 'max'.")

  updateProgressBar()

proc changeStride(sb: SpinButton) =
  stride = toInt(sb.value)
  updateProgressBar()

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

proc startRecording(button: Button) =
  let midiLow = toMidiNote(minNote.octave, minNote.note)
  let midiHigh = toMidiNote(maxNote.octave, maxNote.note)
  for note in countup(midiLow, midiHigh, stride):
    sample(midiDevice, audioDevice, note, fmt"{toString(note)}.wav")

proc createStartStopBox(): Box =
  result = newBox(Orientation.horizontal)
  with result:
    marginStart = 25
    marginTop = 25
    marginEnd = 25
    hexpand = true

  let recordButton = newButton()
  recordButton.connect("clicked", startRecording)
  let recordBox = newBox(Orientation.horizontal)
  let recordIcon = newImageFromIconName("media-record", int(IconSize.button))
  recordIcon.marginEnd = 10
  let recordLabel = newLabel("Start sampling")
  recordBox.add(recordIcon)
  recordBox.add(recordLabel)
  recordButton.add(recordBox)
  result.add(recordButton)


proc appActivate(app: Application) =
  let window = newApplicationWindow(app)
  with window:
    title = "Autosampler"
    defaultSize = (800, 600)

  let columnBox = newBox(Orientation.vertical)

  let connectionsBox = createConnectionsBox()
  let notesBox = createNotesBox()
  let startStopBox = createStartStopBox()

  columnBox.add(connectionsBox)
  columnBox.add(notesBox)
  columnBox.add(startStopBox)

  progressBar = newLevelBarForInterval(0, toFloat(numNotes()))
  with progressBar:
    mode = LevelBarMode.discrete
    marginStart = 25
    marginEnd = 25
    marginTop = 25

  columnBox.add(progressBar)

  window.add(columnBox)
  showAll(window)

proc main =
  discard nordaudio.initNoDebug()

  let app = newApplication("org.psirus.autosampler")
  connect(app, "activate", appActivate)
  discard run(app)

main()
