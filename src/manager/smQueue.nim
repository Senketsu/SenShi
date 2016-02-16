import strutils, times
import projectTypes, projectEvents
import ndbex/db_mysql_ex
import smUtils

type
 QueueItem* = tuple
  iLen: int
  path,meta,lp,id: string

 QueueItemNew* = tuple
  iLen: int
  trackID,meta,path: string


proc clear* (track: var QueueItem) =
 track.path = ""
 track.meta = ""
 track.lp = ""
 track.id = ""
 track.iLen = 0

proc clear* (track: var QueueItemNew) =
 track.path = ""
 track.meta = ""
 track.trackID = ""
 track.iLen = 0


proc updateQueueTimes* (conn: DbConn) =
 try:
  var sumLen: int = 0
  let queueItems = conn.getAllRowsNew(sql("""SELECT id FROM queue ORDER BY id ASC"""))
  for item in queueItems:
   let queueLen = conn.getValueNew(sql("""SELECT SUM(length) AS sumlen from
    queue where id < ?"""),item.data[0])
   if queueLen.hasData:
    sumLen = parseInt(queueLen.data)

   conn.exec(sql("""UPDATE queue SET time = TIMESTAMPADD(SECOND, ?,
    CURRENT_TIMESTAMP) WHERE id = ?"""),sumLen, item.data[0])

 except:
  logEvent(true,"***Error Msg: @manUpdateQueueTimes '$1'" % getCurrentExceptionMsg())


proc getTrackFromQueue* (track: var QueueItem, conn: DbConn): bool =
 var
  rowNew: RowNew
 track.clear()
 try:
  rowNew = conn.getRowNew(sql("""SELECT a.*, b.path, b.lastplayed FROM queue a,
   tracks b WHERE a.trackid = b.id ORDER BY a.id ASC LIMIT 1"""))
  if rowNew.hasData:
   track.id = rowNew.data[0]
   track.meta = rowNew.data[2]
   track.iLen = parseInt(rowNew.data[3])
   track.path = rowNew.data[5]
   track.lp = rowNew.data[6]
   result = true
   if not conn.tryExec(sql("""DELETE FROM queue ORDER BY ID ASC LIMIT 1""")):
    logEvent(true,"***Error: Failed to remove item from queue")
  else:
   result = false
 except:
  logEvent(true,"***Error: @getTrackFromQueue '$1'" % getCurrentExceptionMsg())

proc addToQueue* (conn: DbConn, track: QueueItemNew,
                         iTrackRem: int,chanIrcBot: ptr StringChannel): bool =
 result = false
 var
  iQueueLen: int = 0
  iNewTrackWhen: int = 0
  queueLen: TGetVal
  reply: string = "BC:Requested: "

 try:
  queueLen = conn.getValueNew(sql("""SELECT SUM(length) AS sumlen from queue"""))

  if not queueLen.hasData:
   iQueueLen = 0
  else:
   iQueueLen = parseInt(queueLen.data)

  iNewTrackWhen = iQueueLen + iTrackRem

  if conn.tryExec(sql("""INSERT INTO queue (trackid, time, meta, length)
    VALUES (?, TIMESTAMPADD(SECOND, ?, CURRENT_TIMESTAMP() ), ?, ?)"""),
    track.trackID, iNewTrackWhen, track.meta, track.iLen):

   conn.exec(sql("""UPDATE tracks SET usable = 0 , lastrequested =
    CURRENT_TIMESTAMP WHERE id = ? LIMIT 1"""),track.trackID)
   result = true
   reply.add('\x03')
   reply.add("03'$1'" % [track.meta])
   reply.add('\x03')
   reply.add("15 $1" % [lenIntToStrQueue(iNewTrackWhen)])
   chanIrcBot[].send(reply)
 except:
  logEvent(true,"***Error: @addToQueue '$1'" % getCurrentExceptionMsg())

proc addToQueue_Silent* (conn: DbConn, track: QueueItemNew, iTrackRem: int): bool =
 result = false
 var
  iQueueLen: int = 0
  iNewTrackWhen: int = 0
  queueLen: TGetVal

 try:
  queueLen = conn.getValueNew(sql("""SELECT SUM(length) AS sumlen from queue"""))

  if not queueLen.hasData:
   iQueueLen = 0
  else:
   iQueueLen = parseInt(queueLen.data)

  iNewTrackWhen = iQueueLen + iTrackRem

  if conn.tryExec(sql("""INSERT INTO queue (trackid, time, meta, length)
    VALUES (?, TIMESTAMPADD(SECOND, ?, CURRENT_TIMESTAMP() ), ?, ?)"""),
    track.trackID, iNewTrackWhen, track.meta, track.iLen):

   conn.exec(sql("""UPDATE tracks SET usable = 0 WHERE id = ? LIMIT 1"""),track.trackID)
   result = true
 except:
  logEvent(true,"***Error: @addToQueue_Silent '$1'" % getCurrentExceptionMsg())

