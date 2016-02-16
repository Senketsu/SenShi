import strutils, times
import ndbex/db_mysql_ex
import ../icestat/isMain
import smUtils
from smQueue import QueueItem,QueueItemNew
import projectEvents, projectTypes

type
 StreamStatus* = object
  id: string
  djid: string
  np: string
  iList: string
  bitrate: string
  isAfkStream: bool
  isStreamDesk: bool
  start_time: string
  end_time: string
  lastset: string
  trackid: string
  thread: string
  requesting: bool
  djname: string

proc clear* (status: var StreamStatus) =
 status.id = ""
 status.djid = ""
 status.np = ""
 status.iList = ""
 status.bitrate = ""
 status.isAfkStream = false
 status.isStreamDesk = false
 status.start_time = ""
 status.end_time = ""
 status.lastset = ""
 status.trackid = ""
 status.thread = ""
 status.requesting = false
 status.djname = ""


proc load* (status: var StreamStatus, conn: DbConn) =
 var
  radDbRow: RowNew

 try:
  radDbRow = conn.getRowNew(sql("""SELECT * FROM streamstatus where id = 0"""))
 except:
  logEvent(true,"***Error Msg: @managerLoadStatus $1" % getCurrentExceptionMsg())

 if radDbRow.hasData:
  status.id = radDbRow.data[0]
  status.djid = radDbRow.data[1]
  status.np = radDbRow.data[2]
  status.iList = radDbRow.data[3]
  status.bitrate = radDbRow.data[4]
  status.isAfkStream = (if radDbRow.data[5] == "0": false else: true)
  status.isStreamDesk = (if radDbRow.data[6] == "0": false else: true)
  status.start_time = radDbRow.data[7]
  status.end_time = radDbRow.data[8]
  status.lastset = radDbRow.data[9]
  status.trackid = radDbRow.data[10]
  status.thread = radDbRow.data[11]
  status.requesting = (if radDbRow.data[12] == "0": false else: true)
  status.djname = radDbRow.data[13]

 else:
  logEvent(true,"**Warning Manager: Failed to load stream status form DB")
  status.id = "0"
  status.djid = "0"
  status.np = "nothing - nothing"
  status.iList = "0"
  status.bitrate = "0"
  status.isAfkStream = false
  status.isStreamDesk = false
  status.start_time = "0"
  status.end_time = "0"
  status.lastset = "NULL"
  status.trackid = "0"
  status.thread = "none"
  status.requesting = false
  status.djname = "SenShi"

proc `id=`*(ss: var StreamStatus, value: string) {.inline.} =
 ss.id = "0" # Do not allow overwrite

proc id* (ss: StreamStatus): string {.inline.} =
 ss.id

proc `djid=`*(ss: var StreamStatus, value: string) {.inline.} =
 ss.djid = if isNumber(value): value else: "0"

proc `djid=`*(ss: var StreamStatus, value: int) {.inline.} =
 ss.djid = $value

proc djid* (ss: StreamStatus): string {.inline.} =
 ss.djid

proc `np=`*(ss: var StreamStatus, value: string) {.inline.} =
 ss.np = value

proc np* (ss: StreamStatus): string {.inline.} =
 ss.np

proc `iList=`*(ss: var StreamStatus, value: string) {.inline.} =
 ss.iList = if isNumber(value): value else: "0"

proc `iList=`*(ss: var StreamStatus, value: int) {.inline.} =
 ss.iList = $value

proc iList* (ss: StreamStatus): string {.inline.} =
 ss.iList

proc `bitrate=`*(ss: var StreamStatus, value: string) {.inline.} =
 ss.bitrate = if isNumber(value): value else: "0"

proc `bitrate=`*(ss: var StreamStatus, value: int) {.inline.} =
 ss.bitrate = $value

proc bitrate* (ss: StreamStatus): string {.inline.} =
 ss.bitrate

proc `isAfkStream=`*(ss: var StreamStatus, value: bool) {.inline.} =
 ss.isAfkStream = value

proc `isAfkStream=`*(ss: var StreamStatus, value: int) {.inline.} =
 ss.isAfkStream = if value > 0: true else: false

proc `isAfkStream=`*(ss: var StreamStatus, value: string) {.inline.} =
 case value
 of "true", "1":
  ss.isAfkStream = true
 else:
  ss.isAfkStream = false

proc isAfkStream* (ss: StreamStatus): bool {.inline.} =
 ss.isAfkStream

proc `isStreamDesk=`*(ss: var StreamStatus, value: bool) {.inline.} =
 ss.isStreamDesk = value

proc `isStreamDesk=`*(ss: var StreamStatus, value: int) {.inline.} =
 ss.isStreamDesk = if value > 0: true else: false

