import os, strutils, parsecfg , streams
import ndbex/db_mysql_ex
import smStatus, smTopic, smQueue, smOther, smRequests, smUtils
import icestat/isMain
import projectEvents, projectTypes
export ManTopic,StreamStatus,QueueItem,QueueItemNew

type
 ManDbCfg* = tuple
  address,user,pass,dbName: string

 StreamManager* = object
  conn*: DbConn
  connCfg*: ManDbCfg
  status*: StreamStatus
  topic*: ManTopic
  trackCurr,trackLast,trackNext: QueueItem
  trackNew: QueueItemNew
  playsStats: PlaysStats
  echoTrackInfo*: bool

proc clear* (stats: var PlaysStats) =
 stats.iPlays = ""
 stats.iLen = ""
 stats.lp = ""
 stats.id = ""
 stats.meta = ""

proc setDefault* (stats: var PlaysStats, meta: string) =
 stats.iPlays = "0"
 stats.iLen = "0"
 stats.lp = "0000-00-00 00:00:00"
 stats.id = "0"
 stats.meta = meta

proc connectToMysql* (man: var StreamManager): bool =
 try:
  man.conn = open(man.connCfg.address, man.connCfg.user, man.connCfg.pass, man.connCfg.dbName)
  if man.conn.setEncoding("utf8") == false:
   logEvent(true,"***Error Manager: Failed to set DB connection encoding")
  result = true
 except:
  logEvent(true,"***Error: @connectToMysql '$1'" % getCurrentExceptionMsg())

proc save* (dbInfo: var ManDbCfg, cfg: string) =
 var
  cfgFile: File

 if cfgFile.open(cfg ,fmWrite):
    cfgFile.writeLine("address=\"$1\"" % [dbInfo.address])
    cfgFile.writeLine("user=\"$1\"" % [dbInfo.user])
    cfgFile.writeLine("pass=\"$1\"" % [dbInfo.pass])
    cfgFile.writeLine("dbName=\"$1\"" % [dbInfo.dbName])
    cfgFile.flushFile()
    cfgFile.close()
 else:
  logEvent(true,"***Error Conf: Couldn't create file '$1'" % [cfg])
  discard

proc loadDef* (dbInfo: var ManDbCfg, cfg: string) =
 echoInfo("Manager\t- Setting default radio DB info")
 dbInfo.address = "localhost"
 dbInfo.user = "root"
 dbInfo.pass = "changeme"
 dbInfo.dbName = "radio"
 dbInfo.save(cfg)

proc setNew* (dbInfo: var ManDbCfg, cfg: string) =
 echoInfo("Set your database config please:")

 echoInfo("* Address:\t(Your mysql address and port) [e.g:'127.0.0.1:3306']")
 dbInfo.address = readLine(stdin)

 echoInfo("* User:\t\t(your mysql username)")
 dbInfo.user = readLine(stdin)

 echoInfo("* Pass:\t\t(your mysql password)")
 dbInfo.pass = readLine(stdin)

 echoInfo("* DB Name:\t(your database name)")
 dbInfo.dbName = readLine(stdin)
 echoInfo("Thank you ! All done. Saving and using new config file.")
 dbInfo.save(cfg)

proc set* (dbInfo: var ManDbCfg, cfg: string) =
 echoInfo("No database config file found:\n\t enter 'n' or 'new' to create new")
 echoInfo("\t enter 'd' or 'def' for hardcoded (vagrant) default\n")

 while true:
  let choice = readLine(stdin)
  case choice
  of "d", "default", "def":
   dbInfo.loadDef(cfg)
   break
  of "n", "new":
   dbInfo.setNew(cfg)
   break
  else:
   stdout.writeLine("Not a valid choice, try again (ganbatte~)")

proc load* (dbInfo: var ManDbCfg, cfg: string) =
 echoInfo("Manager\t- Loading radio DB configuration file")
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
  logEvent(false,"**Warning: Cannot open $1. Creating default." % [cfg])
  dbInfo.loadDef(cfg)



