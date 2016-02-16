import strutils, times
import ndbex/db_mysql_ex
import smUtils, smQueue
import projectEvents, projectTypes

const COOL_DOWN = 432000 #(5days)

proc fillWithPlaysStats* (track: var QueueItem, stats: PlaysStats) =
 track.meta = stats.meta
 track.lp = stats.lp
 track.id = stats.trackid
 track.iLen = parseInt(stats.iLen)

proc updateTracksLastPlayed* (conn: DbConn, trackid: string) =
 try:
   conn.exec(sql("""UPDATE tracks SET lastplayed=NOW() WHERE id = ? LIMIT 1"""),trackid)
 except:
  logEvent(true,"***Error: @updateTracksLp '$1'" % getCurrentExceptionMsg())

proc addToLastPlayed* (conn: DbConn, meta, trackid: string) =
 try:
  conn.exec(sql("""INSERT into lastplayed (trackid,song) VALUES (?, ?)"""),trackid, meta)
 except:
  logEvent(true,"***Error: @updateLastPlayed'$1'" % getCurrentExceptionMsg())

proc getDjId* (conn: DbConn, djname: string): string =
 result = ""
 try:
  let val = conn.getValueNew(sql("""SELECT id FROM djs WHERE djname=?"""),djname)
  if val.hasData:
   result = val.data
 except:
  logEvent(true,"***Error: @getDjId '$1'" % getCurrentExceptionMsg())

proc getDjIdByTag* (conn: DbConn, djname: string): string =
 result = ""
 try:
  let val = conn.getValueNew(sql("""SELECT id FROM djs WHERE tags=?"""),djname)
  if val.hasData:
   result = val.data
 except:
  logEvent(true,"***Error: @getDjId '$1'" % getCurrentExceptionMsg())


proc getDjNameById* (conn: DbConn, id: string): string =
 result = ""
 try:
  let val = conn.getValueNew(sql("""SELECT djname FROM djs WHERE id=?"""),id)
  if val.hasData:
   result = val.data
 except:
  logEvent(true,"***Error: @getDjName '$1'" % getCurrentExceptionMsg())

proc getDjNameByTag* (conn: DbConn, tag: string): string =
 result = ""
 try:
  let val = conn.getValueNew(sql("""SELECT djname FROM djs WHERE tags=?"""),tag)
  if val.hasData:
   result = val.data
 except:
  logEvent(true,"***Error: @getDjName '$1'" % getCurrentExceptionMsg())

proc isAfkDj* (conn: DbConn, id: string): bool =
 result = false
 try:
  let val = conn.getValueNew(sql("""SELECT tags FROM djs WHERE id=?"""),id)
  if val.hasData:
   if val.data.contains("AFK_DJ"):
    result = true
 except:
  logEvent(true,"***Error: @isAfkDj '$1'" % getCurrentExceptionMsg())


proc getQueueLenStr* (conn: DbConn): string =
 result = ""
 var
  iQueueLen: int = 0
  queueLen: TGetVal
 try:
  queueLen = conn.getValueNew(sql("""select SUM(length) AS sumlen from queue"""))

  if not queueLen.hasData:
   iQueueLen = 0
  else:
   iQueueLen = parseInt(queueLen.data)

 except:
  logEvent(true,"***Error: @getQueueLenStr '$1'" % getCurrentExceptionMsg())
 result = lenIntToStrQueue(iQueueLen)

proc getTrackUsableFromTS* (lastplayed: string): bool =
 ## Return false on below two 'if' to prevend repetitive requests before song plays
 if lastplayed == "0000-00-00 00:00:00": return false
 if lastplayed == "" or lastplayed == nil: return false
 let parTimeInfo = times.parse(lastplayed,"yyyy-MM-dd HH:mm:ss")
 let lpTime = timeInfoToTime(parTimeInfo)
 let timeNow = getTime()
 let timeDiff = (int)(timeNow - lpTime)
 if timeDiff > COOL_DOWN:
  result = true

