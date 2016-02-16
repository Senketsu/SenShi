import os, strutils, parsecfg, streams
import projectTypes, projectEvents
import snircl, ibCommands
import ndbex/db_mysql_ex
export PIrc , TIrc

type
 ManDbCfg = tuple
  address,user,pass,dbName: string

proc load (dbInfo: var ManDbCfg, cfg: string) =
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
     of "address":
      dbInfo.address = event.value
     of "user":
      dbInfo.user = event.value
     of "pass":
      dbInfo.pass = event.value
     of "dbName":
      dbInfo.dbName = event.value
     else:
      discard
    of cfgOption:
     discard
    of cfgError:
     echo(event.msg)
  close(cfgParser)
 else:
  logEvent(false,"**Warning: Cannot open $1" % [cfg])

proc connectToMysql (conn: var DbConn, connCfg: ManDbCfg): bool =
 try:
  conn = open(connCfg.address, connCfg.user, connCfg.pass, connCfg.dbName)
  if conn.setEncoding("utf8") == false:
   logEvent(true,"***Error Manager: Failed to set DB connection encoding")
  result = true
 except:
  logEvent(true,"***Error: @connectToMysql (IRC) '$1'" % getCurrentExceptionMsg())


proc save*(irc: var PIrc, cfg: string) =
 var
  cfgFile: File
 if cfgFile.open(cfg ,fmWrite):
    cfgFile.writeLine("[Connect]")
    cfgFile.writeLine("nickName=\"$1\"" % [irc.nickName])
    cfgFile.writeLine("userName=\"$1\"" % [irc.userName])
    cfgFile.writeLine("realName=\"$1\"" % [irc.realName])
    cfgFile.write("channels=\"")
    for chan in irc.channels:
     cfgFile.write(chan & " ")
    cfgFile.writeLine("\"")
    cfgFile.writeLine("network=\"$1\"" % [irc.network])
    cfgFile.writeLine("port=\"$1\"" % [$irc.port])
    cfgFile.writeLine("servPass=\"$1\"" % [irc.servPass])
    cfgFile.writeLine("nickPass=\"$1\"" % [irc.nickPass])
    cfgFile.flushFile()
    cfgFile.close()
 else:
  logEvent(true,"***Error Conf: Couldn't create file '$1'" % [cfg])

proc loadDef*(irc: var PIrc, cfg: string) =
 echoInfo("Irc Bot\t- Setting default irc bot options")
 irc.nickName = "SenShi"
 irc.userName = "SenShi"
 irc.realname = "SenShi"
 irc.channels = @["#SenShi","#Senketsu"]
 irc.network = "irc.stormbit.net"
 irc.port = 6667
 irc.servPass = ""
 irc.nickPass = ""
 irc.save(cfg)


proc setNew* (irc: var PIrc, cfg: string) =

 var
  buff: string = ""
 irc.servPass = ""
 irc.nickPass = ""
 irc.channels = @[]

 echoInfo("Set your irc bot config please:")
 echoInfo("* Network:\t(irc network to join)")
 irc.network = readLine(stdin)

 echoInfo("* Port:\t\t(irc networks port) [default: '6667']")
 let port = readLine(stdin)
 if port.isNumber:
  irc.port = parseInt(port)
 else:
  irc.port = 6667

 echoInfo("* Serv pass:\t(server password) [optional]")
 irc.servPass = readLine(stdin)

 echoInfo("* Nick:\t\t(your bots nick)")
 irc.nickName = readLine(stdin)

 echoInfo("* User name:\t(your bots user name) [optional]")
 buff = readLine(stdin)
 if buff != "":
  irc.userName = buff
 else:
  irc.userName = irc.nickName

 echoInfo("* Real name:\t(your bots real name) [optional]")
 buff = readLine(stdin)
 if buff != "":
  irc.realname = buff
 else:
  irc.realname = irc.nickName

 echoInfo("* Nick pass:\t(NickServ password) [optional]")
 irc.nickPass = readLine(stdin)

 echoInfo("* Channels:\t(channels to autojoin, space separated) [e.g:#SenShi]")
 buff = readLine(stdin)
 if buff != "":
  let spl = buff.split(' ')
  irc.channels = spl
 else:
  irc.channels = @["#SenShi"]

 echoInfo("Thank you ! All done. Saving and using new config file.")
 irc.save(cfg)

