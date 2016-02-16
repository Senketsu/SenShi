# snircl - synchronous nim irc library
# This file is licensed under MIT License
# Copyright(c) 2015 by Senketsu ( @Senketsu_Dev | https://github.com/Senketsu )
import net, parseutils, strutils, times, os
import db_sqlite


var
 Debug: bool = false
 bColorOut*,bPrintOut*: bool
 msgDelayCount: int = 0
 msgLastTime: Time
 sniDB : TDbConn

sniDB = open(connection = ":memory:","","","")

sniDB.exec(sql"""create table nicks (id integer primary key autoincrement,
 nick varchar(50) collate nocase)""")
sniDB.exec(sql"""create table channels (id integer primary key autoincrement,
chan varchar(100) collate nocase, topic text)""")
sniDB.exec(sql"""create table nick_chan_link (id integer primary key autoincrement,
 nick_id integer not null constraint fk_n_c REFERENCES nicks(id), chan_id integer
 not null constraint fk_c_n REFERENCES channels(id), modes varchar(20))""")

type
 TIrcEvent* = tuple
  nick,user,host,serverName: string
  cmd: IrcCmdType
  cmdNum: int
  tStampS: string
  params: seq[string] ## Parameters of the IRC message
  source,target: string ## The channel/user that this msg originated from
  msg: string
 PIrcEvent* = ref TIrcEvent

 TIrc* = tuple
  sock: Socket
  network: string
  port: int
  nickName, userName, realName, servPass, nickPass: string
  channels: seq[string]
  msgBuff: string
  data: TIrcEvent
  isReady: bool
  isTimeout: bool
 PIrc* = ref TIrc

 IrcColorCode* = enum
  White
  Black
  Blue
  Green
  LightRed
  Brown
  Purple
  Orange
  Yellow
  LightGreen
  Cyan
  LightCyan
  LightBlue
  Pink
  Gray
  LightGray

 IrcControlCode* = enum
  SOH = 0x01
  Bold = 0x02
  Color = 0x03
  Italic = 0x09
  Reset = 0x0f
  StrikeT = 0x13
  UnderLine = 0x15
  Reverse = 0x16
  UnderLine2 = 0x1f

 ColorCodeTerm* = enum
  FG_BLACK = 30
  FG_RED = 31
  FG_GREEN = 32
  FG_YELLOW = 33
  FG_BLUE = 34
  FG_PURPLE = 35
  FG_CYAN = 36
  FG_WHITE = 37
  FG_DEFAULT = 39
  BG_BLACK = 40
  BG_RED = 41
  BG_GREEN = 42
  BG_YELLOW = 43
  BG_BLUE = 44
  BG_PURPLE = 45
  BG_CYAN = 46
  BG_WHITE = 47
  BG_DEFAULT = 49

 IrcCmdType* = enum
  MUnknown
  MNumeric
  MPrivMsg
  MJoin
  MPart
  MMode
  MTopic
  MInvite
  MKick
  MQuit
  MNick
  MNotice
  MPing
  MPong
  MError
 # Numeric events with an minimal explanation
 IrcNumEvent* = enum
  # Statistic Responses
  RPL_TRACELINK = (200,"RPL_TRACELINK")
  RPL_TRACECONNECTING = (201,"RPL_TRACECONNECTING")
  RPL_TRACEHANDSHAKE = (202,"RPL_TRACEHANDSHAKE")
  RPL_TRACEUNKNOWN = (203,"RPL_TRACEUNKNOWN")
  RPL_TRACEOPERATOR = (204,"RPL_TRACEOPERATOR")
  RPL_TRACEUSER = (205,"RPL_TRACEUSER")
  RPL_TRACESERVER = (206,"RPL_TRACESERVER")
  RPL_TRACENEWTYPE = (208,"RPL_TRACENEWTYPE")
  RPL_STATSLINKINFO = (211,"RPL_STATSLINKINFO")
  RPL_STATSCOMMANDS = (212,"RPL_STATSCOMMANDS")
  RPL_STATSCLINE = (213,"RPL_STATSCLINE")
  RPL_STATSNLINE = (214,"RPL_STATSNLINE")
  RPL_STATSILINE = (215,"RPL_STATSILINE")
  RPL_STATSKLINE = (216,"RPL_STATSKLINE")
  RPL_STATSYLINE = (218,"RPL_STATSYLINE")
  RPL_ENDOFSTATS = (219,"RPL_ENDOFSTATS")
  RPL_UMODEIS = (221,"/MODE reply")
  RPL_STATSLLINE = (241,"RPL_STATSLLINE")
  RPL_STATSUPTIME = (242,"RPL_STATSUPTIME")
  RPL_STATSOLINE = (243,"RPL_STATSOLINE")
  RPL_STATSHLINE = (244,"RPL_STATSHLINE")
  RPL_LUSERCLIENT = (251,"/LUSERS: Client stats")
  RPL_LUSEROP = (252,"/LUSERS: No. of Operators")
  RPL_LUSERUNKNOWN = (253,"/LUSERS: No. of unknow connections")
  RPL_LUSERCHANNELS = (254,"/LUSERS: No. of channels")
  RPL_LUSERME = (255,"/LUSERS: No. of clients & servers")
  RPL_ADMINME = (256,"/ADMIN reply")
  RPL_ADMINLOC1 = (257,"/ADMIN info")
  RPL_ADMINLOC2 = (258,"/ADMIN info")
  RPL_ADMINEMAIL = (259,"/ADMIN mail")
  RPL_TRACELOG = (261,"File <logfile> <debug level>")
  # Command Responses
  RPL_NONE = (300,"Dummy - Not used")
  RPL_AWAY = (301, "Away message reply")
  RPL_USERHOST = (302,"USERHOST reply")
  RPL_ISON = (303,"ISON reply")
  RPL_UNAWAY = (305,"You are no longer marked as being away")
  RPL_NOWAWAY = (306,"You have been marked as being away")
  RPL_WHOISUSER = (311,"WHOIS - User reply")
  RPL_WHOISSERVER = (312,"WHOIS - Server reply")
  RPL_WHOISOPERATOR = (313,"WHOIS - If <nick> is an IRC operator")
  RPL_WHOWASUSER = (314, "WHOWAS - User reply")
  RPL_ENDOFWHO = (315, "End of /WHO list")
  RPL_WHOISIDLE = (317,"WHOIS - Seconds idle")
  RPL_ENDOFWHOIS = (318,"End of /WHOIS")
  RPL_WHOISCHANNELS = (319,"WHOIS - Channels reply")
  RPL_LISTSTART = (321,"Start of /List reply")
  RPL_LIST = (322,"Body of /List reply")
  RPL_LISTEND = (323,"End of /LIST")
  RPL_CHANNELMODEIS = (324,"<channel> <mode> <mode params>")
  RPL_NOTOPIC = (331,"No topic is set")
  RPL_TOPIC = (332,"Topic reply")
  RPL_INVITING = (341,"INVITE message was successful")
  RPL_SUMMONING = (342,"Summoning user to IRC")
  RPL_VERSION = (351,"Server version details")
  RPL_WHOREPLY = (352,"Reply to /WHO")
  RPL_NAMREPLY = (353,"Reply to /NAMES")
  RPL_LINKS = (364,"Reply to /LINKS")
  RPL_ENDOFLINKS = (365,"End of /LINKS list")
  RPL_ENDOFNAMES = (366,"End of /NAMES list")
  RPL_BANLIST = (367, "Reply to /BANLIST")
  RPL_ENDOFBANLIST = (368, "End of /BANLIST")
  RPL_ENDOFWHOWAS = (369,"End of /WHOWAS")
  RPL_INFO = (371,"Reply to /INFO")
  RPL_MOTD = (372,"Reply to /MOTD")
  RPL_ENDOFINFO = (374,"End of /INFO")
  RPL_MOTDSTART = (375,"Start of Message of the day")
  RPL_ENDOFMOTD = (376,"End of /MOTD")
  RPL_YOUREOPER = (381,"You are now an IRC operator")
  RPL_REHASHING = (382,"REHASH message reply")
  RPL_TIME = (391,"Reply to /TIME message")
  RPL_USERSSTART = (392,"Start or /USERS reply")
  RPL_USERS = (393,"Body of /USERS reply")
  RPL_ENDOFUSERS = (394,"End of /USERS reply")
  RPL_NOUSERS = (395,"Nobody logged in")
  # Error Responses
  ERR_NOSUCHNICK = (401, "No such nick/channel")
  ERR_NOSUCHSERVER = (402, "No such server")
  ERR_NOSUCHCHANNEL = (403, "No such channel")
  ERR_CANNOTSENDTOCHAN = (404, "Cannot send to channel")
  ERR_TOOMANYCHANNELS = (405, "You have joined too many channels")
  ERR_WASNOSUCHNICK = (406, "There was no such nickname")
  ERR_TOOMANYTARGETS = (407, "Too many recipients")
  ERR_NOSUCHSERVICE = (408, "No such service")
  ERR_NOORIGIN = (409, "No origin specified")
  ERR_NORECIPIENT = (411, "No recipient given")
    # 412 - 415 are returned by PRIVMSG to indicate that
  ERR_NOTEXTTOSEND = (412, "No text to send")
  ERR_NOTOPLEVEL = (413, "No toplevel domain specified")
  ERR_WILDTOPLEVEL = (414, "Wildcard in toplevel domain")
  ERR_BADMASK = (415, "Bad Server/host mask")
    #   the message wasn't delivered for some reason.
  ERR_UNKNOWNCOMMAND = (421, "Unknown command")
  ERR_NOMOTD = (422, "MOTD File is missing")
  ERR_NOADMININFO = (423, "No administrative info available")
  ERR_FILEERROR = (424, "Failed file operation during the processing of a message")
  ERR_NONICKNAMEGIVEN = (431, "No nickname given")
  ERR_ERRONEUSNICKNAME = (432, "Erroneous nickname")
  ERR_NICKNAMEINUSE = (433, "Nickname is already in use")
  ERR_NICKCOLLISION = (436, "Nickname collision KILL")
  ERR_USERNOTINCHANNEL = (441, "They aren't on that channel")
  ERR_NOTONCHANNEL = (442, "You're not on that channel")
  ERR_USERONCHANNEL = (443, "User is already on channel")
  ERR_NOLOGIN = (444, "User not logged in")
  ERR_SUMMONDISABLED = (445, "SUMMON has been disabled")
  ERR_USERSDISABLED = (446, "USERS has been disabled")
  ERR_NOTREGISTERED = (451, "You have not registered")
  ERR_NEEDMOREPARAMS = (461, "Not enough parameters")
  ERR_ALREADYREGISTRED = (462, "You may not reregister")
  ERR_NOPERMFORHOST = (463, "Your host isn't among the privileged #checkYourPrivileges")
  ERR_PASSWDMISMATCH = (464, "Password incorrect")
  ERR_YOUREBANNEDCREEP = (465, "You are banned from this server")
  ERR_KEYSET = (467,"Channel key already set")
  ERR_CHANNELISFULL = (471,"Cannot join channel (+l)")
  ERR_UNKNOWNMODE = (472,"Unknown mode char")
  ERR_INVITEONLYCHAN = (473,"Cannot join channel (+i)")
  ERR_BANNEDFROMCHAN = (474,"Cannot join channel (+b)")
  ERR_BADCHANNELKEY = (475,"Cannot join channel (+k)")
  ERR_NOPRIVILEGES = (481,"Permission Denied - You're not an IRC operator")
  ERR_CHANOPRIVSNEEDED = (482,"You're not channel operator")
  ERR_CANTKILLSERVER = (483,"You cant kill a server!")
  ERR_NOOPERHOST = (491,"No O-lines for your host")
  ERR_UMODEUNKNOWNFLAG = (501,"Unknown MODE flag")
  ERR_USERSDONTMATCH = (502,"Cant change mode for other users")

 IrcModes* = enum
  CM_ADD = "+"
  CM_REM = "-"
  CM_OP = "o"
  CM_OP_A = "+o"
  CM_OP_R = "-o"
  CM_PRIV = "p"
  CM_PRIV_A = "+p"
  CM_PRIV_R = "-p"
  CM_SECRET = "s"
  CM_SECRET_A = "+s"
  CM_SECRET_R = "-s"
  CM_INVITE = "i"
  CM_INVITE_A = "+i"
  CM_INVITE_R = "-i"
  CM_TOPIC = "t"
  CM_TOPIC_A = "+t"
  CM_TOPIC_R = "-t"
  CM_NOOUTMSG = "n"
  CM_NOOUTMSG_A = "+n"
  CM_NOOUTMSG_R = "-n"
  CM_MODERATED = "m"
  CM_MODERATED_A = "+m"
  CM_MODERATED_R = "-m"
  CM_USRLIM = "l"
  CM_USRLIM_A = "+l"
  CM_USRLIM_R = "-l"
  CM_BANMASK = "b"
  CM_BANMASK_A = "+b"
  CM_BANMASK_R = "-b"
  CM_VOICE = "v"
  CM_VOICE_A = "+v"
  CM_VOICE_R = "-v"
  CM_KEY = "k"
  CM_KEY_A = "+k"
  CM_KEY_R = "-k"
  USR_INVIS = "i"
  USR_INVIS_A = "+i"
  USR_INVIS_R = "-i"
  USR_SNOTICE = "s"
  USR_SNOTICE_A = "+s"
  USR_SNOTICE_R = "-s"
  USR_WALLOPS = "w"
  USR_WALLOPS_A = "+w"
  USR_WALLOPS_R = "-w"
  USR_OP = "o"
  USR_OP_A = "+o"
  USR_OP_R = "-o"