proc `isStreamDesk=`*(ss: var StreamStatus, value: string) {.inline.} =
 case value
 of "true", "1":
  ss.isStreamDesk = true
 else:
  ss.isStreamDesk = false

proc isStreamDesk* (ss: StreamStatus): bool {.inline.} =
 ss.isStreamDesk

proc `start_time=`*(ss: var StreamStatus, value: string) {.inline.} =
 ss.start_time = if isNumber(value): value else: "0"

proc `start_time=`*(ss: var StreamStatus, value: int) {.inline.} =
 ss.start_time = $value

proc start_time* (ss: StreamStatus): string {.inline.} =
 ss.start_time

proc `end_time=`*(ss: var StreamStatus, value: string) {.inline.} =
 ss.end_time = if isNumber(value): value else: "0"

proc `end_time=`*(ss: var StreamStatus, value: int) {.inline.} =
 ss.end_time = $value

proc end_time* (ss: StreamStatus): string {.inline.} =
 ss.end_time

proc `lastset=`*(ss: var StreamStatus, value: string) {.inline.} =
 ss.lastset = value

proc lastset* (ss: StreamStatus): string {.inline.} =
 ss.lastset

proc `trackid=`*(ss: var StreamStatus, value: string) {.inline.} =
 ss.trackid = if isNumber(value): value else: "0"

proc `trackid=`*(ss: var StreamStatus, value: int) {.inline.} =
 ss.trackid = $value

proc trackid* (ss: StreamStatus): string {.inline.} =
 ss.trackid

proc `thread=`*(ss: var StreamStatus, value: string) {.inline.} =
 ss.thread = value

proc thread* (ss: StreamStatus): string {.inline.} =
 ss.thread

proc `requesting=`*(ss: var StreamStatus, value: bool) {.inline.} =
 ss.requesting = value

proc `requesting=`*(ss: var StreamStatus, value: int) {.inline.} =
 ss.requesting = if value > 0: true else: false

proc `requesting=`*(ss: var StreamStatus, value: string) {.inline.} =
 case value
 of "true", "1":
  ss.requesting = true
 else:
  ss.requesting = false

proc requesting* (ss: StreamStatus): bool {.inline.} =
 ss.requesting

proc `djname=`*(ss: var StreamStatus, value: string) {.inline.} =
 ss.djname = value

proc djname* (ss: StreamStatus): string {.inline.} =
 ss.djname









proc getTimeRemInt* (status: StreamStatus): int =
 result = 0
 let timeNow = getTime()
 let endTime = parseInt(status.end_time)
 let diffTime = ((Time)endTime) - timeNow
 result = (int)diffTime

proc getTimeElapInt* (status: StreamStatus): int =
 result = 0
 let timeNow = getTime()
 let startTime = parseInt(status.start_time)
 let diffTime = timeNow - ((Time)startTime)
 result = (int)diffTime

proc getTimeRemStr* (status: StreamStatus): string =
 result = ""
 let timeNow = getTime()
 let endTime = parseInt(status.end_time)
 let diffTime = ((Time)endTime) - timeNow
 result = lenIntToStr((int)diffTime)

proc getTimeElapStr* (status: StreamStatus): string =
 result = ""
 let timeNow = getTime()
 let startTime = parseInt(status.start_time)
 let diffTime = timeNow - ((Time)startTime)
 result = lenIntToStr((int)diffTime)



proc update* (status: var StreamStatus,track: QueueItem,iceOutPath: string) =
 status.np = track.meta
 status.trackid = track.id
 status.iList = $(parseIceStats(iceOutPath).iList)
 status.start_time = $((int)getTime())
 status.end_time = $((int)(getTime()) + track.iLen)

proc update* (status: var StreamStatus,iceOutPath: string) =
 let iceOut = parseIceStats(iceOutPath)
 status.np = iceOut.np
 status.trackid = "0"
 status.iList = $iceOut.iList
 status.start_time = $((int)getTime())
 status.end_time = "0"

proc pushToDb* (status: StreamStatus, conn: DbConn) =

 try:
  if not conn.tryExec(sql("""UPDATE streamstatus SET djid=?,np=?,listeners=?,
   bitrate=?,isafkstream=?,isstreamdesk=?,start_time=?,end_time=?,
   lastset=NOW(),trackid=?,thread=?,requesting=?,
   djname=? WHERE id = 0"""),status.djid, status.np,
    status.iList, status.bitrate, if status.isAfkStream: "1" else: "0",
    if status.isStreamDesk: "1" else: "0", status.start_time, status.end_time, status.trackid,
    status.thread, if status.requesting: "1" else: "0", status.djname):
   logEvent(true,"***Error Manager: Stream status update failed")
 except:
  logEvent(true,"***Error Msg: $1" % getCurrentExceptionMsg())









