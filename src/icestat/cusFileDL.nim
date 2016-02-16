import strutils, strtabs, uri, net, os, parseutils

const defUserAgent* = "Custom Nim httpclient/0.1"

type
  Response* = tuple[
    version: string,
    status: string,
    headers: StringTableRef,
    body: string]

  ProtocolError* = object of IOError   ## exception that is raised when server
                                       ## does not conform to the implemented
                                       ## protocol

  HttpRequestError* = object of IOError ## Thrown in the ``getContent`` proc
                                        ## and ``postContent`` proc,
                                        ## when the server returns an error



proc httpError(msg: string) =
  var e: ref ProtocolError
  new(e)
  e.msg = msg
  raise e

proc fileError(msg: string) =
  var e: ref IOError
  new(e)
  e.msg = msg
  raise e


proc parseChunks(s: Socket, timeout: int): string =
  result = ""
  var ri = 0
  while true:
    var chunkSizeStr = ""
    var chunkSize = 0
    s.readLine(chunkSizeStr, timeout)
    var i = 0
    if chunkSizeStr == "":
      httpError("Server terminated connection prematurely")
    while true:
      case chunkSizeStr[i]
      of '0'..'9':
        chunkSize = chunkSize shl 4 or (ord(chunkSizeStr[i]) - ord('0'))
      of 'a'..'f':
        chunkSize = chunkSize shl 4 or (ord(chunkSizeStr[i]) - ord('a') + 10)
      of 'A'..'F':
        chunkSize = chunkSize shl 4 or (ord(chunkSizeStr[i]) - ord('A') + 10)
      of '\0':
        break
      of ';':
        # http://tools.ietf.org/html/rfc2616#section-3.6.1
        # We don't care about chunk-extensions.
        break
      else:
        httpError("Invalid chunk size: " & chunkSizeStr)
      inc(i)
    if chunkSize <= 0:
      s.skip(2, timeout) # Skip \c\L
      break
    result.setLen(ri+chunkSize)
    var bytesRead = 0
    while bytesRead != chunkSize:
      let ret = recv(s, addr(result[ri]), chunkSize-bytesRead, timeout)
      ri += ret
      bytesRead += ret
    s.skip(2, timeout) # Skip \c\L
    # Trailer headers will only be sent if the request specifies that we want
    # them: http://tools.ietf.org/html/rfc2616#section-3.6.1

proc parseBody(s: Socket, headers: StringTableRef, timeout: int): string =
  result = ""
  if headers.getOrDefault"Transfer-Encoding" == "chunked":
    result = parseChunks(s, timeout)
  else:
    # -REGION- Content-Length
    # (http://tools.ietf.org/html/rfc2616#section-4.4) NR.3
    var contentLengthHeader = headers.getOrDefault"Content-Length"
    if contentLengthHeader != "":
      var length = contentLengthHeader.parseint()
      if length > 0:
        result = newString(length)
        var received = 0
        while true:
          if received >= length: break
          let r = s.recv(addr(result[received]), length-received, timeout)
          if r == 0: break
          received += r
        if received != length:
          httpError("Got invalid content length. Expected: " & $length &
                    " got: " & $received)
    else:
      # (http://tools.ietf.org/html/rfc2616#section-4.4) NR.4 TODO

      # -REGION- Connection: Close
      # (http://tools.ietf.org/html/rfc2616#section-4.4) NR.5
      if headers.getOrDefault"Connection" == "close":
        var buf = ""
        while true:
          buf = newString(4000)
          let r = s.recv(addr(buf[0]), 4000, timeout)
          if r == 0: break
          buf.setLen(r)
          result.add(buf)


proc parseResponse(s: Socket, getBody: bool, timeout: int): Response =
  var parsedStatus = false
  var linei = 0
  var fullyRead = false
  var line = ""
  result.headers = newStringTable(modeCaseInsensitive)
  while true:
    line = ""
    linei = 0
    s.readLine(line, timeout)
    if line == "": break # We've been disconnected.
    if line == "\c\L":
      fullyRead = true
      break
    if not parsedStatus:
      # Parse HTTP version info and status code.
      var le = skipIgnoreCase(line, "HTTP/", linei)
      if le <= 0: httpError("invalid http version")
      inc(linei, le)
      le = skipIgnoreCase(line, "1.1", linei)
      if le > 0: result.version = "1.1"
      else:
        le = skipIgnoreCase(line, "1.0", linei)
        if le <= 0: httpError("unsupported http version")
        result.version = "1.0"
      inc(linei, le)
      # Status code
      linei.inc skipWhitespace(line, linei)
      result.status = line[linei .. ^1]
      parsedStatus = true
    else:
      # Parse headers
      var name = ""
      var le = parseUntil(line, name, ':', linei)
      if le <= 0: httpError("invalid headers")
      inc(linei, le)
      if line[linei] != ':': httpError("invalid headers")
      inc(linei) # Skip :

      result.headers[name] = line[linei.. ^1].strip()
  if not fullyRead:
    httpError("Connection was closed before full request has been made")
  if getBody:
    result.body = parseBody(s, result.headers, timeout)
  else:
    result.body = ""

