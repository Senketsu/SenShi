type
 StringChannel* = Channel[string]

 PPathsCfg* = tuple
  dir, sb, ib, manDb, manTopic: string

 PPaths* = tuple
  home, senshi, log, data, fpDB, fpIceOut: string
  cfg: PPathsCfg

 TGetVal* =  tuple
  hasData: bool
  data: string

 TSplitFile* = tuple
  dir, name, ext: string

 PlaysStats* = tuple
  id,trackid,meta,iPlays,iLen,lp: string

 UserQuery* = tuple
  user, query: string