# @@@@@@@@@@@@@@@@@@@@@@@@
# FWD Procs Declarations
# @@@@@@@@@@@@@@@@@@@@@@@@

# @@@@@@@@@@@@@@@@@@@@@@@@
# Util
# @@@@@@@@@@@@@@@@@@@@@@@@
proc printEvent (msg: string) =
 if bColorOut:
  if msg.startsWith("***Error"):
   stderr.writeLine("\27[1;31m$1\27[0m"%[msg])
  elif msg.startsWith("*Notice") :
   stderr.writeLine("\27[1;34m$1\27[0m"%[msg])
  elif msg.startsWith("**Warning") :
   stderr.writeLine("\27[1;33m$1\27[0m"%[msg])
  elif msg.startsWith("*Debug") :
   stderr.writeLine("\27[1;32m$1\27[0m"%[msg])
  else:
   stderr.writeLine(msg)
 else:
  stderr.writeLine(msg)

proc ircAntiKick* () =
 var msgLastInSec: float = toSeconds(msgLastTime)
 if fromSeconds(msgLastInSec + 2) < getTime():
  msgDelayCount = 0
 elif msgDelayCount >= 3:
  sleep(1000)
  msgDelayCount = 0


# @@@@@@@@@@@@@@@@@@@@@@@@
# IRC Protocol procs
# @@@@@@@@@@@@@@@@@@@@@@@@
proc send* (irc: PIrc, data: string) =
 var sendData: string = data & "\c\L"
 ircAntiKick()
 irc.sock.send(sendData)
 msgLastTime = getTime()
 inc(msgDelayCount)
 if Debug:
  echo (">>" & sendData)

