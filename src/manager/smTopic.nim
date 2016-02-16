import strutils, parsecfg , streams
import smStatus, projectEvents

type
 ManTopicFormat* = object
  titleMain, titleSec, titleSecDef, stream, dj, site, other: string
 ManTopic* = object
  format*: ManTopicFormat
  full*: string

proc `titleMain=`*(tf: var ManTopicFormat, value: string) {.inline.} =
 tf.titleMain = value

proc titleMain* (tf: var ManTopicFormat): string {.inline.} =
 tf.titleMain

proc `titleSec=`*(tf: var ManTopicFormat, value: string) {.inline.} =
 tf.titleSec = value

proc titleSec* (tf: var ManTopicFormat): string {.inline.} =
 tf.titleSec

proc `titleSecDef=`*(tf: var ManTopicFormat, value: string) {.inline.} =
 tf.titleSecDef = value

proc titleSecDef* (tf: var ManTopicFormat): string {.inline.} =
 tf.titleSecDef

proc `stream=`*(tf: var ManTopicFormat, value: string) {.inline.} =
 tf.stream = value

proc stream* (tf: var ManTopicFormat): string {.inline.} =
 tf.stream

proc `dj=`*(tf: var ManTopicFormat, value: string) {.inline.} =
 tf.dj = value

proc dj* (tf: var ManTopicFormat): string {.inline.} =
 tf.dj

proc `site=`*(tf: var ManTopicFormat, value: string) {.inline.} =
 tf.site = value

proc site* (tf: var ManTopicFormat): string {.inline.} =
 tf.site

proc `other=`*(tf: var ManTopicFormat, value: string) {.inline.} =
 tf.other = value

proc other* (tf: var ManTopicFormat): string {.inline.} =
 tf.other

proc `full=`*(tf: var ManTopic, value: string) {.inline.} =
 tf.full = value

proc full* (tf: var ManTopic): string {.inline.} =
 tf.full


## Just a first draft of topic procs
proc editFormat* (format: var ManTopicFormat, which: string, new: string): bool =
 result = true
 case which
 of "main":
  format.titleMain = new
 of "sec":
  format.titleSec = new
 of "site":
  format.site = new
 of "other":
  format.other = new
 of "otheradd":
  format.other.add(" | ")
  format.other.add(new)
 of "dj":
  format.dj = new
 of "stream":
  format.stream = new
 else:
  result = false

proc construct* (format: ManTopicFormat, streamUp: bool, djname: string): string =
 result = ""
 result.add(format.titleMain)
 if format.titleSec == "":
  result = result.replace("'?'",format.titleSecDef)
 else:
  result = result.replace("'?'",format.titleSec)
 result.add(" | ")
 result.add('\x02')
 result.add('\x03')
 result.add("00")

 if format.stream == "":
  result.add("Stream:")
 else:
  result.add(format.stream)
 result.add('\x02')
 result.add('\x03')

 if streamUp:
  result.add("03 UP")
 else:
  result.add("04 DOWN")
 result.add('\x03')
 result.add(" | ")
 result.add('\x02')
 result.add('\x03')
 result.add("00")

 if format.dj == "":
  result.add("DJ:")
 else:
  result.add(format.dj)
 result.add('\x02')
 result.add('\x03')
 result.add("10 $1" % djname)
 result.add('\x03')

 if format.site != "":
  result.add(" | ")
  result.add(format.site)

 if format.other != "":
  result.add(" | ")
  result.add('\x03')
  result.add("08")
  result.add(format.other)


proc update* (topic: var ManTopic, status: StreamStatus, setTopic: string = "") =
 var streamUp: bool = false
 if status.isAfkStream or status.isStreamDesk:
  streamUp = true
 if setTopic != "":
  topic.format.titleSec = setTopic
 topic.full = topic.format.construct(streamUp, status.djname)