proc getTrackUsable* (conn: DbConn, query: string): bool =
 result = false
 var
  resRow: RowNew

 try:
  if query.isNumber():
   resRow = conn.getRowNew(sql("""SELECT usable,lastplayed FROM tracks WHERE
    id=? LIMIT 1"""), query)
  else:
   let newQuery = "%%$1%%" % query
   resRow = conn.getRowNew(sql("""SELECT usable,lastplayed FROM tracks WHERE
    tags like ? LIMIT 1"""), newQuery)
 except:
  logEvent(true,"***Error: @getTrackUsable '$1'" % getCurrentExceptionMsg())

 if resRow.hasData:
  if resRow.data[0] == "1":
   result = true
  else:
   result = getTrackUsableFromTS(resRow.data[1])

proc getTrackFavesCount* (conn: DbConn, meta: string): int =
 result = 0
 try:
  let res = conn.getValueNew(sql("""SELECT COUNT(*) FROM faves WHERE playsid IN
   (SELECT id from plays WHERE meta=?)"""),meta)
  if res.hasData:
   result = parseInt(res.data)
 except:
  logEvent(true,"***Error: @getFavesCount '$1'" % getCurrentExceptionMsg())

proc notifyFaveStarting* (conn: DbConn, stats: PlaysStats, chanBot: ptr StringChannel) =
 try:
  let rows = conn.getAllRowsNew(sql("""SELECT a.user FROM users a,faves b WHERE
   a.id = b.userid AND a.fave_notify=1 AND b.playsid = ?"""),stats.id)

  for row in rows:
   if row.hasData:
    let msg = "RAW:NOTICE $1 :Fave: '$2' is playing." % [row.data[0],stats.meta]
    chanBot[].send(msg)
 except:
  logEvent(true,"***Error: @notifyFaveStarting '$1'" % getCurrentExceptionMsg())

proc addPlaysStats* (conn: DbConn, trackMeta: string): bool =
 try:
  if conn.tryExec(sql("""INSERT INTO plays (meta) VALUES (?)"""),trackMeta):
   result = true
 except:
  logEvent(true,"***Error: @addPlaysStats '$1'" % getCurrentExceptionMsg())

proc getPlaysStats* (stats: var PlaysStats, conn: DbConn, meta: string): bool =
 try:
  let res = conn.getRowNew(sql("""SELECT * FROM plays WHERE meta=?"""), meta)
  if res.hasData:
   stats.id = res.data[0]
   stats.trackid = res.data[1]
   stats.meta = res.data[2]
   stats.iPlays = res.data[3]
   stats.iLen = res.data[4]
   stats.lp = res.data[5]
   result = true
 except:
  logEvent(true,"***Error: @getPlaysStats '$1'" % getCurrentExceptionMsg())

proc getPlaysStatsPlays* (conn: DbConn, meta: string): int =
 result = 0
 try:
  let res = conn.getValueNew(sql("""SELECT iPlays FROM plays WHERE meta=?"""), meta)
  if res.hasData:
   result = parseInt(res.data)
 except:
  logEvent(true,"***Error: @getPlaysStatsPlays '$1'" % getCurrentExceptionMsg())

proc getPlaysStatsLen* (conn: DbConn, meta: string): int =
 result = 0
 try:
  let res = conn.getValueNew(sql("""SELECT iLen FROM plays WHERE meta=?"""), meta)
  if res.hasData:
   result = parseInt(res.data)
 except:
  logEvent(true,"***Error: @getPlaysStatsLen '$1'" % getCurrentExceptionMsg())

proc updatePlaysStats_DJ* (conn: DbConn, startTime,meta: string) =

 try:
  conn.exec(sql("""UPDATE plays SET iPlays=iPlays+1, iLen=(UNIX_TIMESTAMP()-?)
   WHERE meta=?"""),startTime, meta)
 except:
  logEvent(true,"***Error: @updatePlaysStats_DJ '$1'" % getCurrentExceptionMsg())

proc updatePlaysStats* (conn: DbConn, track: QueueItem) =
 try:
  conn.exec(sql("""UPDATE plays SET iPlays=iPlays+1, iLen=?,trackid=?
   WHERE meta=?"""),track.iLen, track.id ,track.meta)
 except:
  logEvent(true,"***Error: @updatePlaysStats '$1'" % getCurrentExceptionMsg())