proc ping* (irc: PIrc, target: string) =
 irc.send("PING :" & target)

proc pong* (irc: PIrc, msg: string) =
 irc.send("PONG :" & msg)

proc nick* (irc: PIrc, nick: string) =
 irc.send("NICK :" & nick)

proc user* (irc: PIrc, userName, realName: string) =
 irc.send("USER $1 vhost 1 :$2"%[userName,realName])

proc server* (irc: PIrc , servName, servInfo, hopcount: string) =
 irc.send("SERVER $1 $2 :$3"%[servName,hopcount,servInfo])

proc oper* (irc: PIrc, userName, password: string) =
 irc.send("OPER $1 $2"%[userName,password])

proc quit* (irc: PIrc, msg: string) =
 irc.send("QUIT :" & msg)

proc close* (irc: Pirc) =
 irc.sock.close()

proc squit* (irc: PIrc, servName,reason: string) =
 irc.send("SQUIT $1 :$2"%[servName,reason])

proc join* (irc: PIrc, channel: string) =
 irc.send("JOIN " & channel)

proc join* (irc: PIrc, channel,key: string) =
 irc.send("JOIN $1 $2"%[channel,key])

proc join* (irc: PIrc, channels,keys: seq[string]) =
 var buffChan,buffKey: string = ""
 for channel in channels:
  buffChan.add(channel & ",")
 buffChan.delete(buffChan.len,buffChan.len)
 for key in keys:
  buffKey.add(key & ",")
 buffKey.delete(buffKey.len,buffKey.len)
 irc.send("JOIN $1 $2"%[buffChan,buffKey])

