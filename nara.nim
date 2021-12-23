import imgui, imgui/[impl_opengl, impl_glfw]
import nimgl/[opengl, glfw]

import ui

proc main() =
  ui.init()
  doAssert glfwInit()

  glfwWindowHint(GLFWContextVersionMajor, 3)
  glfwWindowHint(GLFWContextVersionMinor, 3)
  glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE)
  glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFWResizable, GLFW_TRUE)

  var w: GLFWWindow = glfwCreateWindow(600, 400, "Nara")
  if w == nil:
    quit(-1)

  w.makeContextCurrent()

  doAssert glInit()

  let context = igCreateContext()

  doAssert igGlfwInitForOpenGL(w, true)
  doAssert igOpenGL3Init()

  igStyleColorsCherry()
  igPushStyleVar(ItemSpacing, ImVec2(x: 5, y: 3));
  # let io = igGetIO()
  # io.fonts.addFontFromFileTTF("GilliusADF-Regular.otf", 20)

  var show_demo: bool = false
  var use_work_area = false

  while not w.windowShouldClose:
    glfwPollEvents()

    igOpenGL3NewFrame()
    igGlfwNewFrame()
    igNewFrame()

    let viewport = igGetMainViewport()
    let flags = ImGuiWindowFlags(ord(ImGuiWindowFlags.NoDecoration) or ord(ImGuiWindowFlags.NoMove) or ord(ImGuiWindowFlags.NoResize) or ord(ImGuiWindowFlags.NoSavedSettings))
    igSetNextWindowPos(if use_work_area: viewport.workPos else: viewport.pos)
    igSetNextWindowSize(if use_work_area: viewport.workSize else: viewport.size)

    igBegin("Nara main window", flags=flags)

    when not defined(release):
      igCheckbox("Demo Window", show_demo.addr)
      if show_demo:
        igShowDemoWindow(show_demo.addr)
    mainWindow()

    igEnd()

    igRender()

    igOpenGL3RenderDrawData(igGetDrawData())

    w.swapBuffers()

  igOpenGL3Shutdown()
  igGlfwShutdown()
  context.igDestroyContext()

  w.destroyWindow()
  glfwTerminate()

main()
