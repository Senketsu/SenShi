import strutils, os, db_mysql
import ../projectEvents
import fillTracks


proc setupDatabaseConnect* (connection: var DbConn, dbInfo: RadioDbInfo): bool =
 try:
  connection = open(dbInfo.address, dbInfo.user, dbInfo.pass, dbInfo.dbName)
  if connection.setEncoding("utf8") == false:
   logEvent(true,"***Error Setup: Failed to set DB connection encoding")
  result = true
 except EDb:
  logEvent(true,"***Error Setup: DB connection failed, EDb error")
 except OverflowError:
  logEvent(true,"***Error Setup: DB connection failed, OverflowError")
 except ValueError:
  logEvent(true,"***Error Setup: DB connection failed, ValueError")


proc createRadioDB* () =

 var
  conn: DbConn
  dbInfo: RadioDbInfo
  newDBname: string = ""

 echoInfo(" *** Welcome to SenShi database setup ! *** ")
 echoInfo("Please submit your mysql information to setup database.\n")
 echoInfo("* Address:\t(Your mysql address and port) [e.g:'127.0.0.1:3306']")
 dbInfo.address = readLine(stdin)

 echoInfo("* User:\t\t(your mysql username)")
 dbInfo.user = readLine(stdin)

 echoInfo("* Pass:\t\t(your mysql password)")
 dbInfo.pass = readLine(stdin)
 dbInfo.dbName = ""

 echoInfo("* DB Name:\t(name for your new database)")
 newDBname = readLine(stdin)
 echoInfo("\nThank you ! Proceeding to create database..")

 if conn.setupDatabaseConnect(dbInfo):
  echoInfo("Connection established !")
 else:
  logEvent(true,"***Error Setup: Failed to establish connection with mysql server. Quitting")
  quit()


 try:
  if conn.tryExec(sql("""CREATE DATABASE IF NOT EXISTS $1 DEFAULT
   CHARACTER SET = utf8""" % [newDBname])):
   echoInfo("Progress: Database 'radio' created")
 except:
  logEvent(true,"***Error Setup: MySQL failed to create database 'radio'")

 try:
  if conn.tryExec(sql("""USE $1""" % [newDBname])):
   echoInfo("Progress: Switched to '$1' database" % [newDBname])
 except:
  logEvent(true,"***Error Setup: MySQL failed to use database 'radio'")

 try:
  if conn.tryExec(sql("""CREATE TABLE tracks ( id int(8) UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    artist varchar(500) NOT NULL,track varchar(500) NOT NULL,album varchar(255) NOT NULL,
    lenght int(4) NOT NULL DEFAULT 0,
    path text NOT NULL,tags text NOT NULL , lastplayed timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
    lastrequested timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
    usable int(1) NOT NULL DEFAULT 0, accepter varchar(255) NOT NULL DEFAULT '',
    lasteditor varchar(255) NOT NULL DEFAULT '',hash varchar(40) UNIQUE,
    need_reupload int(1) NOT NULL DEFAULT 0, index(tags(767)))""")):
   echoInfo("Progress: Table 'tracks' created")
 except:
  logEvent(true,"***Error Setup: MySQL failed to create table 'tracks'")

 try:
  if conn.tryExec(sql("""CREATE TABLE queue ( trackid int(8) UNSIGNED NOT NULL,
    time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    meta text,length int(4) DEFAULT 0,id int(10) UNSIGNED PRIMARY KEY AUTO_INCREMENT)""")):
   echoInfo("Progress: Table 'queue' created")
 except:
  logEvent(true,"***Error Setup: MySQL failed to create table 'queue'")

 try:
  if conn.tryExec(sql("""CREATE TABLE lastplayed (id int(8) unsigned PRIMARY KEY
   AUTO_INCREMENT,song varchar(500) NOT NULL,trackid int(8) unsigned NOT NULL ,
   dt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)""")):
   echoInfo("Progress: Table 'lastplayed' created")
 except:
  logEvent(true,"***Error Setup: MySQL failed to create table 'lastplayed'")

 try:
  if conn.tryExec(sql("""CREATE TABLE streamstatus (id int(8) PRIMARY KEY DEFAULT 0,
    djid int(8) UNSIGNED NOT NULL DEFAULT 0, np varchar(500) NOT NULL DEFAULT '',
    listeners int(4) UNSIGNED NOT NULL DEFAULT 0, bitrate int(4) UNSIGNED NOT NULL DEFAULT 0,
    isafkstream int(1) NOT NULL DEFAULT 0,isstreamdesk int(1) NOT NULL DEFAULT 0,
    start_time bigint(20) UNSIGNED NOT NULL DEFAULT 0,end_time bigint(20) UNSIGNED NOT NULL DEFAULT 0,
    lastset timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
    trackid int(8) NOT NULL DEFAULT 0,thread text NOT NULL DEFAULT '',
    requesting int(8) NOT NULL DEFAULT 0,djname varchar(255) NOT NULL DEFAULT '')""")):
   echoInfo("Progress: Table 'streamstatus' created")
   echoInfo("Filling blank template into 'streamstatus'")
   discard conn.tryExec(sql("""INSERT INTO streamstatus (djid,np,isafkstream,bitrate) VALUES (0,'',1,256)"""))
 except:
  logEvent(true,"***Error Setup: MySQL failed to create table 'streamstatus'")


 try:
  if conn.tryExec(sql("""CREATE TABLE users (id int(8) unsigned PRIMARY KEY
    AUTO_INCREMENT,user VARCHAR(63) NOT NULL,pass VARCHAR(255) NOT NULL DEFAULT '',
    djid int(4) unsigned NOT NULL DEFAULT 0,
    privilages tinyint(3) unsigned NOT NULL DEFAULT 0,
    last_request TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
    fave_notify tinyint(2) unsigned NOT NULL DEFAULT 1,
    created_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    updated_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP() ON UPDATE
    CURRENT_TIMESTAMP(),email VARCHAR(255) NOT NULL DEFAULT '', UNIQUE(user))""")):
   echoInfo("Progress: Table 'users' created")
 except:
  logEvent(true,"***Error Setup: MySQL failed to create table 'users'")

 try:
  if conn.tryExec(sql("""CREATE TABLE faves (id bigint(8) unsigned PRIMARY KEY
    AUTO_INCREMENT, playsid int(8) unsigned NOT NULL,userid int(8) unsigned NOT
    NULL, UNIQUE (playsid, userid))""")):
   echoInfo("Progress: Table 'faves' created")
 except:
  logEvent(true,"***Error Setup: MySQL failed to create table 'faves'")

 try:
  if conn.tryExec(sql("""CREATE TABLE djs (id int(4) unsigned PRIMARY KEY
    AUTO_INCREMENT, djname VARCHAR(255) NOT NULL, tags VARCHAR(64))""")):
   echoInfo("Progress: Table 'djs' created")
  conn.exec(sql("""INSERT INTO djs (djname,tags) VALUES (?,?)"""),"SenShi","AFK_DJ")
 except:
  logEvent(true,"***Error Setup: MySQL failed to create table 'djs'")

 try:
  if conn.tryExec(sql("""CREATE TABLE plays (id bigint(8) unsigned PRIMARY KEY
    AUTO_INCREMENT, trackid int(8) unsigned NOT NULL DEFAULT 0,
    meta VARCHAR(255) NOT NULL UNIQUE, iPlays int(4) unsigned NOT NULL DEFAULT 0,
    iLen int(4) unsigned NOT NULL DEFAULT 0, lastplayed timestamp NOT NULL
    DEFAULT '0000-00-00 00:00:00' ON UPDATE CURRENT_TIMESTAMP)""")):
   echoInfo("Progress: Table 'plays' created")
 except:
  logEvent(true,"***Error Setup: MySQL failed to create table 'plays'")


 echoInfo("All tables created successfuly !")
 echoInfo("* Do you want to populate the tracks table ?")
 while true:
  echoInfo("* Do you want to input more folders ? (yes/no)")
  var inPath: string = ""
  let yesNo = readLine(stdin).toLower()
  case yesNo
  of "y", "yes":
   echoInfo("* Please input path to search for tracks:")
   inPath = readLine(stdin)
   if dirExists(inPath):
    conn.searchTracks(inPath)
    echoInfo("Done with folder '$1'" % inPath)
   else:
    echoInfo("Error: Ooops,invalid folder path .. try again")
  of "n", "no":
   echoInfo("You can populate your track table with a handy popTrackTable app anytime.")
   break
  else:
   echoInfo("* Not a valid choice, type 'yes' or 'no' and press enter.")

 echoInfo("All done, your database is ready to use ! Bye ~")


when isMainModule: createRadioDB()