proc join* (irc: PIrc, channels: seq[string]) =
 var buffChan: string = ""
 for channel in channels:
  buffChan.add(channel & ",")
 buffChan.delete(buffChan.len,buffChan.len)
 irc.send("JOIN $1"%[buffChan])

proc part* (irc: PIrc, channel: string) =
 irc.send("PART " & channel)

proc part* (irc: PIrc, channels: seq[string]) =
 var buffChan: string = ""
 for channel in channels:
  buffChan.add(channel & ",")
 buffChan.delete(buffChan.len,buffChan.len)
 irc.send("PART $1"%[buffChan])

proc mode* (irc: PIrc, target,modes: string) =
 irc.send("MODE $1 $2"%[target,modes])

proc mode* (irc: PIrc, target,modes,param: string) =
 irc.send("MODE $1 $2 $3"%[target,modes,param])

proc topic* (irc: PIrc, channel: string) =
 irc.send("TOPIC $1"%[channel])

proc topic* (irc: PIrc, channel,topicMsg: string) =
 irc.send("TOPIC $1 :$2"%[channel,topicMsg])

proc names* (irc: PIrc) =
 irc.send("NAMES")

proc names* (irc: PIrc, channel: string) =
 irc.send("NAMES $1"%[channel])

proc names* (irc: PIrc, channels: seq[string]) =
 var buffChan: string = ""
 for channel in channels:
  buffChan.add(channel & ",")
 buffChan.delete(buffChan.len,buffChan.len)
 irc.send("NAMES $1"%[buffChan])

proc list* (irc: PIrc) =
 irc.send("LIST")

proc list* (irc: PIrc, channel: string) =
 irc.send("LIST $1"%[channel])

proc list* (irc: PIrc, channels: seq[string]) =
 var buffChan: string = ""
 for channel in channels:
  buffChan.add(channel & ",")
 buffChan.delete(buffChan.len,buffChan.len)
 irc.send("LIST $1"%[buffChan])

proc invite* (irc: PIrc, user,channel: string) =
 irc.send("INVITE $1 $2"%[user,channel])

proc kick* (irc: PIrc, channel,user: string) =
 irc.send("KICK $1 $2"%[channel,user])

proc kick* (irc: PIrc, channel,user,reason: string) =
 irc.send("KICK $1 $2 :$3"%[channel,user,reason])

proc kick* (irc: PIrc, users: seq[string],channel,reason: string = "") =
 var buffUsers: string = ""
 for user in users:
  buffUsers.add(user & ",")
 buffUsers.delete(buffUsers.len,buffUsers.len)
 if reason != "":
  irc.send("KICK $1 $2 :$3"%[channel,buffUsers,reason])
 else:
  irc.send("KICK $1 $2"%[channel,buffUsers])

proc kick* (irc: PIrc, channels,users: seq[string],reason: string = "") =
 var buffChan,buffUsers: string = ""
 for channel in channels:
  buffChan.add(channel & ",")
 buffChan.delete(buffChan.len,buffChan.len)
 for user in users:
  buffUsers.add(user & ",")
 buffUsers.delete(buffUsers.len,buffUsers.len)
 if reason != "":
  irc.send("KICK $1 $2 :$3"%[buffChan,buffUsers,reason])
 else:
  irc.send("KICK $1 $2"%[buffChan,buffUsers])

proc version* (irc: PIrc, param: string = "") =
 if param != "":
  irc.send("VERSION $1"%[param])
 else:
  irc.send("VERSION")


proc stats* (irc: PIrc, param: string, server: string = "") =
 if server != "":
  irc.send("STATS $1 $2"%[param,server])
 else:
  irc.send("STATS $1"%[param])

proc links* (irc: PIrc, mask: string = "") =
 if mask != "":
  irc.send("LINKS $1"%[mask])
 else:
  irc.send("LINKS")

proc links* (irc: PIrc, server, mask: string) =
 irc.send("LINKS $1 $2"%[mask,server])

