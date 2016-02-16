import strutils, times
import projectTypes, projectEvents
import ntag
from os import splitFile

# @@@@@@@@@@@@@@@@@@@@@@@@
# Convertors INT -><- STR
# @@@@@@@@@@@@@@@@@@@@@@@@
proc lenStrToInt* (sLen: string): int =
 result = 0
 let splitLen = sLen.split(":")
 result = (parseInt(splitLen[0])*60) + parseInt(splitLen[1])

proc lenIntToStr* (iLen: int): string =
 result = ""
 let sec = iLen mod 60
 let min = (iLen - sec) div 60
 result = ("$1:$2" % [if min > 9: $min else: "0" & $min,
  if sec > 9: $sec else: "0" & $sec])

proc lenIntToStrQueue* (iLen: int): string =
 result = ""
 let sec = iLen mod 60
 let min = ((int)(iLen / 60) %% 60)
 let hour = (int)(iLen / 3600)
 result = ("($1:$2:$3)" % [ if hour > 9: $hour else: "0" & $hour,
      if min > 9: $min else: "0" & $min, if sec > 9: $sec else: "0" & $sec])

# @@@@@@@@@@@@@@@@@@@@@@@@
# Time Remaining (INT)
# @@@@@@@@@@@@@@@@@@@@@@@@
proc getTimeRemInt* (endTime: string): int =
 result = 0
 let timeNow = getTime()
 let iEndTime = parseInt(endTime)
 let diffTime = ((Time)iEndTime) - timeNow
 result = (int)diffTime

proc getTimeRemInt* (endTime: int): int =
 result = 0
 let timeNow = getTime()
 let diffTime = ((Time)endTime) - timeNow
 result = (int)diffTime

proc getTimeRemInt* (endTime: Time): int =
 result = 0
 let timeNow = getTime()
 let diffTime = endTime - timeNow
 result = (int)diffTime

# @@@@@@@@@@@@@@@@@@@@@@@@
# Time Elapsed (INT)
# @@@@@@@@@@@@@@@@@@@@@@@@
proc getTimeElapInt* (startTime: string): int =
 result = 0
 let timeNow = getTime()
 let iStartTime = parseInt(startTime)
 let diffTime = timeNow - ((Time)iStartTime)
 result = (int)diffTime

proc getTimeElapInt* (startTime: int): int =
 result = 0
 let timeNow = getTime()
 let diffTime = timeNow - ((Time)startTime)
 result = (int)diffTime

proc getTimeElapInt* (startTime: Time): int =
 result = 0
 let timeNow = getTime()
 let diffTime = timeNow - startTime
 result = (int)diffTime

# @@@@@@@@@@@@@@@@@@@@@@@@
# Time Remaining (STR)
# @@@@@@@@@@@@@@@@@@@@@@@@
proc getTimeRemStr* (endTime: string): string =
 result = ""
 let timeNow = getTime()
 let iEndTime = parseInt(endTime)
 let diffTime = ((Time)iEndTime) - timeNow
 result = lenIntToStr((int)diffTime)


proc getTimeRemStr* (endTime: int): string =
 result = ""
 let timeNow = getTime()
 let diffTime = ((Time)endTime) - timeNow
 result = lenIntToStr((int)diffTime)

proc getTimeRemStr* (endTime: Time): string =
 result = ""
 let timeNow = getTime()
 let diffTime = endTime - timeNow
 result = lenIntToStr((int)diffTime)

# @@@@@@@@@@@@@@@@@@@@@@@@
# Time Elapsed (STR)
# @@@@@@@@@@@@@@@@@@@@@@@@
proc getTimeElapStr* (startTime: string): string =
 result = ""
 let timeNow = getTime()
 let iStartTime = parseInt(startTime)
 let diffTime = timeNow - ((Time)iStartTime)
 result = lenIntToStr((int)diffTime)

proc getTimeElapStr* (startTime: int): string =
 result = ""
 let timeNow = getTime()
 let diffTime = timeNow - ((Time)startTime)
 result = lenIntToStr((int)diffTime)

proc getTimeElapStr* (startTime: Time): string =
 result = ""
 let timeNow = getTime()
 let diffTime = timeNow - startTime
 result = lenIntToStr((int)diffTime)

