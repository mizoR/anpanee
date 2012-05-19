#!/bin/env coffee

module.exports = class UploadedFileParser
  parse:(req, success) ->
    error = @error
    headerFlag = true
    header = ''
    body = ''
    name = ''
    contentType = req.headers['content-type']
    boundary = contentType.split('; ')[1].split('=')[1]
    req.on 'data', (raw) ->
      i = 0
      # for header
      while (i < raw.length and headerFlag)
        chars = raw.slice(i, i+4).toString()
        if chars == '\r\n\r\n'
          headerFlag = false
          header = raw.slice(0, i+4).toString()
          name = (/filename="(.*)"/m).exec(header)[1]
          i += 4
        else
          i += 1
      # for body
      while i < raw.length
        body += raw.toString('binary', i, raw.length)
        i = raw.length
      return
    req.on 'end', () ->
      body = body.slice(0, body.length - (boundary.length + 8))
      success(name, body)
      return
    return
