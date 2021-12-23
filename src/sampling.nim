import nordmidi
import nordaudio
import sndfile
import os, lenientops, bitops

const
  SAMPLE_RATE = 44100
  FRAMES_PER_BUFFER = 512
  NUM_SECONDS = 1
  NUM_CHANNELS = 2
  SAMPLE_SILENCE = 0.0

type
  TestData = object
    frameIndex: int
    maxFrameIndex: int
    recordedSamples: seq[cfloat]

# Bit of pointer arithmetic needed to closely replicate PortAudio example
template `+`[T](p: ptr T, off: int): ptr T =
  cast[ptr type(p[])](cast[ByteAddress](p) +% off * sizeof(p[]))

template `+=`[T](p: ptr T, off: int) =
  p = p + off

proc recordCallback(inputBuffer: pointer; outputBuffer: pointer;
                    framesPerBuffer: culong;
                    timeInfo: ptr StreamCallbackTimeInfo;
                    statusFlags: StreamCallbackFlags; userData: pointer): cint {.cdecl.} =
  var data = cast[ptr TestData](userData)
  var input = cast[ptr cfloat](inputBuffer)

  var framesLeft = data.maxFrameIndex - data.frameIndex
  let startIndex = data.frameIndex * NUM_CHANNELS

  var framesToCalc: int
  if framesLeft < cast[int](framesPerBuffer):
    framesToCalc = framesLeft
    result = cast[cint](paComplete)
  else:
    framesToCalc = cast[int](framesPerBuffer)
    result = cast[cint](paContinue)

  if inputBuffer == nil:
    for frame in 0..<framesToCalc:
      let index = startIndex + NUM_CHANNELS * frame
      data.recordedSamples[index] = SAMPLE_SILENCE
      if NUM_CHANNELS == 2:
        data.recordedSamples[index + 1] = SAMPLE_SILENCE
  else:
    for frame in 0..<framesToCalc:
      let index = startIndex + NUM_CHANNELS * frame
      data.recordedSamples[index] = input[]
      input += 1
      if NUM_CHANNELS == 2:
        data.recordedSamples[index + 1] = input[]
        input += 1

  data.frameIndex += framesToCalc

proc sample*(midiDevice: nordmidi.DeviceID, audioDevice: DeviceIndex, note: int, filename: string) =
  # init MIDI stuff
  var midiStream: ptr PortMidiStream

  let bufferSize: cint = 0
  let latency: cint = 0
  var error = openOutput(addr(midiStream), midiDevice, nil, bufferSize,  nil, nil, latency)
  echo error

  # init audio stuff
  var data: TestData
  let totalFrames = NUM_SECONDS * SAMPLE_RATE
  data.maxFrameIndex = totalFrames
  data.frameIndex = 0
  let numSamples = totalFrames * NUM_CHANNELS
  data.recordedSamples = newSeq[cfloat](numSamples)

  discard initialize()

  var inputParameters: StreamParameters
  inputParameters.device = audioDevice
  inputParameters.channelCount = NUM_CHANNELS
  inputParameters.sampleFormat = paFloat32

  var audioStream: ptr Stream
  var err = openStream(addr(audioStream), addr(inputParameters), nil, SAMPLE_RATE, FRAMES_PER_BUFFER,
                      paClipOff, recordCallback, addr(data))

  # Actual samplingn
  err = startStream(audioStream)

  var msg = cast[Message](Pm_Message(0x90, note, 100))
  error = writeShort(midiStream, 0, msg)
  sleep(500)
  msg = cast[Message](Pm_Message(0x90, note, 0))
  error = writeShort(midiStream, 0, msg)
  sleep(500)

  # teardown
  err = closeStream(audioStream)
  discard terminate()

  error = close(midiStream)
  echo error

  # write wav file
  var fileInfo: TINFO
  fileInfo.frames = totalFrames
  fileInfo.samplerate = SAMPLE_RATE
  fileInfo.channels = NUM_CHANNELS
  fileInfo.format = bitor(cast[cint](SF_FORMAT_PCM_16), cast[cint](SF_FORMAT_WAV))

  var waveFile = open(filename, WRITE, fileInfo.addr)
  echo data.recordedSamples.len
  echo waveFile.write_float(data.recordedSamples[0].addr, data.recordedSamples.len)
  discard waveFile.close()

