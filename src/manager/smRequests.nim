import strutils, ndbex/db_mysql_ex
import smQueue, smTopic, smUtils, smStatus, smOther
import ../icestat/isMain
import projectEvents, projectTypes


proc cmd_RandomBot* (item: var QueueItemNew, conn: DbConn, status: StreamStatus) =
 try:
  var
   row: RowNew
  item.clear()
  row = conn.getRowNew(sql("""SELECT id, path, lenght, artist, track FROM tracks
   WHERE usable = 1 ORDER BY RAND() LIMIT 1"""))
  if row.hasData:
   item.trackid = row.data[0]
   item.path = row.data[1]
   item.iLen = parseInt(row.data[2])
   item.meta = row.data[3] & " - " & row.data[4]
   var timeRem: int = getTimeRemInt(status.end_time)
   if not conn.addToQueue_Silent(item, timeRem):
    logEvent(true,"***Error Manager: Failed to add item to queue - $1" % repr(item))
 except:
  logEvent(true,"***Error Msg: $1" % getCurrentExceptionMsg())

proc cmd_Random* (conn: DbConn,item: var QueueItemNew, status: StreamStatus,
                       user: string, chanIrcBot: ptr StringChannel) =
 if not status.isAfkStream:
  return
 var
  row: RowNew
 item.clear()
 try:
  row = conn.getRowNew(sql("""SELECT id, path, lenght, artist, track FROM tracks
   WHERE usable = 1 ORDER BY RAND() LIMIT 0,1"""))
  if row.hasData:
   item.trackid = row.data[0]
   item.path = row.data[1]
   item.iLen = parseInt(row.data[2])
   item.meta = row.data[3] & " - " & row.data[4]
   var timeRem: int = getTimeRemInt(status.end_time)
   if not conn.addToQueue(item, timeRem, chanIrcBot):
    chanIrcBot[].send("BC: Oooops..something broke ..")
   else:
    conn.exec(sql("""UPDATE users SET last_request = CURRENT_TIMESTAMP()
                 WHERE user = ?"""), user)
 except:
  logEvent(true,"***Error: @cmd_Random '$1'" % getCurrentExceptionMsg())

# Not elegant
proc cmd_RandomFave* (conn: DbConn,item: var QueueItemNew, status: StreamStatus,
                           user: string, chanIrcBot: ptr StringChannel) =
 if not status.isAfkStream:
  return
 var
  rowTracks: RowNew
  rowsFaves: seq[RowNew]
 item.clear()
 try:
   rowsFaves = conn.getAllRowsNew(sql("""SELECT playsid from faves where userid IN
    (SELECT id from users where user=?) ORDER BY id"""),user)
   for row in rowsFaves:
    if row.hasData:
     rowTracks = conn.getRowNew(sql("""SELECT id, path, lenght, artist, track
      FROM tracks WHERE id IN (SELECT trackid FROM plays where id = ?)
      AND usable=1 LIMIT 0,1"""),row.data)
     if rowTracks.hasData:
      item.trackid = rowTracks.data[0]
      item.path = rowTracks.data[1]
      item.iLen = parseInt(row.data[2])
      item.meta = row.data[3] & " - " & row.data[4]
      var timeRem: int = getTimeRemInt(status.end_time)
      if not conn.addToQueue(item, timeRem, chanIrcBot):
       chanIrcBot[].send("BC: Oooops..something broke ..")
      else:
       conn.exec(sql("""UPDATE users SET last_request = CURRENT_TIMESTAMP()
                 WHERE user = ?"""), user)
      return

   chanIrcBot[].send("RAW:NOTICE $1 :No faves available to request." % user)
 except:
   logEvent(true,"***Error: @cmd_RandomFave '$1'" % getCurrentExceptionMsg())

proc cmd_Lucky* (conn: DbConn,item: var QueueItemNew, status: StreamStatus,
                   user: string, query: string, chanIrcBot: ptr StringChannel) =
 if not status.isAfkStream:
  return
 var
  row: RowNew
  newQuery: string = "%%$1%%" % query
  newQuery2: string = "$1%%" % query
 item.clear()
 try:
  row = conn.getRowNew(sql("""SELECT id, path, lenght, artist, track
   FROM tracks WHERE usable = 1 AND tags like ? ORDER BY CASE WHEN
   artist = ? THEN 1 WHEN track LIKE ? THEN 2
   WHEN artist LIKE ? THEN 3 WHEN track LIKE ? THEN 4 ELSE 5 END,
   RAND() LIMIT 1"""), newQuery, query, newQuery2, newQuery, newQuery)

  if row.hasData:
   item.trackid = row.data[0]
   item.path = row.data[1]
   item.iLen = parseInt(row.data[2])
   item.meta = row.data[3] & " - " & row.data[4]
   var timeRem: int = getTimeRemInt(status.end_time)
   if not conn.addToQueue(item, timeRem, chanIrcBot):
    chanIrcBot[].send("BC: Oooops..something broke ..")
   else:
    conn.exec(sql("""UPDATE users SET last_request = CURRENT_TIMESTAMP()
                 WHERE user = ?"""), user)
  else:
   chanIrcBot[].send("BC:Your query didn't turn any results")
 except:
  logEvent(true,"***Error: @cmd_Lucky '$1'" % getCurrentExceptionMsg())

