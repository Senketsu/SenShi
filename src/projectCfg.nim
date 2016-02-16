import os, strutils
import projectTypes, projectEvents
import streamer/sbMain, manager/smMain, manager/smTopic, ircbot/ibMain


proc setPaths* (paths: var PPaths) =
 paths.home = getHomeDir()
 paths.senshi = joinPath(paths.home,"Senshi")
 paths.log = joinPath(paths.senshi,"log")
 paths.data = joinPath(paths.senshi,"data")
 paths.cfg.dir = joinPath(paths.senshi,"conf")
 paths.cfg.sb = joinPath(paths.cfg.dir, "Stream_Bot.ini")
 paths.cfg.ib = joinPath(paths.cfg.dir, "Irc_Bot.ini")
 paths.cfg.manDb = joinPath(paths.cfg.dir, "Manager_DB.ini")
 paths.cfg.manTopic = joinPath(paths.cfg.dir, "Manager_Topic.ini")
 paths.fpDB = joinPath(paths.data,"Senshi.db")
 paths.fpIceOut = joinPath(paths.data,"iceOut.xsl")


proc firstRunSetup* (paths: var PPaths): bool =
 echoInfo("First run detected, or no config files found.")
 echoInfo("Do you want to go trough setup now ? (y/n)")
 echoInfo("\t[Choosing 'no' will create default config files for vagrant setup]")
 var
  manDb: ManDbCfg
  sb: StreamBotCfg
  topic: ManTopicFormat
  irc: PIrc
 new irc
 while true:
  let line = readLine(stdin)
  let tlLine = line.toLower()
  case tlLine
  of "y","yes":
   echoInfo("First run setup: [1/3]")
   manDb.setNew(paths.cfg.manDb)
   echoInfo("First run setup: [2/3]")
   sb.setNew(paths.cfg.sb)
   echoInfo("First run setup: [3/3]")
   irc.setNew(paths.cfg.ib)
   echoInfo("First run setup: [4/4]")
   topic.setNew(paths.cfg.manTopic)
   echoInfo("All done ! Ready to roll..")
   result = true
   break
  of "n","no":
   echoInfo("Default config files will be created in '$1'" % paths.cfg.dir)
   echoInfo("Please edit them according to your needs.")
   manDb.loadDef(paths.cfg.manDb)
   sb.loadDef(paths.cfg.sb)
   irc.loadDef(paths.cfg.ib)
   topic.loadDef(paths.cfg.manTopic)
   break
  else:
   echoInfo("* Not a valid choice, type 'yes' or 'no' and press enter.")

proc checkConfigs* (paths: var PPaths): bool =
 echoInfo("\t*** Checking config files ...")

 try:
  if not existsDir(paths.cfg.dir):
   return paths.firstRunSetup()
  else:
   if not existsFile(joinPath(paths.cfg.dir, "Manager_DB.ini")):
    var manDbInfo: ManDbCfg
    manDbInfo.set(paths.cfg.manDb)
   if not existsFile(joinPath(paths.cfg.dir, "Stream_Bot.ini")):
    var sb: StreamBotCfg
    sb.set(paths.cfg.sb)
   if not existsFile(joinPath(paths.cfg.dir, "Manager_Topic.ini")):
    var manTopic: ManTopicFormat
    manTopic.set(paths.cfg.manTopic)
   if not existsFile(joinPath(paths.cfg.dir, "Irc_Bot.ini")):
    var irc: PIrc
    new irc
    irc.set(paths.cfg.ib)
   return true
 except:
  logEvent(true,"***Error: Failed to create & set config files. Exiting..")
  return false


proc init*(paths: var PPaths):bool =
 result = false
 paths.home = getHomeDir()
 paths.senshi = joinPath(paths.home,"Senshi")
 paths.log = joinPath(paths.senshi,"log")
 paths.data = joinPath(paths.senshi,"data")
 paths.cfg.dir = joinPath(paths.senshi,"conf")
 paths.cfg.sb = joinPath(paths.cfg.dir, "Stream_Bot.ini")
 paths.cfg.ib = joinPath(paths.cfg.dir, "Irc_Bot.ini")
 paths.cfg.manDb = joinPath(paths.cfg.dir, "Manager_DB.ini")
 paths.cfg.manTopic = joinPath(paths.cfg.dir, "Manager_Topic.ini")
 paths.fpDB = joinPath(paths.data,"Senshi.db")
 paths.fpIceOut = joinPath(paths.data,"iceOut.xsl")
 if not existsDir(paths.senshi):
  try:
   createDir(paths.senshi)
   createDir(paths.log)
   createDir(paths.data)
   createDir(paths.cfg.dir)
   if paths.firstRunSetup():
    result = true
   else:
    result = false
    echoInfo("Are you sure you want to run with default settings ?")
    while true:
     let line = readLine(stdin)
     let tlLine = line.toLower()
     case tlLine
     of "y","yes":
      result = true
      break
     of "n","no":
      result = false
      break
     else:
      echoInfo("* Not a valid choice, type 'yes' or 'no' and press enter.")
  except:
   logEvent(true,"***Error: Failed to create & set project paths. Exiting..")
 else:
  result = paths.checkConfigs()