proc set* (irc: var PIrc, cfg: string) =
 echoInfo("No irc bot config file found:\n\t enter 'n' or 'new' to create new")
 echoInfo("\t enter 'd' or 'def' for hardcoded default\n")

 while true:
  let choice = readLine(stdin)
  case choice
  of "d", "default", "def":
   irc.loadDef(cfg)
   break
  of "n", "new":
   irc.setNew(cfg)
   break
  else:
   stdout.writeLine("Not a valid choice, try again (ganbatte~)")

proc load*(irc: var PIrc, cfg: string) =
 echoInfo("Irc Bot\t- Loading irc configuration file")
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
     of "nickName":
      irc.nickName = event.value
     of "userName":
      irc.userName = event.value
     of "realName":
      irc.realName = event.value
     of "channels":
      irc.channels = split(event.value,' ')
     of "network":
      irc.network = event.value
     of "port":
      irc.port = parseInt(event.value)
     of "servPass":
      irc.servPass = event.value
     of "nickPass":
      irc.nickPass = event.value
     else:
      discard
    of cfgOption:
     discard
    of cfgError:
     logEvent(true,"***Error IRC: $1" % [event.msg])
  close(cfgParser)
 else:
  logEvent(false,"**Warning: Cannot open $1. Creating default." % [cfg])
  irc.set(cfg)



proc ibHandle* (irc: PIrc,conn: DbConn,chanManager,chanBot: ptr StringChannel) =

 var
  isPrivate: bool

 case irc.data.cmd
 of MPrivMsg, MNotice:

  # We dont serve actions
  if irc.data.msg[0] == '\1' and irc.data.msg[1] == 'A':
   return

  # Check if its whisper
  if irc.data.target == irc.nickName:
   isPrivate = true

  # Take action
  if isPrivate and irc.data.msg.startsWith(".@"): # Its a admin command
   echo "CMD: $1" % irc.data.msg

  # Public commands, .q .random etc..
  elif irc.data.msg[0] == '.' or irc.data.msg[0] == '-' or irc.data.msg[0] == '@':
   irc.processCmd(conn, isPrivate, chanManager, chanBot)

  # Ignore everything else
  else:
   discard
 else:
  discard

proc handleChannelCmds (irc: PIrc, chanManager,chanBot: ptr StringChannel) =
 let chanTryBuff = chanBot[].tryRecv()
 if chanTryBuff.dataAvailable:
  var msg: string = chanTryBuff.msg
  if msg.startsWith("BC:"):  ## BC - broadcast (main channel)
   msg.delete(0,2)
   irc.msg(irc.channels[0],msg)
  elif msg.startsWith("RAW:"):  ## RAW - Send string directly
   msg.delete(0,3)
   irc.send(msg)
  elif msg.startsWith("ST:"): ## Set topic
   msg.delete(0,2)
   irc.topic(irc.channels[0],msg)
  else:
   logEvent(false,"**Warning Bot: unknown chan msg '$1'" % msg)

proc start* (irc: PIrc,paths: PPaths, chanManager,chanBot: ptr StringChannel) =
 echoInfo("Irc Bot\t- Setup complete .. starting")
 var
  conn: DbConn
  connCfg: ManDbCfg
 connCfg.load(paths.cfg.manDb)
 sleep(500)
 if not conn.connectToMysql(connCfg):
  echoInfo("An error has occured, please try restarting SenShi")
  chanManager[].send("cmd_quit")
 #TODO: Check why mysql connection fails sometimes
 while true:
  if irc.connect():
   logEvent(false,"*Notice IRC Bot: Connected to: $1:$2" % [irc.network, $irc.port])
  while irc.handleData() == 0:
   if not irc.isTimeout:
    irc.handleEvent()
    if irc.isReady:
     irc.ibHandle(conn, chanManager, chanBot)
   if irc.isReady:
    irc.handleChannelCmds(chanManager, chanBot)

  logEvent(false,"*Notice IRC Bot: Trying to reconnect in 5 seconds..")
  sleep(5000)
  continue