proc time* (irc: PIrc, server: string = "") =
 if server != "":
  irc.send("TIME $1"%[server])
 else:
  irc.send("TIME")

proc connect* (irc: PIrc, target: string) =
 irc.send("CONNECT $1"%[target])

proc connect* (irc: PIrc, target,server,port: string) =
 irc.send("CONNECT $1 $2 $3"%[target,port,server])

proc trace* (irc: PIrc, target: string = "") =
 if target != "":
  irc.send("TRACE $1"%[target])
 else:
  irc.send("TRACE")

proc admin* (irc: PIrc, target: string = "") =
 if target != "":
  irc.send("ADMIN $1"%[target])
 else:
  irc.send("ADMIN")

proc info* (irc: PIrc, target: string = "") =
 if target != "":
  irc.send("INFO $1"%[target])
 else:
  irc.send("INFO")

proc msg* (irc: PIrc, target,msg: string) =
 irc.send("PRIVMSG $1 :$2"%[target,msg])

proc msg* (irc: PIrc, targets: seq[string] ,msg: string) =
 var buffTargets: string = ""
 for target in targets:
  buffTargets.add(target & ",")
 buffTargets.delete(buffTargets.len,buffTargets.len)
 irc.send("PRIVMSG $1 :$2"%[buffTargets,msg])

proc notice* (irc: PIrc, target,msg: string) =
 irc.send("NOTICE $1 :$2"%[target,msg])

proc who* (irc: PIrc, target: string, op: bool = false) =
 if op:
  irc.send("WHO $1 o"%[target])
 else:
  irc.send("WHO $1"%[target])

proc who_OP* (irc: PIrc, target: string) =
 irc.send("WHO $1 o"%[target])

proc whois* (irc: PIrc, target: string, server: string = "") =
 if server != "":
  irc.send("WHOIS $1 $2"%[server,target])
 else:
  irc.send("WHOIS $1"%[target])
# Test
proc whowas2* (irc: PIrc, nickname: string,server: string = "", count:int = -1) =
 if count < 0:
  if server != "":
   irc.send("WHOWAS $1 $2"%[nickname,server])
  else:
   irc.send("WHOWAS $1"%[nickname])
 else:
  if server != "":
   irc.send("WHOWAS $1 $2 $3"%[nickname,$count,server])
  else:
   irc.send("WHOWAS $1 $2"%[nickname,$count])

proc whowas* (irc: PIrc, nickname: string,server: string = "", count:int = -1) =
 if server != "":
  irc.send("WHOWAS $1 $2 $3"%[nickname,$count,server])
 else:
  irc.send("WHOWAS $1 $2"%[nickname,$count])

proc kill* (irc: PIrc, nickname: string,comment: string) =
 irc.send("KILL $1 $2"%[nickname,comment])

proc away* (irc: PIrc, msg: string = "") =
 if msg != "":
  irc.send("AWAY $1"%[msg])
 else:
  irc.send("AWAY")

proc rehash* (irc: PIrc) =
 irc.send("REHASH")

proc restart* (irc: PIrc) =
 irc.send("RESTART")

proc summon* (irc: PIrc, user: string,server: string = "") =
 if server != "":
  irc.send("SUMMON $1 $2"%[user,server])
 else:
  irc.send("SUMMON $1"%[user])

proc users* (irc: PIrc, server: string) =
 irc.send("USERS $1"%[server])

proc wallops* (irc: PIrc, msg: string) =
 irc.send("WALLOPS :$1"%[msg])

proc userhost* (irc: PIrc, nickname: string) =
 irc.send("USERHOST $1"%[nickname])

proc userhost* (irc: PIrc, nicknames: seq[string]) =
 var nickList: string = ""
 var i: int = 0
 for nick in nicknames:
  if i == 5: break
  nickList.add(nick & " ")
  inc(i)
 irc.send("USERHOST $1"%[nickList])

proc ison* (irc: PIrc, nickname: string) =
 irc.send("ISON $1"%[nickname])

proc ison* (irc: PIrc, nicknames: seq[string]) =
 var nickList: string = ""
 for nick in nicknames:
  if (nickList.len + nick.len > 504):
   irc.send("ISON $1"%[nickList])
   nickList = ""
  nickList.add(nick & " ")
 irc.send("ISON $1"%[nickList])

# proc * (irc: PIrc, ) =

# @@@@@@@@@@@@@@@@@@@@@@@@
# IRC snircl db procs
# @@@@@@@@@@@@@@@@@@@@@@@@
proc sdb_hasChan* (chan: string): bool =
 var value: string = ""
 value = sniDB.getValue(sql("SELECT * FROM channels WHERE chan='$1' LIMIT 1" % [chan]))
 if value == "":
  result = false
 else:
  result = true

proc sdb_hasNick* (nick: string): bool =
 var value: string = ""
 value = sniDB.getValue(sql("SELECT * FROM nicks WHERE nick='$1' LIMIT 1" % [nick]))
 if value == "":
  result = false
 else:
  result = true

proc sdb_getID* (par: string): int =
 var value: string = ""
 if par[0] == '#':
  value = sniDB.getValue(sql("SELECT id FROM channels WHERE chan='$1' limit 1" % [par]))
 else:
  value = sniDB.getValue(sql("SELECT id FROM nicks WHERE nick='$1' limit 1" % [par]))
 if value == "":
  result = 0
 else:
  result = parseInt(value)

