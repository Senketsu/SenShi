import os, strutils, hashes, db_mysql
import ../projectEvents
import ../manager/ntag

type
 RadioDbInfo* = tuple
  address,user,pass,dbName: string

 TSplitFile* = tuple
  dir, name, ext: string

 TTrackTable = tuple
  artist,title,album,iLen,path,tags,hash: string

proc popDatabaseConnect* (connection: var DbConn, dbInfo: RadioDbInfo): bool =
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


proc popTrackTable* (conn: DbConn, track: TTrackTable): bool =
 try:
  if conn.tryExec(sql("""INSERT INTO tracks (artist,track,album,lenght,path,tags,usable,
    accepter,lasteditor,hash) VALUES (?,?,?,?,?,?,1,?,?,?)"""),track.artist,
    track.title,track.album,track.iLen,track.path,track.tags,"SenShi","SenShi",track.hash):
   result = true
 except:
  echo getCurrentExceptionMsg()

proc prepareTrackData* (conn: DbConn, path: string, spFile: TSplitFile) =
 var
  track: TTrackTable
  artist,title,album: string = ""
  artistFb,titleFb,albumFb: string = ""

 taglib_set_strings_unicode(true)
 let file = taglib_file_new(path)
 let tag = taglib_file_tag(file)
 let properties = taglib_file_audioproperties(file)

 let iLen: int = taglib_audioproperties_length(properties)

 title = $taglib_tag_title(tag)
 artist = $taglib_tag_artist(tag)
 album = $taglib_tag_album(tag)

 taglib_file_free(file)

 # We get fallback artist / title as well album from filename
 let spName = spFile.name.split('-')
 artistFb = spName[0]
 for i in 0..spName.high:
  if i != 0:
   titleFb.add(spName[i])
   titleFb.add("-")
 titleFb.delete(titleFb.len,titleFb.len)

 let spPath = splitPath(spFile.dir)
 albumFb = spPath.tail
 # Strip of top/tailing spaces
 artistFb = strip(artistFb)
 titleFb = strip(titleFb)
 albumFb = strip(albumFb)

 # Populate TTrackTable
 if artist != "":
  track.artist = artist
 else:
  track.artist = artistFb

 if title != "":
  track.title = title
 else:
  track.title = titleFb

 if album != "":
  track.album = album
 else:
  track.album = albumFb

 track.iLen = $iLen

 track.path = path
 track.tags = "$1 $2 $3" % [track.artist,track.title,track.album]
 let hashGen = "$1 - $2 $3" % [track.artist,track.title,$iLen]
 # Hash generating
 track.hash = $(hashIgnoreCase(hashGen))

 ## Supply track to proc for db input
 if not conn.popTrackTable(track):
  logEvent(false,"***Error: populating table with '$1' failed.." % [spFile.name])

proc searchTracks* (conn: DbConn,dir: string) =

 # let allowTypes = @[".mp3",".ogg",".flac",".opus",".webm"]
 let allowTypes = @[".mp3"] ## We allow mp3 only now

 for file in walkDirRec(dir):
  let split: TSplitFile = splitFile(file)
  for ext in allowTypes:
   if ext == split.ext:
    conn.prepareTrackData(file, split)
    break

proc main() =
 var
  conn: DbConn
  dbInfo: RadioDbInfo

 echoInfo(" *** Database track table population app *** ")
 echoInfo("Please submit your mysql information to proceed.\n")
 echoInfo("* Address:\t(Your mysql address and port) [e.g:'127.0.0.1:3306']")
 dbInfo.address = readLine(stdin)

 echoInfo("* User:\t\t(your mysql username)")
 dbInfo.user = readLine(stdin)

 echoInfo("* Pass:\t\t(your mysql password)")
 dbInfo.pass = readLine(stdin)
 echoInfo("* DB Name:\t(your database name)")
 dbInfo.dbName = readLine(stdin)

 if conn.popDatabaseConnect(dbInfo):
  echoInfo("Connection established !")
 else:
  logEvent(true,"***Error Setup: Failed to establish connection with mysql server. Quitting")
  quit()

 echoInfo("Thank you ! Proceeding to populate track table..")


 while true:
  echoInfo("* Do you want to input more folders ? (yes/no)")
  var inPath: string = ""
  let yesNo = readLine(stdin).toLower()
  case yesNo
  of "y", "yes":
   echoInfo("* Please input path to search for tracks:")
   inPath = readLine(stdin)
   if dirExists(inPath):
    echoInfo("* Proccessing tracks , please wait..:")
    conn.searchTracks(inPath)
    echoInfo("Done with folder '$1'" % inPath)
   else:
    echoInfo("Error: Ooops,invalid folder path .. try again")
  of "n", "no":
   break
  of "maybe":
   echoInfo("Ay mate, we indecisive eh ?")
  else:
   echoInfo("* Not a valid choice, type 'yes' or 'no' and press enter. Ganbatte~")


 echoInfo("See ya !~")

when isMainModule: main()
