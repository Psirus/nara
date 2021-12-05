import std/tables

{.passL: "-lportmidi".}
{.pragma: pmHeader, header: "portmidi.h"}

type
  DeviceID* = cint
  Error* {.size: sizeof(cint).} = enum
    pmHostError = -10000, pmInvalidDeviceId, ## *< out of range or
                                         ##  output device when input is requested or
                                         ##  input device when output is requested or
                                         ##  device is already opened
                                         ##
    pmInsufficientMemory, pmBufferTooSmall, pmBufferOverflow, pmBadPtr, ## *< PortMidiStream parameter is NULL or
                                                                    ##  stream is not opened or
                                                                    ##  stream is output when input is required or
                                                                    ##  stream is input when output is required
    pmBadData,                ## *< illegal midi data, e.g. missing EOX
    pmInternalError, pmBufferMaxSize, ## *< buffer is already as large as it can be
    pmNotImplemented,         ## *< the function is not implemented, nothing was done
    pmInterfaceNotSupported,  ## *< the requested interface is not supported
                            ##  NOTE: If you add a new error type, be sure to update Pm_GetErrorText()
    pmNoError = 0, pmGotData = 1   ## *< A "no error" return also indicating data available

  # TODO probably incorrect, was void; we'll see if (when) it crashes, I guess
  PortMidiStream* {.importc: "PortMidiStream", pmHeader.} = object
  Message* = cint
  Timestamp* = cint
  TimeProcPtr* {.importc: "Pm$1", pmHeader.} = proc (time_info: pointer): Timestamp {.cdecl.}


  DeviceInfo* {.importc: "PmDeviceInfo", pmHeader, bycopy.} = object
    structVersion*: cint       ## *< this internal structure version
    interf*: cstring           ## *< underlying MIDI API, e.g. MMSystem or DirectX
    name*: cstring             ## *< device name, e.g. USB MidiSport 1x1
    input*: cint               ## *< true iff input is available
    output*: cint              ## *< true iff output is available
    opened*: cint              ## *< used by generic PortMidi code to do error checking on arguments

proc getDefaultOutputDeviceID*(): DeviceID {.importc: "Pm_GetDefaultOutputDeviceID", pmHeader.}
proc countDevices*(): cint {.importc: "Pm_CountDevices", pmHeader.}
proc getDeviceInfo*(id: DeviceID): ptr DeviceInfo {.importc: "Pm_GetDeviceInfo", pmHeader.}
proc openOutput*(stream: ptr ptr PortMidiStream; outputDevice: DeviceID;
                   outputDriverInfo: pointer; bufferSize: cint;
                   time_proc: TimeProcPtr; time_info: pointer; latency: cint): Error {.
                     importc: "Pm_OpenOutput", pmHeader, cdecl.}
proc close*(stream: ptr PortMidiStream): Error {.importc: "Pm_Close", pmHeader.}
proc writeShort*(stream: ptr PortMidiStream; timestamp: Timestamp; msg: Message): Error {.
    importc: "Pm_WriteShort", pmHeader.}

template Pm_Message*(status, data1, data2: untyped): untyped =
  ((((data2) shl 16) and 0xFF0000) or (((data1) shl 8) and 0xFF00) or ((status) and 0xFF))

template Pm_MessageStatus*(msg: untyped): untyped =
  ((msg) and 0xFF)

template Pm_MessageData1*(msg: untyped): untyped =
  (((msg) shr 8) and 0xFF)

template Pm_MessageData2*(msg: untyped): untyped =
  (((msg) shr 16) and 0xFF)

# Some additional methods, nordmidi only procs

proc getOutputDevices*(): seq[(DeviceID, DeviceInfo)] =
  for i in 0..<countDevices():
    let deviceInfo = getDeviceInfo(i)[]
    if deviceInfo.output == 1:
      result.add((i, deviceInfo))

proc toMidiNote*(octave: int, note: string): int =
  let noteValues = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}.toTable
  result = 12*(octave + 1) + noteValues[note]

proc toString*(note: int): string =
  let octave = note div 12 - 1
  let pitch = note - 12 * (octave + 1)
  let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
  result = $noteNames[pitch] & $octave