proc cmd_Request* (conn: DbConn, item: var QueueItemNew, status: StreamStatus,
                   user: string, query: string,chanIrcBot: ptr StringChannel)=
 if not status.isAfkStream:
  return
 var
  row: RowNew
 item.clear()
 try:
  if not conn.getTrackUsable(query):
   chanIrcBot[].send("BC:This song is on cooldown..")
   return

  if query.isNumber():
   row = conn.getRowNew(sql("""SELECT id, path, lenght, artist, track
     FROM tracks WHERE id = ? LIMIT 1"""), query)
  else:
   let newQuery = "%%$1%%" % query
   row = conn.getRowNew(sql("""SELECT  id, path, lenght, artist, track
     FROM tracks WHERE tags like ? ORDER BY RAND() LIMIT 1"""), newQuery)

  if row.hasData:
   item.trackid = row.data[0]
   item.path = row.data[1]
   item.iLen = parseInt(row.data[2])
   item.meta = row.data[3] & " - " & row.data[4]
   var timeRem: int = getTimeRemInt(status.end_time)
   if not conn.addToQueue(item, timeRem, chanIrcBot):
    chanIrcBot[].send("BC: Oooops..something broke ..")
   else:
    conn.exec(sql("""UPDATE users SET last_request = CURRENT_TIMESTAMP()
                 WHERE user = ?"""), user)
  else:
   chanIrcBot[].send("BC:Your query didn't turn any results")
 except:
  logEvent(true,"***Error: @cmd_Request '$1'" % getCurrentExceptionMsg())



proc cmd_Fave* (conn: DbConn, track: QueueItem,user: string,
                        chanIrcBot: ptr StringChannel) =
 var
  reply = "RAW:NOTICE $1 :Added " % user

 try:
  conn.exec(sql("""INSERT INTO faves (userid,playsid) SELECT id AS uid,
   (SELECT id FROM plays where meta=?) AS pid FROM users where user=?"""),
    track.meta, user)
  reply.add('\x03')
  reply.add("03'$1'" % track.meta)
  reply.add('\x03')
  reply.add(" to your favorites.")
  chanIrcBot[].send(reply)
 except:
  logEvent(true,"***Error: @cmd_Fave '$1'" % getCurrentExceptionMsg())


proc cmd_UnFave* (conn: DbConn, track: QueueItem,user: string,
                          chanIrcBot: ptr StringChannel) =
 var
  reply = "RAW:NOTICE $1 :Removed " % user

 try:
  conn.exec(sql("""DELETE FROM faves WHERE userid IN
   (SELECT id FROM users where user = ?) AND playsid IN (SELECT
    id FROM plays WHERE meta=?)"""),user, track.meta)
  reply.add('\x03')
  reply.add("03'$1'" % track.meta)
  reply.add('\x03')
  reply.add(" from your favorites.")
  chanIrcBot[].send(reply)
 except:
  logEvent(true,"***Error: @cmd_Fave '$1'" % getCurrentExceptionMsg())

proc cmd_FaveNotify* (conn: DbConn, user,query: string, chanIrcBot: ptr StringChannel) =

 var
  reply = "RAW:NOTICE $1 :" % user
  mode: int = 0
 try:
  case query
  of "on","true","1":
   mode = 1
  of "off","false","0":
   mode = 0
  else:
   mode = 2

  case mode
  of 0,1:
   if conn.tryExec(sql("""UPDATE users SET fave_notify = ? WHERE user = ?"""),mode,user):
    reply.add('\x03')
    reply.add("03Fave notify")
    reply.add('\x03')
    reply.add(": $1" % [if mode == 1: "on" else: "off"])
  else:
   let val = conn.getValueNew(sql("""SELECT fave_notify FROM users WHERE user = ?"""), user)
   if val.hasData:
    reply.add('\x03')
    reply.add("03Fave notify")
    reply.add('\x03')
    reply.add(": $1" % [if val.data == "1": "on" else: "off"])
  chanIrcBot[].send(reply)
 except:
  logEvent(true,"***Error: @cmd_FaveNotify '$1'" % getCurrentExceptionMsg())