type
  HttpMethod* = enum  ## the requested HttpMethod
    httpHEAD,         ## Asks for the response identical to the one that would
                      ## correspond to a GET request, but without the response
                      ## body.
    httpGET,          ## Retrieves the specified resource.
    httpPOST,         ## Submits data to be processed to the identified
                      ## resource. The data is included in the body of the
                      ## request.
    httpPUT,          ## Uploads a representation of the specified resource.
    httpDELETE,       ## Deletes the specified resource.
    httpTRACE,        ## Echoes back the received request, so that a client
                      ## can see what intermediate servers are adding or
                      ## changing in the request.
    httpOPTIONS,      ## Returns the HTTP methods that the server supports
                      ## for specified address.
    httpCONNECT       ## Converts the request connection to a transparent
                      ## TCP/IP tunnel, usually used for proxies.

proc request*(url: string, httpMethod: string, extraHeaders = "",
              body = "", timeout = -1, userAgent = defUserAgent): Response =
  ## | Requests ``url`` with the custom method string specified by the
  ## | ``httpMethod`` parameter.
  ## | Extra headers can be specified and must be separated by ``\c\L``
  ## | An optional timeout can be specified in milliseconds, if reading from the
  ## server takes longer than specified an ETimeout exception will be raised.
  var r = parseUri(url)
  var hostUrl = r
  var headers = substr(httpMethod, len("http"))
  # TODO: Use generateHeaders further down once it supports proxies.

  headers.add ' '
  if r.path[0] != '/':
   headers.add '/'
  headers.add(r.path)
  if r.query.len > 0:
   headers.add("?" & r.query)

  headers.add(" HTTP/1.1\c\L")

  if hostUrl.port == "":
    add(headers, "Host: " & hostUrl.hostname & "\c\L")
  else:
    add(headers, "Host: " & hostUrl.hostname & ":" & hostUrl.port & "\c\L")

  if userAgent != "":
    add(headers, "User-Agent: " & userAgent & "\c\L")
  add(headers, extraHeaders)
  add(headers, "\c\L")
  var s = newSocket()
  if s == nil: raiseOSError(osLastError())
  var port = net.Port(80)
  if r.scheme == "https":
   raise newException(HttpRequestError,
                "SSL support is not available. Cannot connect over SSL.")
  if r.port != "":
    port = net.Port(r.port.parseInt)

  if timeout == -1:
    s.connect(r.hostname, port)
  else:
    s.connect(r.hostname, port, timeout)
  s.send(headers)
  if body != "":
    s.send(body)

  result = parseResponse(s, httpMethod != "httpHEAD", timeout)
  s.close()


proc request*(url: string, httpMethod = httpGET, extraHeaders = "",
              body = "", timeout = -1, userAgent = defUserAgent): Response =
  ## | Requests ``url`` with the specified ``httpMethod``.
  ## | Extra headers can be specified and must be separated by ``\c\L``
  ## | An optional timeout can be specified in milliseconds, if reading from the
  ## server takes longer than specified an ETimeout exception will be raised.
  result = request(url, $httpMethod, extraHeaders, body, timeout,
                   userAgent)

proc redirection(status: string): bool =
  const redirectionNRs = ["301", "302", "303", "307"]
  for i in items(redirectionNRs):
    if status.startsWith(i):
      return true

proc getNewLocation(lastUrl: string, headers: StringTableRef): string =
  result = headers.getOrDefault"Location"
  if result == "": httpError("location header expected")
  # Relative URLs. (Not part of the spec, but soon will be.)
  let r = parseUri(result)
  if r.hostname == "" and r.path != "":
    let origParsed = parseUri(lastUrl)
    result = origParsed.hostname & "/" & r.path

proc get*(url: string, extraHeaders = "", maxRedirects = 5,
          timeout = -1, userAgent = defUserAgent): Response =
  ## | GETs the ``url`` and returns a ``Response`` object
  ## | This proc also handles redirection
  ## | Extra headers can be specified and must be separated by ``\c\L``.
  ## | An optional timeout can be specified in milliseconds, if reading from the
  ## server takes longer than specified an ETimeout exception will be raised.
  result = request(url, httpGET, extraHeaders, "", timeout, userAgent)
  var lastURL = url
  for i in 1..maxRedirects:
    if result.status.redirection():
      let redirectTo = getNewLocation(lastURL, result.headers)
      result = request(redirectTo, httpGET, extraHeaders, "", timeout, userAgent)
      lastUrl = redirectTo

proc getContent*(url: string, extraHeaders = "", maxRedirects = 5,
                 timeout = -1, userAgent = defUserAgent): string =
  ## | GETs the body and returns it as a string.
  ## | Raises exceptions for the status codes ``4xx`` and ``5xx``
  ## | Extra headers can be specified and must be separated by ``\c\L``.
  ## | An optional timeout can be specified in milliseconds, if reading from the
  ## server takes longer than specified an ETimeout exception will be raised.
  var r = get(url, extraHeaders, maxRedirects, timeout, userAgent)
  if r.status[0] in {'4','5'}:
    raise newException(HttpRequestError, r.status)
  else:
    return r.body

proc dlFile*(url: string, outputFilename: string,
                   timeout = -1, userAgent = defUserAgent) =
  ## | Downloads ``url`` and saves it to ``outputFilename``
  ## | An optional timeout can be specified in milliseconds, if reading from the
  ## server takes longer than specified an ETimeout exception will be raised.
  var f: File
  if open(f, outputFilename, fmWrite):
    f.write(getContent(url, timeout = timeout, userAgent = userAgent))
    f.close()
  else:
    fileError("Unable to open file")
