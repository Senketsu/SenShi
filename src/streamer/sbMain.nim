import os, strutils, parsecfg , streams
import nshout
import projectEvents

type
 StreamBot* = object
  cfg*: StreamBotCfg
  shout*: PShout

 StreamBotCfg* = object
  host,pass,mount,user,genre,name,desc: string
  port,protocol,format: int
  aiBitrate: string


proc `host=`*(sb: var StreamBotCfg, value: string) {.inline.} =
 sb.host = value

proc host* (sb: var StreamBotCfg): string {.inline.} =
 sb.host

proc `pass=`*(sb: var StreamBotCfg, value: string) {.inline.} =
 sb.pass = value

proc pass* (sb: var StreamBotCfg): string {.inline.} =
 sb.pass

proc `mount=`*(sb: var StreamBotCfg, value: string) {.inline.} =
 sb.mount = value

proc mount* (sb: var StreamBotCfg): string {.inline.} =
 sb.mount

proc `user=`*(sb: var StreamBotCfg, value: string) {.inline.} =
 sb.user = value

proc user* (sb: var StreamBotCfg): string {.inline.} =
 sb.user

proc `genre=`*(sb: var StreamBotCfg, value: string) {.inline.} =
 sb.genre = value

proc genre* (sb: var StreamBotCfg): string {.inline.} =
 sb.genre

proc `name=`*(sb: var StreamBotCfg, value: string) {.inline.} =
 sb.name = value

proc name* (sb: var StreamBotCfg): string {.inline.} =
 sb.name

proc `desc=`*(sb: var StreamBotCfg, value: string) {.inline.} =
 sb.desc = value

proc desc* (sb: var StreamBotCfg): string {.inline.} =
 sb.desc

proc `port=`*(sb: var StreamBotCfg, value: int) {.inline.} =
 sb.port = value

proc port* (sb: var StreamBotCfg): int {.inline.} =
 sb.port

proc `protocol=`*(sb: var StreamBotCfg, value: int) {.inline.} =
 sb.protocol = value

proc protocol* (sb: var StreamBotCfg): int {.inline.} =
 sb.protocol

proc `format=`*(sb: var StreamBotCfg, value: int) {.inline.} =
 sb.format = value

proc format* (sb: var StreamBotCfg): int {.inline.} =
 sb.format

proc `aiBitrate=`*(sb: var StreamBotCfg, value: string) {.inline.} =
 sb.aiBitrate = value

proc aiBitrate* (sb: var StreamBotCfg): string {.inline.} =
 sb.aiBitrate

proc clean* (sb: var StreamBotCfg) =
 sb.host = ""
 sb.port = 0
 sb.pass = ""
 sb.mount = ""
 sb.user = ""
 sb.genre = ""
 sb.name = ""
 sb.desc = ""
 sb.protocol = 0
 sb.format = 0
 sb.aiBitrate = ""

proc save* (sb: var StreamBotCfg, cfg: string) =
 var
  cfgFile: File

 if cfgFile.open(cfg ,fmWrite):
    cfgFile.writeLine("host=\"$1\"" % [sb.host])
    cfgFile.writeLine("port=\"$1\"" % [$sb.port])
    cfgFile.writeLine("pass=\"$1\"" % [sb.pass])
    cfgFile.writeLine("mount=\"$1\"" % [sb.mount])
    cfgFile.writeLine("user=\"$1\"" % [sb.user])
    cfgFile.writeLine("genre=\"$1\"" % [sb.genre])
    cfgFile.writeLine("name=\"$1\"" % [sb.name])
    cfgFile.writeLine("desc=\"$1\"" % [sb.desc])
    cfgFile.writeLine("protocol=\"$1\"" % [$sb.protocol])
    cfgFile.writeLine("format=\"$1\"" % [$sb.format])
    cfgFile.writeLine("aiBitrate=\"$1\"" % [sb.aiBitrate])
    cfgFile.flushFile()
    cfgFile.close()
 else:
  logEvent(true,"***Error Conf: Couldn't create file '$1'" % [cfg])
  discard


