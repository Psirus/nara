# Package

version       = "0.1.0"
author        = "Christoph Pohl"
description   = "An autosampler"
license       = "MIT"
srcDir        = "src"
bin           = @["nara"]
backend       = "cpp"


# Dependencies

requires "nim >= 1.6.0"
requires "https://github.com/jamesb93/nim-sndfile"
requires "nordaudio"
requires "https://github.com/nimgl/nimgl"
requires "https://github.com/nimgl/imgui"