proc sdb_inChannel* (chan,nick: string): bool =
 if sdb_hasChan(chan) and sdb_hasNick(nick):
  var
   chanID,nickID: int = 0
   value : string = ""
  chanID = sdb_getID(chan)
  nickID = sdb_getID(nick)
  value = sniDB.getValue(sql("SELECT id FROM nick_chan_link WHERE nick_id=$1 AND chan_id=$2"%[$nick_id, $chan_id]))
  if value == "":
   result = false
  else:
   result = true
 else:
  result = false
# May be problematic
proc sdb_partChannel* (chan,nick: string) =
 var
  chanID, nickID: int
 chanID = sdb_getID(chan)
 nickID = sdb_getID(nick)

 if sdb_inChannel(chan,nick) == true:
  if chanID == 0:
   sniDB.exec(sql("""DELETE FROM nick_chan_link WHERE nick_id = $1""" % [$nickID]))
  else:
   sniDB.exec(sql("""DELETE FROM nick_chan_link WHERE chan_id = $1
    AND nick_id = $2""" % [$chanID,$nickID]))


proc sdb_joinChannel* (chan,nick: string) =
 var
  chanID, nickID: int
 chanID = sdb_getID(chan)
 nickID = sdb_getID(nick)

 if nickID == 0:
  sniDB.exec(sql("INSERT INTO nicks (nick) VALUES ('$1')" % [nick]))
 if chanID == 0:
  sniDB.exec(sql("INSERT INTO channels (chan,topic) VALUES ('$1','')" % [chan]))
 chanID = sdb_getID(chan)
 nickID = sdb_getID(nick)
 if sdb_inChannel(chan,nick) == false:
  sniDB.exec(sql("INSERT INTO nick_chan_link (nick_id, chan_id, modes) VALUES ($1, $2, '')"%[$nick_id, $chan_id]))

proc sdb_hasModes* (chan,nick,modes: string, oper: string = ""): bool =
 if sdb_inChannel(chan,nick):
  var
   chanID, nickID: int = 0
   value: string = ""
  result = false
  chanID = sdb_getID(chan)
  nickID = sdb_getID(nick)
  value = sniDB.getValue(sql("SELECT modes FROM nick_chan_link WHERE nick_id=$1 AND chan_id=$2"%[$nick_id, $chan_id]))
  if value != "":
   for c in value:
    if oper == "":
     if c == modes[0]:
      result = true
      break
    else:
     if modes.contains(c):
      result = true
      break

proc sdb_addMode* (chan,nick: string, mode: char) =
 if sdb_inChannel(chan,nick):
  if sdb_hasModes(chan,nick,modes = $mode) == false:
   var
    chanID, nickID: int = 0
   chanID = sdb_getID(chan)
   nickID = sdb_getID(nick)
   sniDB.exec(sql("UPDATE nick_chan_link SET modes=modes||'$1' WHERE nick_id=$2 AND chan_id=$3"%[$mode, $nick_id, $chan_id]))


# @@@@@@@@@@@@@@@@@@@@@@@@
# IRC Non standard procs
# @@@@@@@@@@@@@@@@@@@@@@@@
proc ircHasAccess* (chan,nick: string): bool =
 result = sdb_hasModes(chan,nick,"oaqh","OR")

proc ircIsOwner* (chan,nick: string): bool =
 result = sdb_hasModes(chan,nick,"q")

proc ircIsAdmin* (chan,nick: string): bool =
 result = sdb_hasModes(chan,nick,"aq", "OR")

proc ircIsOp* (chan,nick: string): bool =
 result = sdb_hasModes(chan,nick,"oaq","OR")

proc ircIsHop* (chan,nick: string): bool =
 result = sdb_hasModes(chan,nick,"h")

proc ircIsVoice* (chan,nick: string): bool =
 result = sdb_hasModes(chan,nick,"v")

proc ircIsNormal* (chan,nick: string): bool =
 if sdb_hasModes(chan,nick,"oaqvh","OR") == false:
  result = true

proc nsIdentify* (irc: PIrc, pass: string) =
 irc.send("PRIVMSG NICKSERV :IDENTIFY " & pass)

proc on_353* (chan:string, msg: string) =
 var
  nick : string = ""
  mode : char = '\0'
  userList: seq[string] = msg.split(' ')

 for user in userList:
  case user[0]
  of '~': mode = 'q' # Owner
  of '&': mode = 'a' # Admin
  of '@': mode = 'o' # OP
  of '%': mode = 'h' # Half OP
  of '+': mode = 'v' # Voice
  else: mode = '\0'

  if user.len > 1:
   if mode == '\0':
    nick = user
    sdb_joinChannel(chan,nick)
   else:
    var usr: string = user
    usr.delete(0,0)
    nick = usr
    sdb_joinChannel(chan,nick)
    sdb_addMode(chan,nick,mode)

# @@@@@@@@@@@@@@@@@@@@@@@@
# Parser & Handle
# @@@@@@@@@@@@@@@@@@@@@@@@
proc isNumber (s: string): bool =
 var i = 0
 while s[i] in {'0'..'9'}: inc(i)
 result = i == s.len and s.len > 0

