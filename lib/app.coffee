#!/bin/env coffee

express = require 'express'
async = require 'async'
fs = require 'fs'
ffmpeg = require 'basicFFmpeg'
md5 = require './libs/md5'
util = require 'util'
config = require 'config'
convertStatus = config.ConvertStatus
filePath = config.FilePath

app = express.createServer()
ConvertInformation = require './models/convert_information'
UploadedFileParser = require './libs/uploaded_file_parser'

app.get '/', (req,res) ->
  res.send 'Hello World'

app.post '/ticket', (req, res) ->
  async.waterfall [
    (callback) ->
      parser = new UploadedFileParser
      parser.parse req, (name, binary) ->
        callback(null, name, binary)
        return
      return
    , (name, binary, callback) ->
      date = new Date
      rand = Math.random().toString()
      ticketCode = md5.digestHex(date + rand)
      hashedFileName = md5.digestHex(ticketCode + rand)
      srcFilePath = util.format(filePath.src, hashedFileName)
      fs.writeFile(srcFilePath, binary, 'binary', (err) ->
        callback(err) if err
        callback(null, ticketCode, name, hashedFileName)
      )
    , (ticketCode, fileName, hashedFileName, callback) ->
      srcFilePath = util.format(filePath.src, hashedFileName)
      dstFilePath = util.format(filePath.dst, hashedFileName)
      pubFilePath = util.format(filePath.pub, hashedFileName)
      info = ConvertInformation.build
        status: convertStatus.waiting
        ticketCode: ticketCode
        fileName: fileName
        srcFile:  srcFilePath
        dstFile:  dstFilePath
        pubFile:  pubFilePath
      info.save().success ->
        res.send({status:'OK', ticketCode: ticketCode})
        callback(null, info)
        return
      return
    , (info, callback) ->
      info.status = convertStatus.processing
      info.save().success ->
        callback(null, info)
    , (info, callback) ->
      inputStream = fs.createReadStream(info.srcFile)
      outputStream = fs.createWriteStream(info.dstFile)
      processor = ffmpeg.createProcessor({
        inputStream: inputStream,
        outputStream: outputStream,
        emitInputAudioCodecEvent: true,
        emitInfoEvent: true,
        emitProgressEvent: true,
        niceness: 10,
        timeout: 10 * 60 * 1000,
        arguments: { '-vn': null, '-ar': 44100, '-ab': '128k', '-acodec': 'libfaac', '-f': 'adts' }
      })
      processor.on 'success', (retcode, signal) ->
        callback(null, info)
      processor.on 'failure', (retcode, signal) ->
        callback('process failure')
      processor.on 'timeout', (processor) ->
        processor.terminate();
        callback('timeout error');
      processor.execute()
      return
    , (info, callback) ->
      info.status = convertStatus.finished
      info.save().success ->
        console.log('Finished.')
  ], (err) ->
    console.log(err) if err
    return
  return

app.get '/progress/:ticketCode', (req, res) ->
  result = ConvertInformation.find({where: {ticketCode: req.params.ticketCode}})
  result.success (info) ->
    switch info.status
      when convertStatus.waiting
        json = { status: info.status }
      when convertStatus.processing
        json = { status: info.status }
      when convertStatus.finished
        json = { status: info.status, path:info.pubFile }
      else
        callback('unexpected status')
    res.send(json)
  result.error () ->
    json = { status: 'RecordNotFound' }
    res.send(json)

app.listen 3000

