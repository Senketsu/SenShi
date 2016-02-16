## Super minimal wrapper since im lazy person - Senketsu
{.deadCodeElim: on.}
{.push gcsafe.}
when defined(Windows):
 const LibName* = "libtag_c.dll"
elif defined(Linux):
 const LibName* = "libtag_c.so"
elif defined(macosx):
 const LibName* = "libtag_c.dylib"

type
 TagLib_File* = ptr object
 TagLib_Tag* = ptr object
 TagLib_AudioProperties* = ptr object

proc taglib_set_strings_unicode*(uni: bool)
  {.cdecl, dynlib: LibName, importc:"taglib_set_strings_unicode".}

proc taglib_file_new*(path: cstring): TagLib_File
  {.cdecl, dynlib: LibName, importc:"taglib_file_new".}

proc taglib_file_free*(self: TagLib_File)
  {.cdecl, dynlib: LibName, importc:"taglib_file_free".}

proc taglib_file_tag*(self: TagLib_File): TagLib_Tag
  {.cdecl, dynlib: LibName, importc:"taglib_file_tag".}

proc taglib_file_audioproperties*(self: TagLib_File):TagLib_AudioProperties
  {.cdecl, dynlib: LibName, importc:"taglib_file_audioproperties".}

proc taglib_audioproperties_length*(self: TagLib_AudioProperties): int
  {.cdecl, dynlib: LibName, importc:"taglib_audioproperties_length".}

proc taglib_tag_artist*(self: TagLib_Tag): cstring
  {.cdecl, dynlib: LibName, importc:"taglib_tag_artist".}

proc taglib_tag_title*(self: TagLib_Tag): cstring
  {.cdecl, dynlib: LibName, importc:"taglib_tag_title".}

proc taglib_tag_album*(self: TagLib_Tag): cstring
  {.cdecl, dynlib: LibName, importc:"taglib_tag_album".}

proc taglib_tag_comment*(self: TagLib_Tag): cstring
  {.cdecl, dynlib: LibName, importc:"taglib_tag_comment".}

proc taglib_tag_free_strings*()
  {.cdecl, dynlib: LibName, importc:"taglib_tag_free_strings".}

