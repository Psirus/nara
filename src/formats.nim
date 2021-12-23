import xmltree

proc writeDecentSampler*(filename: string, samples: seq[(int, string)]) =
  var groups = newElement("groups")
  var group = newElement("group")
  groups.add(group)
  for sample in samples:
    var ent = newElement("sample")
    let (note, path) = sample
    ent.attrs = {"path": path, "rootNote": $note}.toXmlAttributes
    group.add(ent)
  let tree = newXmlTree("DecentSampler", [groups])
  var file = open(filename, fmWrite)
  file.write(xmlHeader)
  file.write($tree)
  file.close()