proc getTrackIdFromQuery (idCurr, idLast, query: string): string =
 result = ""
 case query
 of "":
   result = idCurr
 of "last", "l":
   result = idLast
 else:
  if query.isNumber():
   result = query
  else: return

proc cmd_Tags* (conn: DbConn, trackID_curr, trackID_last: string,
                   user: string, query: string, chanIrcBot: ptr StringChannel) =
 var
  reply: string = ""
  val : TGetVal
  queryTrackId: string = getTrackIdFromQuery(trackID_curr, trackID_last, query)
 if queryTrackId == "":
  return

 if user == "":
  reply = "BC:"
 else:
  reply = "RAW:NOTICE $1 :" % user

 try:
  val = conn.getValueNew(sql("""SELECT tags FROM tracks WHERE id = ?"""),queryTrackId)
  if val.hasData:
   reply.add('\x03')
   reply.add("03Tags:")
   reply.add('\x03')
   reply.add(" '$1'" % [val.data])
   chanIrcBot[].send(reply)
  else:
   reply.add("There is no track with id '$1'" % queryTrackId)
   chanIrcBot[].send(reply)
 except:
  logEvent(true,"***Error: @cmd_Tags '$1'" % getCurrentExceptionMsg())


proc cmd_Info* (conn: DbConn, trackID_curr, trackID_last: string,
                   user: string, query: string, chanIrcBot: ptr StringChannel) =
 var
  reply: string = ""
  row: RowNew
  queryTrackId: string = getTrackIdFromQuery(trackID_curr, trackID_last, query)
 if queryTrackId == "":
  return

 if user == "":
  reply = "BC:"
 else:
  reply = "RAW:NOTICE $1 :" % user

 try:
  row = conn.getRowNew(sql("""SELECT artist,track,album,tags,lastplayed
   FROM tracks WHERE id = ?"""),queryTrackId)
  if row.hasData:
   reply.add("\x03" & "03Artist\x03: '$1' " % [if row.data[0].hasData(): row.data[0] else: ""])
   reply.add("\x03" & "03Title\x03: '$1' " % [if row.data[1].hasData(): row.data[1] else: ""])
   reply.add("\x03" & "03Album\x03: '$1' " % [if row.data[2].hasData(): row.data[2] else: ""])
   reply.add("\x03" & "03Tags\x03: '$1' " % [if row.data[3].hasData(): row.data[3] else: ""])
   reply.add("\x03" & "03LP\x03: '$1' " % [if row.data[4].hasData(): row.data[4] else: ""])
   chanIrcBot[].send(reply)
  else:
   reply.add("There is no track with id '$1'" % queryTrackId)
   chanIrcBot[].send(reply)
 except:
  logEvent(true,"***Error: @cmd_Info '$1'" % getCurrentExceptionMsg())

proc cmd_Search* (conn: DbConn, user: string, query: string,
                        chanIrcBot: ptr StringChannel) =
 var
  rowsInfo: seq[RowNew]
  reply: string = ""
  queryNew = "%%$1%%" % query
  gotData: bool

 if user == "":
  reply = "BC:"
 else:
  reply = "RAW:NOTICE $1 :" % user

 try:
  rowsInfo = conn.getAllRowsNew(sql("""SELECT usable,artist,track,id,lastplayed
   FROM tracks WHERE tags like ? ORDER BY RAND() LIMIT 5"""),queryNew)

  for row in rowsInfo:
   if row.hasData:
    gotData = true
    reply.add('\x03')
    if row.data[0] == "1":
     reply.add("03")
    else: # Recheck if its still unavailable based on timestamp
     if getTrackUsableFromTS(row.data[4]):
      conn.exec(sql("""UPDATE tracks SET usable = 1 WHERE id = ?"""),row.data[3])
      reply.add("03")
     else:
      reply.add("04")
    reply.add("$1 - " % [if row.data[1].hasData(): row.data[1] else: ""])
    reply.add("$1" % [if row.data[2].hasData(): row.data[2] else: ""])
    reply.add("\x03 ($1) | " % [if row.data[3].hasData(): row.data[3] else: ""])

  if gotData:
   reply.delete((reply.len-2),reply.len)
   chanIrcBot[].send(reply)
  else:
   reply.add("Your query didn't turn any results.")
   chanIrcBot[].send(reply)
 except:
  logEvent(true,"***Error: @cmd_Search '$1'" % getCurrentExceptionMsg())

