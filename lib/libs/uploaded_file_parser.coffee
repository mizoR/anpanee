#!/bin/env coffee

module.exports = class UploadedFileParser
  success: null
  error: null
  parse:(req) ->
    @success('filename', 'binarydata')
    
