import os, strutils
import sbMain, nshout, projectEvents, projectTypes

var
 isAfkStream: bool = false
 isStreamDesk: bool = false
 isKillRequest: bool = false

proc quit*(streamBot: var StreamBot) =
 streamBot.shout.free()
 shoutShutdown()

proc init*(streamBot: var StreamBot): bool =
 shoutInit()
 streamBot.shout = shoutNew()

 if streamBot.shout.setHost(streamBot.cfg.host) > 0:
  logEvent(true,"***Error Streamer: $1" % [$streamBot.shout.getError()])

 if streamBot.shout.setProtocol((uint)streamBot.cfg.protocol) != SHOUTERR_SUCCESS:
  logEvent(true,"***Error Streamer: $1" % [$streamBot.shout.getError()])
  return

 if streamBot.shout.setPort((cushort)streamBot.cfg.port) != SHOUTERR_SUCCESS:
  logEvent(true,"***Error Streamer: $1" % [$streamBot.shout.getError()])
  return

 if streamBot.shout.setPassword(streamBot.cfg.pass) != SHOUTERR_SUCCESS:
  logEvent(true,"***Error Streamer: $1" % [$streamBot.shout.getError()])
  return

 if streamBot.shout.setMount(streamBot.cfg.mount) != SHOUTERR_SUCCESS:
  logEvent(true,"***Error Streamer: $1" % [$streamBot.shout.getError()])
  return

 if streamBot.shout.setUser(streamBot.cfg.user) != SHOUTERR_SUCCESS:
  logEvent(true,"***Error Streamer: $1" % [$streamBot.shout.getError()])
  return

 if streamBot.shout.setFormat((uint)streamBot.cfg.format) != SHOUTERR_SUCCESS:
  logEvent(true,"***Error Streamer: $1" % [$streamBot.shout.getError()])
  return

 if streamBot.shout.setGenre(streamBot.cfg.genre) != SHOUTERR_SUCCESS:
  logEvent(true,"***Error Streamer: $1" % [$streamBot.shout.getError()])
  return

 if streamBot.shout.setName(streamBot.cfg.name) != SHOUTERR_SUCCESS:
  logEvent(true,"***Error Streamer: $1" % [$streamBot.shout.getError()])
  return

 if streamBot.shout.setDescription(streamBot.cfg.desc) != SHOUTERR_SUCCESS:
  logEvent(true,"***Error Streamer: $1" % [$streamBot.shout.getError()])
  return

 if streamBot.shout.setAudioInfo(SHOUT_AI_BITRATE , streamBot.cfg.aiBitrate) != SHOUTERR_SUCCESS:
  logEvent(true,"***Error Streamer: $1" % [$streamBot.shout.getError()])
  return

 result = true

proc getNextTrackPath(chanManager,chanStreamer: ptr StringChannel): string =

 var
  chanBuffer: string = ""

 chanManager[].send("sb_new")
 chanBuffer = chanStreamer[].recv()
 if chanBuffer.startsWith("cmd_stream_file"):
  chanBuffer.delete(0,15)
  result = chanBuffer
 else:
  logEvent(true,"***Error Streamer: Invalid manager response $1" % [chanBuffer])
  result = ""

