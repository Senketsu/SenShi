import strutils, times
import projectTypes, projectEvents
import snircl, ndbex/db_mysql_ex

const requestCoolDown: int = 3600 # hour obviously

proc parseQuery(splitCMD: seq[string], param: int = 0): string =
 result = ""
 for i in 0..splitCMD.high:
  if i > param:
   result.add(splitCMD[i])
   result.add(" ")
 result.delete(result.len,result.len)

proc lenIntToStrReq (iLen: int): string =
 result = ""
 let sec = iLen mod 60
 let min = (iLen - sec) div 60
 result = "$1 minute$2 $3 second$4" % [$min, if min == 1: "" else: "s", $sec, if sec == 1: "" else: "s"]

proc checkReqStatus (irc: PIrc, ts: string, user: string): bool =
 result = false
 if ts == "0000-00-00 00:00:00": return true
 var
  parTimeInfo: TimeInfo
  curGMT = getGMTime(getTime())
  lastReqTime, curUtcTime: Time
  timeLeft: int = 0
  reply: string = ""

 parTimeInfo = times.parse(ts,"yyyy-MM-dd HH:mm:ss")
 lastReqTime = timeInfoToTime(parTimeInfo)
 curUtcTime = timeInfoToTime(curGMT)
 let timeDiff = (int)(curUtcTime - lastReqTime)
 if timeDiff > requestCoolDown:
  result = true
 else:
  timeLeft = requestCoolDown - timeDiff
  reply.add('\x03')
  reply.add("07You can request again in $1." % [lenIntToStrReq(timeLeft)])
  irc.notice(user, reply)


proc addNewUser(conn: DbConn, user: string) =
 try:
  conn.exec(sql("""INSERT INTO users (user) VALUES (?)"""), user)
 except:
  logEvent(true,"***Error: @addNewUser '$1'" % getCurrentExceptionMsg())

proc hasUser(conn: DbConn, user: string): bool =
 try:
  let val = conn.getValueNew(sql("""SELECT id FROM users WHERE user = ?"""), user)
  if val.hasData:
   result = true
 except:
  logEvent(true,"***Error: @hasUser '$1'" % getCurrentExceptionMsg())

proc userCanRequest(conn: DbConn,irc: PIrc, user: string): bool =
 var
  val: TGetVal
 try:
  val = conn.getValueNew(sql("""SELECT last_request FROM users WHERE user = ?"""), user)
  if val.hasData:
   result = irc.checkReqStatus(val.data, user)
 except:
  logEvent(true,"***Error: @userCanRequest '$1'" % getCurrentExceptionMsg())

