import std/rdstdin
import std/os
import strutils

import nordmidi

let default_out = getDefaultOutputDeviceID()
let num_devices = countDevices()

echo "Available devices:"
for (i, dev) in getOutputDevices():
  echo i, ": ", dev.name

let choice = cast[nordmidi.DeviceID](parseInt(readLineFromStdin "Choose output device: "))

var stream: ptr PortMidiStream

let bufferSize: cint = 0
let latency: cint = 0
var error = openOutput(addr(stream), choice, nil, bufferSize,  nil, nil, latency)
echo error

while true:
  var msg = cast[Message](Pm_Message(0x90, 60, 100))
  error = writeShort(stream, 0, msg)
  echo error
  sleep(500)
  msg = cast[Message](Pm_Message(0x90, 60, 0))
  error = writeShort(stream, 0, msg)
  echo error
  sleep(500)