proc announceNowStarting* (conn: DbConn, item: QueueItem, status: StreamStatus,
                            stats: PlaysStats, chanIrcBot: ptr StringChannel) =
 var
  songLP,songLen: string = ""
  iFaves: int = 0
  reply: string = ""

 songLP = getLastPlayedStr(item.lp)
 songLen = lenIntToStr(item.iLen)
 iFaves = conn.getTrackFavesCount(status.np)

 reply.add("BC:Now starting: ")
 reply.add('\x03')
 reply.add("04'$1' " % status.np)
 reply.add('\x03')
 reply.add("[$1] " % songLen)
 reply.add("($1), $2, played $3 " % [
   if status.iList == "1": "1 listener" else: (status.iList & " listeners"),
   if iFaves == 1: "1 fave" else: ($iFaves & " faves"),
   if stats.iPlays == "1": "1 time" else: (stats.iPlays & " times")])
 reply.add('\x03')
 reply.add("03LP:")
 reply.add('\x03')
 reply.add(" $1" % songLP)
 chanIrcBot[].send(reply)

proc announceNowStarting_DJ* (conn: DbConn, status: StreamStatus,
                          stats: PlaysStats, chanIrcBot: ptr StringChannel) =
 var
  songLP,songLen,reply: string = ""
  iFaves: int = 0

 songLP = getLastPlayedStr(stats.lp)
 iFaves = conn.getTrackFavesCount(stats.meta)

 if stats.iLen == "0":
  songLen = "~"
 else:
  songLen = lenIntToStr(parseInt(stats.iLen))

 reply.add("BC:Now starting: ")
 reply.add('\x03')
 reply.add("04'$1' " % stats.meta)
 reply.add('\x03')
 reply.add("[$1] " % songLen)
 reply.add("($1), $2, played $3 " % [
   if status.iList == "1": "1 listener" else: (status.iList & " listeners"),
   if iFaves == 1: "1 fave" else: ($iFaves & " faves"),
   if stats.iPlays == "1": "1 time" else: (stats.iPlays & " times")])
 reply.add('\x03')
 reply.add("03LP:")
 reply.add('\x03')
 reply.add(" $1" % songLP)
 chanIrcBot[].send(reply)

proc parseUserQuery(splitCMD: seq[string]): UserQuery =
 result.user = ""
 result.query = ""
 for i in 0..splitCMD.high:
  if i == 1: result.user = splitCMD[i]
  if i > 1:
   result.query.add(splitCMD[i])
   result.query.add(" ")
 result.query.delete(result.query.len,result.query.len)