proc processCmd* (irc: PIrc, conn: DbConn, isPrivate: bool,
                                  chanManager,chanBot: ptr StringChannel) =

 var
  splitCMD: seq[string]
  query: string = ""

 splitCMD = irc.data.msg.split(" ")
 if not conn.hasUser(irc.data.nick):
  conn.addNewUser(irc.data.nick)

 # echo "DEBUG IRC: $1:$2" % [irc.data.nick,irc.data.msg]

 case splitCMD[0]
 of ".random",".ra","-random","-ra": # Request no.1
  if conn.userCanRequest(irc,irc.data.nick):
   if splitCMD.high == 0:
    chanManager[].send("bot_random $1" % irc.data.nick)

   elif splitCMD.high > 0:
    if splitCMD[1] == "f" or  splitCMD[1] == "fave":
     chanManager[].send("bot_random_fave $1" % irc.data.nick)
    else:
     return
   else:
    return

 of ".lucky","-lucky": # Request no.2
  if conn.userCanRequest(irc,irc.data.nick):
   query = parseQuery(splitCMD)
   chanManager[].send("bot_lucky $1 $2" % [irc.data.nick, query])

 of ".r", "-r","-request", ".request": # Request no.3
  if conn.userCanRequest(irc,irc.data.nick):
   query = parseQuery(splitCMD)
   chanManager[].send("bot_request $1 $2" % [irc.data.nick, query])

 of ".np", ".now playing":
  chanManager[].send("bot_np")

 of ".q", ".queue","-queue","-q":
  if splitCMD.high == 0:
   chanManager[].send("bot_queue")

  elif splitCMD.high > 0:
   if splitCMD[1] == "len" or  splitCMD[1] == "length" or splitCMD[1] == "l":
    chanManager[].send("bot_queue_len")
   else:
    return
  else:
   return

 of ".fave" , ".fa" , "-fave", "-fa":
  if splitCMD.high == 0:
   chanManager[].send("bot_fave $1" % irc.data.nick)

  elif splitCMD.high > 0:
   if splitCMD[1] == "last" or  splitCMD[1] == "l":
    chanManager[].send("bot_fave_last $1" % irc.data.nick)
   else:
    return
  else:
   return

 of ".unfave", "-unfave":
  if splitCMD.high == 0:
   chanManager[].send("bot_unfave $1" % irc.data.nick)

  elif splitCMD.high > 0:
   if splitCMD[1] == "last" or  splitCMD[1] == "l":
    chanManager[].send("bot_unfave_last $1" % irc.data.nick)
   else:
    return
  else:
   return

 of ".fave_notify":
  if splitCMD.high == 0:
   chanManager[].send("bot_fave_notify $1" % [irc.data.nick])
  elif splitCMD.high > 0:
   chanManager[].send("bot_fave_notify $1 $2" % [irc.data.nick,splitCMD[1]])


 of ".tags":
  if splitCMD.high == 0:
   chanManager[].send("bot_tags $1"% [irc.data.nick])

  elif splitCMD.high > 0:
   chanManager[].send("bot_tags $1 $2" % [irc.data.nick, splitCMD[1]])
  else:
   return

 of "@tags":
  if ircHasAccess(irc.channels[0],irc.data.nick):
   if splitCMD.high == 0:
    chanManager[].send("bot_tags_bc $1"% [irc.data.nick])

   elif splitCMD.high > 0:
    chanManager[].send("bot_tags_bc $1 $2" % [irc.data.nick, splitCMD[1]])
   else:
    return
  else:
   irc.msg(irc.channels[0],"You don't have privilages to do that.")

 of ".info", ".i":
  if splitCMD.high == 0:
   chanManager[].send("bot_info $1"% [irc.data.nick])

  elif splitCMD.high > 0:
   chanManager[].send("bot_info $1 $2" % [irc.data.nick, splitCMD[1]])
  else:
   return

 of "@info", "@i":
  if ircHasAccess(irc.channels[0],irc.data.nick):
   if splitCMD.high == 0:
    chanManager[].send("bot_info_bc $1"% [irc.data.nick])

   elif splitCMD.high > 0:
    chanManager[].send("bot_info_bc $1 $2" % [irc.data.nick, splitCMD[1]])
   else:
    return
  else:
   irc.msg(irc.channels[0],"You don't have privilages to do that.")

 of ".search", ".s":
  if splitCMD.high > 0:
   query = parseQuery(splitCMD)
   chanManager[].send("bot_search $1 $2" % [irc.data.nick, query])
  else:
   return

 of "@search", "@s":
  if ircHasAccess(irc.channels[0],irc.data.nick):
   if splitCMD.high > 0:
    query = parseQuery(splitCMD)
    chanManager[].send("bot_search_bc $1 $2" % [irc.data.nick, query])
   else:
    return
  else:
   irc.msg(irc.channels[0],"You don't have privilages to do that.")


  ## Access right commands:
 of ".topic":
  if splitCMD.high == 0:
   if isPrivate:
    chanManager[].send("bot_topic $1" % irc.data.nick)
   else:
    chanManager[].send("bot_topic")

  else:
   if ircHasAccess(irc.channels[0],irc.data.nick):
    query = parseQuery(splitCMD)
    chanManager[].send("bot_set_topic $1 $2" % [irc.data.nick, query])
   else:
    irc.msg(irc.channels[0],"You don't have privilages to do that.")

 of ".editTopic":
  if splitCMD.high >= 2:
   query = parseQuery(splitCMD,1)
   chanManager[].send("bot_edit_topic_f $1 $2" % [splitCMD[1], query])

 of ".thread":
  if splitCMD.high == 0:
   if isPrivate:
    chanManager[].send("bot_thread $1" % irc.data.nick)
   else:
    chanManager[].send("bot_thread")

  else:
   if ircHasAccess(irc.channels[0],irc.data.nick):
    query = parseQuery(splitCMD)
    chanManager[].send("bot_thread $1 $2" % [irc.data.nick, query])
   else:
    irc.msg(irc.channels[0],"You don't have privilages to do that.")

 of ".skip":
  if ircIsAdmin(irc.channels[0],irc.data.nick):
   chanManager[].send("bot_skip")

 of ".kill":
  if ircHasAccess(irc.channels[0],irc.data.nick):
   if splitCMD.high == 0:
    chanManager[].send("bot_kill $1" % irc.data.nick)
    irc.msg(irc.channels[0],"Disconnecting AFK streamer after current track..")

   elif splitCMD.high > 0:
    if splitCMD[1] == "f" or  splitCMD[1] == "force":
     chanManager[].send("bot_kill_force $1" % irc.data.nick)
     irc.msg(irc.channels[0],"Disconnecting AFK streamer..")
    else:
     return
  else:
   irc.msg(irc.channels[0],"You don't have privilages to do that.")

 of ".dj":
  if splitCMD.high == 0:
   chanManager[].send("bot_dj")

  elif splitCMD.high > 0:
   if ircHasAccess(irc.channels[0],irc.data.nick):
    if splitCMD[1].toLower() == irc.nickName.toLower():
     chanManager[].send("bot_dj_set AFK_DJ")
    else:
     chanManager[].send("bot_dj_set $1" % [splitCMD[1]])
   else:
    irc.msg(irc.channels[0],"You don't have privilages to do that.")
  else:
   return

 of ".@exit":
  if ircIsAdmin(irc.channels[0],irc.data.nick):
   irc.quit("じゃあまたね~ ( ´ ▽ ` )ﾉ")
   chanManager[].send("cmd_quit")
   quit(QuitSuccess)

 else:
  return

