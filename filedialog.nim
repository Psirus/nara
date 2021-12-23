import os
import imgui

var
  isActive = false
  currentPath = getHomeDir()
  folderIndex = 0
  fileIndex = 0
  newFolderName = newString(500)
  currentFile = newString(500)

proc activate*() =
  isActive = true

proc draw*(filename: var string) =
  if isActive:
    igSetNextWindowSize(ImVec2(x: 740, y: 410))
    igBegin("Choose output file", nil, ImGuiWindowFlags.NoResize)
    igText(currentPath)

    var files: seq[string]
    var folders: seq[string]
    for k in walkDir(currentPath):
      if isHidden(k.path): continue
      case k.kind
      of pcFile, pcLinkToFile:
        files.add(k.path)
      of pcDir, pcLinkToDir:
        folders.add(k.path)

    igBeginChild("Directories", ImVec2(x: 200, y: 300), true, HorizontalScrollbar)
    if igSelectable("..", false, AllowDoubleClick):
      if igIsMouseDoubleClicked(ImGuiMouseButton.Left):
        currentPath = parentDir(currentPath)
    for i, folder in folders:
      if igSelectable(relativePath(folder, currentPath), i == folderIndex, AllowDoubleClick):
        if igIsMouseDoubleClicked(ImGuiMouseButton.Left):
          currentPath = folder
          folderIndex = 0
          fileIndex = 0
          igSetScrollHereY(0.0)
        else:
          folderIndex = i
    igEndChild()

    igSameLine()

    igBeginChild("Files", ImVec2(x: 516, y: 300), true, HorizontalScrollbar)
    for i, file in files:
      if igSelectable(relativePath(file, currentPath), i == fileIndex, AllowDoubleClick):
        fileIndex = i
        currentFile = file
    igEndChild()
    igPushItemWidth(724)
    igInputText("", currentFile, uint(currentFile.len))
    if igButton("New folder"):
      igOpenPopup("NewFolderPopup")

    igSetNextWindowPos(ImVec2(x: 600, y: 400), Appearing, ImVec2(x: 0.5f, y: 0.5f))
    if igBeginPopup("NewFolderPopup", ImGuiWindowFlags.Modal):
      igText("Enter a name for the new folder")
      var newFolderError: string
      igInputText("", newFolderName[0].addr, uint(newFolderName.len))
      if igButton("Create##1"):
        if newFolderName.len == 0:
          newFolderError = "Folder name can\'t be empty"
        else:
          var newFilePath = joinPath(currentPath, $newFolderName)
          createDir(newFilePath)
          igCloseCurrentPopup()
      igSameLine()
      if igButton("Cancel##1"):
        newFolderName = ""
        newFolderError = ""
        igCloseCurrentPopup()
      igTextColored(ImVec4(x: 1, y: 0, z: 0.2, w: 1), newFolderError)
      igEndPopup()

    if igButton("Cancel"):
      isActive = false
      fileIndex = 0
      folderIndex = 0
      currentFile = ""
    igSameLine()
    if igButton("Select"):
      isActive = false
      filename = currentFile
    igEnd()
