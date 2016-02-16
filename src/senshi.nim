import os,strutils
import ircbot/ibMain
import streamer/sbMain, streamer/sbStream
import manager/smMain
import icestat/isMain
import projectTypes, projectEvents , projectCfg

const VERSION = "0.1.0"
var
 chanManager: StringChannel
 chanStreamer: StringChannel
 chanIrcBot: StringChannel
 chanIceStat: StringChannel
 thrManager: Thread[int]
 thrStreamer: Thread[int]
 thrIrcBot: Thread[int]
 thrIceStat: Thread[int]

proc ircBotStartThread* (thrID: int) {.thread.} =
 echoInfo("Irc Bot\t- initializing..")
 var
  paths: PPaths
  irc: PIrc

 new irc
 let chanMan = chanManager.addr
 let chanBot = chanIrcBot.addr

 paths.setPaths()
 irc.load(paths.cfg.ib)
 irc.start(paths,chanMan,chanBot)

proc icestatStartThread* (thrID: int) {.thread.} =
 echoInfo("IceStat\t- initializing..")
 var
  paths: PPaths

 let chanMan = chanManager.addr
 let chanStat = chanIceStat.addr

 paths.setPaths()
 icestatStart(paths.fpIceOut, chanMan, chanStat)

proc managerStartThread* (thrID: int) {.thread.} =
 echoInfo("Manager\t- initializing..")

 var
  paths: PPaths
  man: StreamManager

 let chanMan = chanManager.addr
 let chanStr = chanStreamer.addr
 let chanBot = chanIrcBot.addr
 let chanStat = chanIceStat.addr

 paths.setPaths()
 man.connCfg.load(paths.cfg.manDb)
 man.echoTrackInfo = true

 if man.connectToMysql():
  man.start(paths,chanMan,chanStr,chanBot,chanStat)


proc streamerStartThread*(thrID: int) {.thread.} =
 echoInfo("Stream\t- initializing..")
 var
  paths: PPaths
  streamBot: StreamBot

 let chanMan = chanManager.addr
 let chanStr = chanStreamer.addr

 paths.setPaths()
 streamBot.cfg.load(paths.cfg.sb)

 if streamBot.init():
  streamBot.shout.start(chanMan, chanStr)
 else:
  logEvent(true, "***Error Streamer: Initializing failed")
  streamBot.quit()
  quit()

 streamBot.quit()


proc startUp() =
 echoInfo("\t*** DJ SenShi starting ***")
 var
  projPaths: PPaths

 if not projPaths.init():
  echoInfo("Quitting...")
  quit()

 echoInfo("\t*** Starting threading ...")
 chanManager.open()
 createThread(thrManager, managerStartThread, 0)

 chanStreamer.open()
 createThread(thrStreamer, streamerStartThread, 1)

 chanIrcBot.open()
 createThread(thrIrcBot, ircBotStartThread, 2)

 chanIceStat.open()
 createThread(thrIceStat, icestatStartThread, 3)

 joinThreads(thrManager,thrStreamer,thrIrcBot,thrIceStat)

 chanManager.close()
 chanStreamer.close()
 chanIrcBot.close()
 chanIceStat.close()



when isMainModule: startUp()