# @@@@@@@@@@@@@@@@@@@@@@@@
# Metadata procs (NTAG)
# @@@@@@@@@@@@@@@@@@@@@@@@
proc getTrackLenInt* (filePath: string): int =
 result = 0
 taglib_set_strings_unicode(true)
 let file = taglib_file_new(filePath)
 let properties = taglib_file_audioproperties(file)

 if properties == nil:
  logEvent(true,"***Error Manager: nil audio prop. from ntag,file '$1'" % filePath)
 else:
  result = taglib_audioproperties_length(properties)
 taglib_file_free(file)

proc getTrackLenStr* (filePath: string): string =
 result = ""
 taglib_set_strings_unicode(true)
 let file = taglib_file_new(filePath)
 let properties = taglib_file_audioproperties(file)

 if properties == nil:
  logEvent(true,"***Error Manager: nil audio prop. from ntag,file '$1'" % filePath)
 else:
  let iLen: int = taglib_audioproperties_length(properties)
  result = lenIntToStr(iLen)
 taglib_file_free(file)

proc getTrackMeta* (filePath: string, metaType: string): string =
 result = ""
 taglib_set_strings_unicode(true)
 let file = taglib_file_new(filePath)
 let tag = taglib_file_tag(file)

 if tag != nil:
  case metaType
  of "title":
   result = $taglib_tag_title(tag)
  of "artist":
   result = $taglib_tag_artist(tag)
  of "album":
   result = $taglib_tag_album(tag)
  of "comment":
   result = $taglib_tag_comment(tag)
  of "meta":
   let artist = taglib_tag_artist(tag)
   let title = taglib_tag_title(tag)
   result = ("$1 - $2" % [$artist,$title])
   if result.len < 4:
    logEvent(true, "**Warning ntag: No metadata for track path '$1'" % filePath)
    let split: TSplitFile = splitFile(filePath)
    result = split.name
  else:
   logEvent(true,"**Warning: In manGetCurSongMeta unexpected request '$1'" % metaType)
 else:
  logEvent(true,"***Error Manager: nil tag obj. from ntag,file '$1'" % filePath)
 taglib_tag_free_strings()
 taglib_file_free(file)

# @@@@@@@@@@@@@@@@@@@@@@@@
# String Reformating (LP Timestamp)
# @@@@@@@@@@@@@@@@@@@@@@@@
proc getLastPlayedStr* (lpStamp: string): string =
 result = ""
 try:
  if lpStamp == "0000-00-00 00:00:00":
   result = "never before"
   return

  var
   parTimeInfo: TimeInfo
   curTime: Time = getTime()
   curGMT = getGMTime(curTime)
   lpTime: Time
   Year,Month,Week,Day,Hour,Min,Sec: int = 0

  parTimeInfo = times.parse(lpStamp,"yyyy-MM-dd HH:mm:ss")
  lpTime = timeInfoToTime(parTimeInfo)
  let utcTime = timeInfoToTime(curGMT)
  let timeDiff = (int)(utcTime - lpTime)

  Year = timeDiff div 31557600
  Month = timeDiff mod 31557600
  Week = Month mod 2629800
  Month = Month div 2629800
  Day = Week mod 604800
  Week = Week div 604800
  Hour = Day mod 86400
  Day = Day div 86400
  Min = Hour mod 3600
  Hour = Hour div 3600
  Sec = Min mod 60
  Min = Min div 60

  if Year > 0:
   result.add("$1 year$2 " % [$Year, if Year == 1: "" else: "s"])
  if Month > 0:
   result.add("$1 month$2 " % [$Month, if Month == 1: "" else: "s"])
  if Week > 0:
   result.add("$1 week$2 " % [$Week, if Week == 1: "" else: "s"])
  if Day > 0:
   result.add("$1 day$2 " % [$Day, if Day == 1: "" else: "s"])
  if Hour > 0:
   result.add("$1 hour$2 " % [$Hour, if Hour == 1: "" else: "s"])
  if Min > 0:
   result.add("$1 minute$2 " % [$Min, if Min == 1: "" else: "s"])
  if Sec > 0:
   result.add("$1 second$2 " % [$Sec, if Sec == 1: "" else: "s"])
 except:
  logEvent(true,"***Error: @getLastPlayedStr '$1'" % getCurrentExceptionMsg())