proc checkChannelQueue* (shout: PShout, blocking: bool,
                            chanManager, chanStreamer: ptr StringChannel): bool =
 var
  splitCMD: seq[string]
  chanBuffer: string = ""

 if blocking:
  chanBuffer = chanStreamer[].recv()
  splitCMD = chanBuffer.split(" ")

 else:
  let chanTryBuff = chanStreamer[].tryRecv()
  if chanTryBuff.dataAvailable:
   chanBuffer = chanTryBuff.msg
   splitCMD = chanBuffer.split(" ")
  else:
   return

 case splitCMD[0]
 of "cmd_stream_meta":
  chanBuffer.delete(0,15)
  var metaData: PShoutMeta
  metaData = metaDataNew()
  if metaData.add("song",chanBuffer) == SHOUTERR_SUCCESS:
   discard shout.setMetadata(metaData)
   metaData.free()

 of "cmd_start":
  logEvent(true,"*Notice Streamer: Resuming AFK DJ Senshi")
  isAfkStream = true
  isStreamDesk = false
  result = true

 of "cmd_kill":
  isKillRequest = true

 of "cmd_kill_f":
  isKillRequest = false
  isAfkStream = false
  discard shout.close()
  chanManager[].send("sb_kill_confirm")
  result = true

 of "cmd_quit":
  discard shout.close()
  quit(QuitSuccess)

 of "cmd_skip":
  result = true

 of "stream_status":
  if splitCMD[1] == "true":
   isAfkStream = true
  else:
   isAfkStream = false

  if splitCMD[2] == "true":
   isStreamDesk = true
  else:
   isStreamDesk = false

 else:
  logEvent(true,"**Warning Streamer: Unexpected data from Manager $1" % [chanBuffer])


proc start*(shout: PShout, chanManager, chanStreamer: ptr StringChannel) =
 var
  totRead,fileLen: int32
  ret,read: int
  fileBuffer: TaintedString = ""
  bEOF: bool = false
  filePath: string = ""
  songFile: File
  chanBuffer: string = ""

 echoInfo("Stream\t- Setup complete .. starting")
 chanManager[].send("sb_get_status")
 discard shout.checkChannelQueue(true,chanManager, chanStreamer)

 ## Endless streamer loop - Never breaks unless fatal error, idle if cmd_kill
 try:
  while true:
   if not isStreamDesk and isAfkStream:
    if shout.open() ==  SHOUTERR_SUCCESS:
     logEvent(false,"*Notice Streamer: Connected to: $1:$2" % [$shout.host,$shout.port])
     chanManager[].send("sb_conn_confirm")
     ## AFK Stream Loop 1 - breaks only by kill
     while isAfkStream:
       filePath = getNextTrackPath(chanManager,chanStreamer)
       if filePath != "":
        chanManager[].send("sb_meta")
        # Prepare file to stream
        if songFile.open(filePath ,fmRead):
         totRead = 0
         bEOF = false
         chanBuffer = ""
         fileBuffer = readAll(songFile)
         songFile.close()
         fileLen = int32(fileBuffer.len())
        else:
         logEvent(true,"***Error Streamer: Can't open file $1" % [filePath])
         continue
       else:
        logEvent(true,"***Error Streamer: Invalid data from Manager $1" % [filePath])
        continue
       if shout.checkChannelQueue(false,chanManager, chanStreamer):
         break

       ## File read & stream loop, breaks @ EOF or cmd_kill / kill_f
       while true:
        var sendArr: array[4096,char]
        for i in 0..4095:
         if totRead + i == fileLen:
          bEOF = true
          read = i
          break
         else:
          sendArr[i] = fileBuffer[totRead+i]
          read = i
        totRead = totRead + int32(read)
        ret = send(shout, sendArr, csize(read))
        if (ret != SHOUTERR_SUCCESS):
         logEvent(true,"***Error Streamer: Shouter: $1" % [$shout.getError()])
         break
        sync(shout)
        # Data sent, check for chan msg meanwhile, on true return do 'break' (force kill)
        if shout.checkChannelQueue(false,chanManager, chanStreamer):
         break
        if bEOF:
         if isKillRequest:
          isAfkStream = false
          isKillRequest = false
          discard shout.close()
          chanManager[].send("sb_kill_confirm")
         break
    # Shout connection failed
    else:
     logEvent(true,"*Notice Streamer: Unable to connect to icecast,connection occupied?")
     chanManager[].send("sb_conn_occupied")
     isAfkStream = false
     isStreamDesk = true
     continue

   while not isAfkStream:
    if shout.checkChannelQueue(true,chanManager, chanStreamer):
     break
 except: # Not sure whats better, for now let it swallow exceptions like a champ
  logEvent(true,"***Error: Streaming bot encountered error: '$1'" % getCurrentExceptionMsg())


