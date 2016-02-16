import os, strutils, times

let
 logEvents*: bool = true
 logError*: bool = true

when defined(Windows):
 let cOut*: bool = false
else:
 let cOut*: bool = true

proc isNumber* (s: string): bool =
 var i = 0
 while s[i] in {'0'..'9'}: inc(i)
 result = i == s.len and s.len > 0


# ESC character octal 33 ,dec 27 ,hex 1B

proc echoInfo* (msg: string) =

 var
  isStream,isIrcBot,isManager,isDebug,isUnk,isPrompt: bool = false

 if msg.startsWith("Stream"):
  isStream = true
 elif msg.startsWith("Irc Bot"):
  isIrcBot = true
 elif msg.startsWith("Manager"):
  isManager = true
 elif msg.startsWith("Debug"):
  isDebug = true
 elif msg[0] == '*':
  isPrompt = true
 else:
  isUnk = true

 if cOut:
  if isManager:
   stdout.writeLine("[Info]: \27[0;35m$1\27[0m" % [msg])
  elif isIrcBot:
   stdout.writeLine("[Info]: \27[0;94m$1\27[0m" % [msg])
  elif isStream:
   stdout.writeLine("[Info]: \27[0;95m$1\27[0m" % [msg])
  elif isDebug:
   stdout.writeLine("[Info]: \27[0;92m$1\27[0m" % [msg])
  elif isPrompt:
   stdout.writeLine("\27[0;96m$1\27[0m" % [msg])
  else:
   stdout.writeLine("[Info]: \27[0;93m$1\27[0m" % msg)
 else:
  stdout.writeLine("[Info]: $1" % msg)




proc logEvent*(logThis: bool, msg: string) =
 var
  isError,isDebug,isWarn,isNotice,isUnk: bool = false
  fileName: string = ""
  logPath: string = joinPath(getHomeDir(),joinPath("Senshi","log"))

 if msg.startsWith("***Error"):
  isError = true
  fileName = "Error.log"
 elif msg.startsWith("*Notice"):
  isNotice = true
 elif msg.startsWith("**Warning"):
  isWarn = true
  fileName = "Error.log"
 elif msg.startsWith("*Debug"):
  isDebug = true
  fileName = "Debug.log"
 else:
  isUnk = true

 if cOut:
  if isError:
   stdout.writeLine("\27[1;31m$1\27[0m" % [msg])
  elif isNotice:
   stdout.writeLine("\27[0;34m$1\27[0m" % [msg])
  elif isWarn:
   stdout.writeLine("\27[0;33m$1\27[0m" % [msg])
  elif isDebug:
   stdout.writeLine("\27[0;32m$1\27[0m" % [msg])
  else:
   stdout.writeLine(msg)
 else:
  stdout.writeLine(msg)

 if (logEvents and logThis) or (logError and isError):
  var
   tStamp: string = ""
   iTimeNow: int = (int)getTime()
  let timeNewTrackWhen = getGMTime(fromSeconds(iTimeNow))
  tStamp = format(timeNewTrackWhen,"[yyyy-MM-dd] (HH:mm:ss)")


  var eventFile: File
  if isError or isDebug or isWarn:
   if eventFile.open(joinPath(logPath,fileName) ,fmAppend):
    eventFile.writeLine("$1: $2" % [tStamp,msg])
    eventFile.flushFile()
    eventFile.close()