# parseMsg Taken from nim's irc lib (for now?)
proc parseMsg* (msgData: string): TIrcEvent =
 var
  msg: string = msgData
  i: int = 0
 result.nick = ""
 result.serverName = ""
 # Process the prefix
 if msg[i] == ':':
  inc(i) # Skip `:`
  var nick = ""
  i.inc msg.parseUntil(nick, {'!', ' '}, i)
  if msg[i] == '!':
   result.nick = nick
   inc(i) # Skip `!`
   i.inc msg.parseUntil(result.user, {'@'}, i)
   inc(i) # Skip `@`
   i.inc msg.parseUntil(result.host, {' '}, i)
   inc(i) # Skip ` `
   discard msg.parseUntil(result.source, {' '}, 1)
  else:
   result.serverName = nick
   result.source = nick
   inc(i) # Skip ` `

 # Process command
 var cmd = ""
 i.inc msg.parseUntil(cmd, {' '}, i)
 if cmd.isNumber:
  result.cmd = MNumeric
  result.cmdNum = parseInt(cmd)
 else:
  case cmd
  of "PRIVMSG": result.cmd = MPrivMsg
  of "JOIN": result.cmd = MJoin
  of "PART": result.cmd = MPart
  of "PONG": result.cmd = MPong
  of "PING": result.cmd = MPing
  of "MODE": result.cmd = MMode
  of "TOPIC": result.cmd = MTopic
  of "INVITE": result.cmd = MInvite
  of "KICK": result.cmd = MKick
  of "QUIT": result.cmd = MQuit
  of "NICK": result.cmd = MNick
  of "NOTICE": result.cmd = MNotice
  of "ERROR": result.cmd = MError
  else: result.cmd = MUnknown

 result.msg = ""
 # Params
 result.params = @[]
 var param = ""
 while msg[i] != '\0' and msg[i] != ':':
  inc(i) # Skip ` `.
  i.inc msg.parseUntil(param, {' ', ':', '\0'}, i)
  if param != "":
   result.params.add(param)
   param.setlen(0)

 if msg[i] == ':':
  inc(i) # Skip `:`.
  result.params.add(msg[i..msg.len-1])
  result.msg = result.params[high(result.params)]

 result.target = result.params[low(result.params)]
 result.tStampS = "[$1]"%[getClockStr()]

proc handleData* (irc: PIrc): int =
 var recvBuff: TaintedString = ""
 try:
  irc.sock.readLine(recvBuff, 1000)
 except OSError:
  let errMsg = getCurrentExceptionMsg()
  printEvent("***Error: " & errMsg)
 except TimeoutError:
  # let errMsg = getCurrentExceptionMsg()
  # printEvent("***Error: " & errMsg)
  irc.isTimeout = true
  return 0
 except:
  printEvent("***Error: unexpected exception :^)")
 if recvBuff == "":
  printEvent("***Error IRC: socket closed")
  return -1
 else:
  irc.msgBuff = $recvBuff
  irc.data = irc.msgBuff.parseMsg()
  irc.isTimeout = false
# @@@@@@@@@@@@@@@@@@@@@@@@
# Socket & Connection
# @@@@@@@@@@@@@@@@@@@@@@@@
proc connectS* (Sock: var Socket, sNetwork: string, sPort: int): bool =
 try:
  Sock = newSocket()
  Sock.connect(sNetwork,Port(sPort))
  result = true
 except OSError:
  let errMsg = getCurrentExceptionMsg()
  printEvent("***Error: " & errMsg)

proc register* (irc: PIrc) =
 assert(irc.nickName != "")
 if irc.servPass != "":
  irc.send("PASS " & irc.servPass)
 irc.nick(irc.nickName)
 irc.user(irc.userName,irc.realName)

proc connect* (irc: PIrc):bool =
 assert(irc.network != "")
 assert(irc.port != 0)
 if (irc.sock.connectS(irc.network,irc.port)) == true:
  irc.register()
  return true