proc save*(topic: var ManTopicFormat, cfg: string) =
 var
  cfgFile: File

 if cfgFile.open(cfg ,fmWrite):
    cfgFile.writeLine("[Topic]")
    cfgFile.writeLine("titleMain=\"$1\"" % [topic.titleMain])
    cfgFile.writeLine("titleSec=\"$1\"" % [topic.titleSec])
    cfgFile.writeLine("titleSecDef=\"$1\"" % [topic.titleSecDef])
    cfgFile.writeLine("stream=\"$1\"" % [topic.stream])
    cfgFile.writeLine("dj=\"$1\"" % [topic.dj])
    cfgFile.writeLine("site=\"$1\"" % [topic.site])
    cfgFile.writeLine("other=\"$1\"" % [topic.other])
    cfgFile.flushFile()
    cfgFile.close()
 else:
  logEvent(true,"***Error Conf: Couldn't create file '$1'" % [cfg])

proc loadDef*(topic: var ManTopicFormat, cfg: string) =
 echoInfo("Irc Bot\t- Setting default topic options")
 topic.titleMain = "Welcome to Senketsu's Test Cave | '?'"
 topic.titleSecDef = "Stream test in progress"
 topic.titleSec = ""
 topic.stream = "Status: "
 topic.dj = "DJ: "
 topic.site = "https://github.com/Senketsu"
 topic.other = "Enjoy your stay."
 topic.save(cfg)


proc setNew* (topic: var ManTopicFormat, cfg: string) =

 topic.stream = ""
 topic.dj = ""
 topic.site = ""
 topic.titleMain = ""
 topic.titleSec = ""
 topic.titleSecDef = ""
 topic.other = ""

 echoInfo("Set your irc topic config please:")
 echoInfo("* Main:\t\t(main topic with '?' variable)")
 topic.titleMain = readLine(stdin)

 echoInfo("* Secondary:\t(secondary default topic)")
 topic.titleSec = readLine(stdin)

 echoInfo("* Site:\t(link to stream site) [optional]")
 topic.site = readLine(stdin)

 echoInfo("* Other:\t(additional stuff) [optional]")
 topic.other = readLine(stdin)

 echoInfo("Thank you ! All done. Saving and using new config file.")
 topic.save(cfg)

proc set* (topic: var ManTopicFormat, cfg: string) =
 echoInfo("No irc topic config file found:\n\t enter 'n' or 'new' to create new")
 echoInfo("\t enter 'd' or 'def' for hardcoded (vagrant) default\n")

 while true:
  let choice = readLine(stdin)
  case choice
  of "d", "default", "def":
   topic.loadDef(cfg)
   break
  of "n", "new":
   topic.setNew(cfg)
   break
  else:
   stdout.writeLine("Not a valid choice, try again (ganbatte~)")

proc load*(topic: var ManTopicFormat, cfg: string) =
 echoInfo("Irc Bot\t- Loading irc topic configuration file")
 var
  fileStream = newFileStream(cfg, fmRead)
 if fileStream != nil:
  var cfgParser: CfgParser
  open(cfgParser, fileStream, cfg)
  while true:
    var
     event = next(cfgParser)
    case event.kind
    of cfgEof:
      break
    of cfgSectionStart:
     discard
    of cfgKeyValuePair:
     case event.key
     of "titleMain":
      topic.titleMain = event.value
     of "titleSec":
      topic.titleSec = event.value
     of "titleSecDef":
      topic.titleSecDef = event.value
     of "stream":
      topic.stream = event.value
     of "dj":
      topic.dj = event.value
     of "site":
      topic.site = event.value
     of "other":
      topic.other = event.value
     else:
      discard
    of cfgOption:
     discard
    of cfgError:
     logEvent(true,"***Error IRC: $1" % [event.msg])
  close(cfgParser)
 else:
  logEvent(false,"**Warning: Cannot open $1. Creating default." % [cfg])
  topic.set(cfg)