proc setNew* (sb: var StreamBotCfg, cfg: string) =
 echoInfo("Set your stream config please:")
 echoInfo("* Host:\t\t(ip or address of your icecast server) [eg: localhost]")
 sb.host = readLine(stdin)

 echoInfo("* Port:\t\t(set port of your icecast server) [default:'8000']")
 let port = readLine(stdin)
 if port.isNumber:
  sb.port = parseInt(port)
 else:
  sb.port = 8000

 echoInfo("* User:\t\t(username used to connect to icecast) [e.g:'source']")
 sb.user = readLine(stdin)

 echoInfo("* Password:\t(password for you icecast connection) [default:'hackme']")
 sb.pass = readLine(stdin)

 echoInfo("* Mount:\t(mount point for your icecast connection) [e.g:'/main.mp3']")
 sb.mount = readLine(stdin)

 echoInfo("* Name:\t\t(your stream name)")
 sb.name = readLine(stdin)

 echoInfo("* Genre:\t(genre of your stream) [whatever you want:'radio','untz'..]")
 sb.genre = readLine(stdin)

 echoInfo("* Description:\t(a short description of your stream)")
 sb.desc = readLine(stdin)

 echoInfo("* Protocol:\t( 0 - HTTP | 1 - XAUDIOCAST | 2 - ICY) [if not sure, 0]")
 let rL = readLine(stdin)
 if rL.isNumber():
  let prot = parseInt(rL)
  if prot > 2:
   sb.protocol = 0
  else:
   sb.protocol = prot
 else:
  sb.protocol = 0

 echoInfo("* Format:\t( 0 - 'ogg' or 'vorbis' | 1 - 'mp3' | 2 - 'webm')")
 let rL2 = readLine(stdin)
 if rL2.isNumber():
  let format = parseInt(rL2)
  if format > 2:
   sb.format = 1
  else:
   sb.format = format
 else:
  sb.format = 1

 echoInfo("* Bitrate:\t(pick your bitrate) [e.g:'256','128'...]")
 sb.aiBitrate = readLine(stdin)
 echoInfo("Thank you ! All done. Saving and using new config file.")
 sb.save(cfg)

proc loadDef* (sb: var StreamBotCfg, cfg: string) =
 echoInfo("Stream\t- Setting default stream options")
 sb.host = "127.0.0.1"
 sb.port = 8000
 sb.pass = "hackme"
 sb.mount = "/main.mp3"
 sb.user = "source"
 sb.genre = "radio"
 sb.name = "Senshi AFK Stream"
 sb.desc = "Senshi Vagrant Test"
 sb.protocol = 0
 sb.format = 1
 sb.aiBitrate = "256"
 sb.save(cfg)

proc set* (sb: var StreamBotCfg, cfg: string) =
 echoInfo("No stream config file found:\n\t enter 'n' or 'new' to create new")
 echoInfo("\t enter 'd' or 'def' for hardcoded (vagrant) default\n")
 while true:
  let choice = readLine(stdin)
  case choice
  of "d", "default", "def":
   sb.loadDef(cfg)
   break
  of "n", "new":
   sb.setNew(cfg)
   break
  else:
   stdout.writeLine("Not a valid choice, try again (ganbatte~)")

proc load* (sb: var StreamBotCfg, cfg: string) =
 echoInfo("Stream\t- Loading stream configuration file")
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
     of "host":
      sb.host = event.value
     of "port":
      sb.port = parseInt(event.value)
     of "pass":
      sb.pass = event.value
     of "mount":
      sb.mount = event.value
     of "user":
      sb.user = event.value
     of "genre":
      sb.genre = event.value
     of "name":
      sb.name = event.value
     of "desc":
      sb.desc = event.value
     of "protocol":
      sb.protocol = parseInt(event.value)
     of "format":
      sb.format = parseInt(event.value)
     of "aiBitrate":
      sb.aiBitrate = event.value
     else:
      discard
    of cfgOption:
     discard
    of cfgError:
     echo(event.msg)
  close(cfgParser)
 else:
  logEvent(false,"**Warning: Cannot open $1" % [cfg])
  sb.set(cfg)