proc cmd_Thread *(conn: DbConn,status: var StreamStatus, user: string,
                            query: string, chanIrcBot: ptr StringChannel) =
 var reply: string = ""
 if user == "":
  reply = "BC:"
 else:
  reply = "RAW:NOTICE $1 :" % user

 try:
  if query == "":
   reply.add('\x03')
   reply.add("03Thread: ")
   reply.add('\x03')
   reply.add(status.thread)
   chanIrcBot[].send(reply)
  else:
   conn.exec(sql("""UPDATE streamstatus SET thread = ? WHERE id = 0"""), query)
   status.thread = query
 except:
  logEvent(true,"***Error: @cmd_Thread '$1'" % getCurrentExceptionMsg())

proc cmd_Topic *(topic: string, user: string, chanIrcBot: ptr StringChannel) =
 var reply: string = ""
 if user == "":
  reply = "BC:"
 else:
  reply = "RAW:NOTICE $1 :" % user
 reply.add(topic)
 chanIrcBot[].send(reply)


proc cmd_QueueLen* (conn: DbConn, chanIrcBot: ptr StringChannel) =
 var
  reply = "BC:"
 try:
  reply.add('\x03')
  reply.add("10Queue length")
  reply.add('\x03')
  reply.add(": " & conn.getQueueLenStr())
  chanIrcBot[].send(reply)
 except:
  logEvent(true,"***Error: @cmd_QueueLen '$1'" % getCurrentExceptionMsg())

proc cmd_Queue* (conn: DbConn, chanIrcBot: ptr StringChannel) =
 var
  reply = "BC:"
  gotData: bool = false
  rowsNew: seq[RowNew]

 try:
  rowsNew = conn.getAllRowsNew(sql("""SELECT meta FROM queue ORDER BY id ASC LIMIT 5"""))

  reply.add('\x03')
  reply.add("10Queue $1: " % [conn.getQueueLenStr()])
  reply.add('\x03')
  for row in rowsNew:
   if row.hasData:
    gotData = true
    reply.add('\x03')
    reply.add("15" & row.data[0])
    reply.add('\x03')
    reply.add(" | ")
  if gotData:
   reply.delete(reply.len-2,reply.len)
  else:
   reply.add("empty")
  chanIrcBot[].send(reply)
 except:
  logEvent(true,"***Error: @cmd_Queue '$1'" % getCurrentExceptionMsg())


proc cmd_NowPlaying* (conn: DbConn,item: QueueItem, status: StreamStatus,
            stats: PlaysStats,iceOutPath:string, chanIrcBot: ptr StringChannel) =
 var
  songLP,songElap,songLen,reply: string = ""
  iFaves,iListen: int = 0

 songLP = getLastPlayedStr(item.lp)
 songElap = getTimeElapStr(status.start_time)
 songLen = lenIntToStr(item.iLen)
 iListen = (parseIceStats(iceOutPath).iList)
 iFaves = conn.getTrackFavesCount(status.np)

 reply.add("BC:Now playing: ")
 reply.add('\x03')
 reply.add("04'$1' " % status.np)
 reply.add('\x03')
 reply.add("[$1/$2] " % [songElap,songLen])
 reply.add("($1), $2, played $3 " % [
   if iListen == 1: "1 listener" else: ($iListen & " listeners"),
   if iFaves == 1: "1 fave" else: ($iFaves & " faves"),
   if stats.iPlays == "1": "1 time" else: (stats.iPlays & " times")])
 reply.add('\x03')
 reply.add("03LP:")
 reply.add('\x03')
 reply.add(" $1" % songLP)

 chanIrcBot[].send(reply)


proc cmd_NowPlaying_Dj* (conn: DbConn,status: StreamStatus,stats: PlaysStats,
                            iceOutPath:string ,chanIrcBot: ptr StringChannel) =
 var
  songLP,songElap,songLen,reply: string = ""
  iFaves,iListen: int = 0

 songLP = getLastPlayedStr(stats.lp)
 songElap = getTimeElapStr(status.start_time)
 iListen = (parseIceStats(iceOutPath).iList)
 iFaves = conn.getTrackFavesCount(status.np)

 if stats.iLen == "0":
  songLen = "~"
 else:
  songLen = lenIntToStr(parseInt(stats.iLen))

 reply.add("BC:Now playing: ")
 reply.add('\x03')
 reply.add("04'$1' " % status.np)
 reply.add('\x03')
 reply.add("[$1/$2] " % [songElap,songLen])
 reply.add("($1), $2, played $3 " % [
   if iListen == 1: "1 listener" else: ($iListen & " listeners"),
   if iFaves == 1: "1 fave" else: ($iFaves & " faves"),
   if stats.iPlays == "1": "1 time" else: (stats.iPlays & " times")])
 reply.add('\x03')
 reply.add("03LP:")
 reply.add('\x03')
 reply.add(" $1" % songLP)

 chanIrcBot[].send(reply)