# @@@@@@@@@@@@@@@@@@@@@@@@
# Main & Client proc
# @@@@@@@@@@@@@@@@@@@@@@@@
proc printEventMsg* (irc: PIrc) =

 if bColorOut:
  case irc.data.cmd
  of MJoin: # \27[1;35m \27[0m - BG \27[Xm
   stdout.writeLine("\27[0;35m* $1($2) has joined $3\27[0m"%[irc.data.nick,irc.data.source,irc.data.target])
  of MPart:
   stdout.writeLine("\27[0;35m* $1 has parted ($2)\27[0m"%[irc.data.nick,irc.data.target])
  of MMode:
   stdout.writeLine("\27[46m* $1 has changed mode of $2[$3] ($4)\27[0m"%[irc.data.nick,irc.data.params[high(irc.data.params)],irc.data.target,irc.data.params[1]])
  of MTopic:
   stdout.writeLine("\27[43m* $1 has changed the topic of $2 to: $3\27[0m"%[irc.data.nick,irc.data.target,irc.data.msg])
  of MKick:
   stdout.writeLine("\27[41m* $1 has kicked $2 from $3($4)\27[0m"%[irc.data.nick,irc.data.params[1],irc.data.target,irc.data.msg])
  of MQuit:
   stdout.writeLine("\27[1;35m* $1 has quit ($2)\27[0m"%[irc.data.nick,irc.data.target])
  of MNotice:
   stdout.writeLine("\27[1;34m$1 [$2] $3: $4\27[0m"%[irc.data.tStampS,irc.data.target,irc.data.nick,irc.data.msg])
  of MPrivMsg:
   if irc.data.target == irc.nickName:
    stdout.writeLine("\27[1;32m$1 [$2] $3: $4\27[0m"%[irc.data.tStampS,irc.data.target,irc.data.nick,irc.data.msg])
   else:
    stdout.writeLine("$1 [$2] $3: $4"%[irc.data.tStampS,irc.data.target,irc.data.nick,irc.data.msg])
  else: discard
 else:
  case irc.data.cmd
  of MJoin: # \27[1;35m \27[0m
   stdout.writeLine("* $1($2) has joined $3"%[irc.data.nick,irc.data.source,irc.data.target])
  of MPart:
   stdout.writeLine("* $1 has parted ($2)"%[irc.data.nick,irc.data.target])
  of MMode:
   stdout.writeLine("* $1 has changed mode of $2[$3] ($4)"%[irc.data.nick,irc.data.params[high(irc.data.params)],irc.data.target,irc.data.params[1]])
  of MTopic:
   stdout.writeLine("* $1 has changed the topic of $2 to: $3"%[irc.data.nick,irc.data.target,irc.data.msg])
  of MKick:
   stdout.writeLine("* $1 has kicked $2 from $3($4)"%[irc.data.nick,irc.data.params[1],irc.data.target,irc.data.msg])
  of MQuit:
   stdout.writeLine("* $1 has quit ($2)"%[irc.data.nick,irc.data.target])
  of MNotice:
   stdout.writeLine("$1 ->[$2]<- $3: $4"%[irc.data.tStampS,irc.data.target,irc.data.nick,irc.data.msg])
  of MPrivMsg:
   if irc.data.target == irc.nickName:
    stdout.writeLine("$1 >[$2]< $3: $4"%[irc.data.tStampS,irc.data.target,irc.data.nick,irc.data.msg])
   else:
    stdout.writeLine("$1 [$2] $3: $4"%[irc.data.tStampS,irc.data.target,irc.data.nick,irc.data.msg])
  else: discard

proc handleEvent* (irc: PIrc) =

 case irc.data.cmd
 of MPing: # Reply to pings from server
  irc.pong(irc.data.msg)

 of MInvite:                                 # Make y/n query
  discard

 of MNumeric:
  case irc.data.cmdNum
  of 353: # Names Reply
   on_353(irc.data.params[2],irc.data.msg)

  of 376: # End of Motd
   for channel in irc.channels:
    if channel.len > 1:
     irc.join(channel)
   irc.isReady = true

  of 400..550: # Range of errors
   let NumEvent: enum = cast[IrcNumEvent](irc.data.cmdNum)
   printEvent("***Error IRC-Numeric: $1 - $2"%[$irc.data.cmdNum,$NumEvent])

  else: discard

 of MPrivMsg,MNotice:   # Send nickserv password
  if irc.data.source.startsWith("NickServ!NickServ@services"):
   if irc.data.msg.startsWith("This nickname is registered"):
    printEvent("*Notice IRC: Trying to authorize via NickServ..")
    if irc.nickPass != "":
     irc.nsIdentify(irc.nickPass)
   elif irc.data.msg.startsWith("You are now identified"):
    printEvent("*Notice IRC: Auth by NickServ successful.")
   else:
    discard

 of MError:
  printEvent("***Error IRC: "&irc.data.msg )

 of MUnknown:
  printEvent("***Error IRC: Unknow event - "&irc.data.msg )

 of MJoin:
  sdb_joinChannel(irc.data.target,irc.data.nick)
 of MPart,MQuit:
  sdb_partChannel(irc.data.target,irc.data.nick)

 else:
  discard

proc main () =

 if system.hostOS == "linux":
  bColorOut = true

 var
  myirc: PIrc
  input: string = ""
 new myirc

 msgLastTime = getTime()
 echo("Start time:",$msgLastTime)
 echo "Fields market with '*' are optional (skip with enter)"
 if Debug == false:
   stdout.write "Network:"
   myIRC.network = readLine(stdin)
   stdout.write "Port:"
   myIRC.port = parseInt(readLine(stdin))
   stdout.write "*Server Pass:"
   myIRC.servPass = readLine(stdin)
   stdout.write "Nick:"
   myIRC.nickName = readLine(stdin)
   myIRC.userName = myIRC.nickName
   myIRC.realname = myIRC.nickName & "@snircl"
   stdout.write "*Nick Pass:"
   myIRC.nickPass = readLine(stdin)
   stdout.write "Channel(s):"
   input = readLine(stdin)
   myIRC.channels = input.split()
   bPrintOut = true


 if Debug:
  myIRC.nickName = "Sylphy"
  myIRC.userName = "Sylphy"
  myIRC.realname = "Sylphy-sama"
  myIRC.channels = @["#Senketsu","#Sylphy"]
  myIRC.network = "irc.stormbit.net"
  myIRC.port = 6667
  myIRC.servPass = ""
  myIRC.nickPass = ""

 if myIRC.connect():
  while myIRC.handleData() == 0: myIRC.handleEvent()
 else:
  printEvent("*Notice: Connecting failed,exiting.")

when isMainModule: main()