proc start* (man: var StreamManager, paths: PPaths,
              chanManager, chanStreamer,chanBot,chanStat: ptr StringChannel) =
 echoInfo("Manager\t- Setup complete .. starting")

 ## Cause we like clean stuff (except my room)
 man.status.clear()
 man.status.load(man.conn)
 man.trackCurr.clear()
 man.trackLast.clear()
 man.trackNext.clear()
 man.trackNew.clear()
 man.playsStats.clear()
 man.topic.format.load(paths.cfg.manTopic)

 var
  chanBuffer: string = ""
  splitCMD: seq[string]
  parData: UserQuery

 # 1st Update Queue times after start/restart
 man.conn.updateQueueTimes()
 ## In stream status we believe, its never wrong (hopefuly)
 if not man.status.isAfkStream and man.status.isStreamDesk:
  if man.status.djname != man.conn.getDjNameByTag("AFK_DJ"):
   chanStat[].send("cmd_start")

 while true: ## Endless loops are fun
  chanBuffer = chanManager[].recv()
  splitCMD = chanBuffer.split(" ")
  parData = splitCMD.parseUserQuery()

  case splitCMD[0]
  of "sb_new":
   if man.trackNext.getTrackFromQueue(man.conn):
    chanStreamer[].send("cmd_stream_file $1" % [man.trackNext.path])
   else: ## SenShi picks random track to play if queue is empty. [dont like autofill]
    man.trackNew.cmd_RandomBot(man.conn, man.status)

    if man.trackNext.getTrackFromQueue(man.conn):
     chanStreamer[].send("cmd_stream_file $1" % [man.trackNext.path])

   ## Seems pointless right ? WRONG ! Only wise old man will comprehend this
   if man.trackCurr.id != "0" and man.status.isAfkStream:
    man.conn.updateTracksLastPlayed(man.trackCurr.id)
   if man.trackCurr.meta != "":
    man.conn.addToLastPlayed(man.trackCurr.meta, man.trackCurr.id)
    man.conn.updatePlaysStats(man.trackCurr)

   man.trackLast = man.trackCurr
   man.trackCurr = man.trackNext
   # Update status
   man.status.update(man.trackCurr, paths.fpIceOut)
   man.status.pushToDb(man.conn)
   # Prepare data for .np/ns
   man.playsStats.clear()
   if not man.playsStats.getPlaysStats(man.conn, man.status.np):
    discard man.conn.addPlaysStats(man.status.np)
    man.playsStats.setDefault(man.status.np)
    # man.playsStats.getPlaysStats(man.conn, man.status.np)

   # Just for fancy
   if man.echoTrackInfo:
    let sLen: string = lenIntToStr(man.trackCurr.iLen)
    echo "\27[0;35m$1\27[0m \27[0;36m$2\27[0m | $3" % ["[Track]:", man.status.np,sLen]
    echo "\t\tLP: " & getLastPlayedStr(man.trackCurr.lp)

   # Announce NS & Notify for faves
   man.conn.announceNowStarting(man.trackCurr,man.status,man.playsStats,chanBot)
   man.conn.notifyFaveStarting(man.playsStats, chanBot)

  of "icestat_new":
   if not man.status.isAfkStream and man.status.isStreamDesk:
    man.conn.updatePlaysStats_DJ(man.status.start_time, man.status.np)
    man.status.update(paths.fpIceOut) ## TODO: Grab known plays track lenght if possible
    if man.playsStats.meta != "":
     man.conn.addToLastPlayed(man.playsStats.meta, man.playsStats.id)
    man.playsStats.clear()
    if not man.playsStats.getPlaysStats(man.conn, man.status.np):
     discard man.conn.addPlaysStats(man.status.np)
     discard man.playsStats.getPlaysStats(man.conn, man.status.np)

    man.status.trackid = man.playsStats.trackid
    try: # push estimate end time from plays track lenght if any
     if man.playsStats.iLen != "0":
      man.status.end_time = (parseInt(man.status.start_time) + parseInt(man.playsStats.iLen))
     else :
      man.status.end_time = 0;
    except: discard
    man.status.pushToDb(man.conn)

    man.trackLast = man.trackCurr
    man.trackCurr.clear()
    man.trackCurr.fillWithPlaysStats(man.playsStats)
    # Announce NS & Notify for faves
    man.conn.announceNowStarting_DJ(man.status, man.playsStats,chanBot)
    man.conn.notifyFaveStarting(man.playsStats, chanBot)
    # Just for fancy
    if man.echoTrackInfo:
     let sLen: string = lenIntToStr(man.trackCurr.iLen)
     echo "\27[0;35m$1\27[0m \27[0;36m$2\27[0m | $3" % ["[Track DJ]:", man.status.np,sLen]
     echo "\t\tLP: " & getLastPlayedStr(man.trackCurr.lp)


  of "sb_meta":
   chanStreamer[].send("cmd_stream_meta $1" % [man.trackCurr.meta])

  of "bot_np":
   if not man.status.isAfkStream and not man.status.isStreamDesk:
    chanBot[].send("BC:Stream is currently down.")
   elif man.status.isAfkStream:
    man.conn.cmd_NowPlaying(man.trackCurr,man.status,man.playsStats,paths.fpIceOut,chanBot)
   else:
    man.conn.cmd_NowPlaying_Dj(man.status,man.playsStats,paths.fpIceOut,chanBot)

  of "bot_queue":
   man.conn.cmd_Queue(chanBot)

  of "bot_queue_len":
   man.conn.cmd_QueueLen(chanBot)

  of "bot_random":
   man.conn.cmd_Random(man.trackNew, man.status, parData.user, chanBot)

  of "bot_random_fave":
   man.conn.cmd_RandomFave(man.trackNew, man.status, parData.user, chanBot)

  of "bot_lucky":
   man.conn.cmd_Lucky(man.trackNew, man.status, parData.user, parData.query, chanBot)

  of "bot_request":
   man.conn.cmd_Request(man.trackNew, man.status, parData.user, parData.query, chanBot)

  of "bot_fave":
   man.conn.cmd_Fave(man.trackCurr, parData.user, chanBot)

  of "bot_unfave":
   man.conn.cmd_UnFave(man.trackCurr, parData.user, chanBot)

  of "bot_fave_last":
   man.conn.cmd_Fave(man.trackLast, parData.user, chanBot)

  of "bot_unfave_last":
   man.conn.cmd_UnFave(man.trackLast, parData.user, chanBot)

  of "bot_fave_notify":
   man.conn.cmd_FaveNotify(parData.user, parData.query, chanBot)

  of "bot_tags":
   man.conn.cmd_Tags(man.trackCurr.id, man.trackLast.id, parData.user, parData.query, chanBot)

  of "bot_tags_bc":
   man.conn.cmd_Tags(man.trackCurr.id, man.trackLast.id, "", parData.query, chanBot)

  of "bot_info":
   man.conn.cmd_Info(man.trackCurr.id, man.trackLast.id, parData.user, parData.query, chanBot)

  of "bot_info_bc":
   man.conn.cmd_Info(man.trackCurr.id, man.trackLast.id, "", parData.query, chanBot)

  of "bot_search":
   man.conn.cmd_Search(parData.user, parData.query, chanBot)

  of "bot_search_bc":
   man.conn.cmd_Search("", parData.query, chanBot)

  of "bot_skip": ## TODO: Remove ? :^)
   chanStreamer[].send("cmd_skip")

  of "bot_thread":
   man.conn.cmd_Thread(man.status, parData.user, parData.query, chanBot)

  of "bot_topic":
   man.topic.update(man.status)
   man.topic.full.cmd_Topic(parData.user, chanBot)

  of "bot_set_topic":
   man.topic.update(man.status, parData.query)
   chanBot[].send("ST:$1" % man.topic.full)

  of "bot_edit_topic_f":
   if man.topic.format.editFormat(parData.user, parData.query):
    man.topic.format.save(paths.cfg.manTopic)
    man.topic.update(man.status)
    chanBot[].send("ST:$1" % man.topic.full)

  of "sb_kill_confirm": ## We update lp after kill completed
   if man.trackCurr.id != "0" and man.status.isAfkStream:
    man.conn.updateTracksLastPlayed(man.trackCurr.id)
   if man.trackCurr.meta != "":
    man.conn.addToLastPlayed(man.trackCurr.meta, man.trackCurr.id)
    man.conn.updatePlaysStats(man.trackCurr)

   man.trackLast = man.trackCurr
   man.status.isAfkStream = false
   man.status.requesting = false
   man.status.pushToDb(man.conn)
   chanStat[].send("cmd_start")

  of "sb_conn_confirm":
   man.status.isAfkStream = true
   man.status.isStreamDesk = false
   man.status.requesting = true
   man.status.pushToDb(man.conn)
   chanStat[].send("cmd_stop")

  of "sb_conn_occupied":
   man.status.isAfkStream = false
   man.status.isStreamDesk = true
   man.status.requesting = false
   man.status.pushToDb(man.conn)
   chanStat[].send("cmd_start")

  of "sb_get_status":
   chanStreamer[].send("stream_status $1 $2" % [
    if man.status.isAfkStream: "true" else: "false",
    if man.status.isStreamDesk: "true" else: "false"])

  of "bot_kill":
   chanStreamer[].send("cmd_kill")

  of "bot_kill_force":
   chanStreamer[].send("cmd_kill_f")

  of "bot_dj":
   if not man.status.isAfkStream and not man.status.isStreamDesk:
    chanBot[].send("BC:Stream is currently down.")
   else:
    chanBot[].send("BC:Current DJ: '$1'" % [man.status.djname])

  of "bot_dj_set":
   if parData.user == "AFK_DJ":
    man.status.djname = man.conn.getDjNameByTag(parData.user)
    man.status.djid = man.conn.getDjId(man.status.djname)
   else:
    man.status.djname = parData.user
    man.status.djid = man.conn.getDjId(parData.user)
   if man.conn.isAfkDj(man.status.djid):
    chanStreamer[].send("cmd_start")
    man.conn.updateQueueTimes()
    man.trackCurr.clear()  ## Now it makes sense eh ? (ref to sb_new 'if' condition comment)
   else:
    man.status.isStreamDesk = true;
   man.status.pushToDb(man.conn)

  of "cmd_quit":
   chanStreamer[].send("cmd_quit")
   chanStat[].send("cmd_quit")
   quit(QuitSuccess)
  else:
   logEvent(true,"***Error Manager: Unknow request: '$1'" % [chanBuffer])

  chanBuffer = ""
