import os, strutils, json
import projectTypes, projectEvents
import cusFileDL ## Some issue(s) with nim httpClient, dont recall what anymore

type
 IceCastStatus* = tuple
  np: string
  iList: int

proc clear* (stat: var IceCastStatus) =
 stat.np = ""
 stat.iList = 0


proc getIceStatsFile (filePath: string) =
 dlFile("http://localhost:8000/status-json.xsl",filePath)


proc parseIceStats* (filePath: string): IceCastStatus =
 result.iList = 0
 result.np = ""
 try:
  getIceStatsFile(filePath)
  let jObj = parseFile(filePath)
  if jObj.kind == JObject:
   let fields = getFields(jObj)
   for field in fields:
    if field.key == "icestats":
     let stats = getFields(field.val)
     for stat in stats:
      if stat.key == "source":
       let audioInfo = getFields(stat.val)
       for info in audioInfo:
        case info.key
        of "listeners":
         result.iList = (int)(info.val.num)
        of  "title":
         result.np = (info.val.str)
        else:
         discard

 except:
  logEvent(true,"***Error IceParser: $1" % getCurrentExceptionMsg())

proc icestatStart* (fpOutput: string, chanManager,chanStat: ptr StringChannel) =
 var
  chanBuffer: string = ""
  lastStat,curStat: IceCastStatus
  splitCMD: seq[string]

 lastStat.clear()
 curStat.clear()

 while true:
  chanBuffer = chanStat[].recv()
  splitCMD = chanBuffer.split(" ")

  case splitCMD[0]
  of "cmd_start":
   while true:
    curStat = parseIceStats(fpOutput)
    if curStat.np != "":
     if curStat.np != lastStat.np:
      chanManager[].send("icestat_new")
      lastStat = curStat
    sleep(1000)

    let chanTBuff = chanStat[].tryRecv()
    if chanTBuff.dataAvailable:
     var msg: string = chanTBuff.msg
     if msg == "cmd_stop":
      break
     elif msg == "cmd_quit":
      quit(QuitSuccess)

  of "cmd_quit":
   quit(QuitSuccess)


  else:
   discard
