#!/bin/env coffee

fs      = require 'fs'
util    = require 'util'
async   = require 'async'
config  = require 'config'
ffmpeg  = require 'basicFFmpeg'
express = require 'express'
md5     = require './lib/md5'
ConvertInformation = require './models/convert_information'
UploadedFileParser = require './lib/uploaded_file_parser'

convertStatus = config.ConvertStatus
filePath      = config.FilePath
fileValid     = config.FileValid

app = express.createServer()

app.get '/', (req,res) ->
  res.send { status: 'ServerListened' }
  return

app.post '/', (req, res) ->
  parser = new UploadedFileParser
  parser.parse req, (name, binary) ->
    async.waterfall [
      (callback) ->
        #  変換チケット保存
        ticketCode = md5.digestHex((new Date) + Math.random().toString())
        hashedFileName = md5.digestHex(ticketCode + Math.random().toString())
        info = ConvertInformation.build
          status: convertStatus.preparing
          ticketCode: ticketCode
          fileName: name
          srcFile:  util.format(filePath.src, hashedFileName)
          dstFile:  util.format(filePath.dst, hashedFileName)
        result = info.save()
        result.success ->
          res.send({status:'OK', ticketCode: ticketCode})
          callback(null, info)
          return
        result.error ->
          callback(['Database error.(cannot save ticket code)', info])
          return
        return
      , (info, callback) ->
        #  変換チケット生成
        if binary.length >= fileValid.maxSize
          callback(['File upload error.(too large)', info])
          return
        fs.writeFile info.srcFile, binary, 'binary', (err) ->
          if err
            callback([err, info])
          else
            callback(null, info)
          return
        return
      , (info, callback) ->
        #  変換ステータス変更
        info.status = convertStatus.processing
        result = info.save()
        result.success ->
          callback(null, info)
          return
        result.error ->
          callback(['Database error.(to "Processing")', info])
          return
        return
      , (info, callback) ->
        #  変換処理
        processor = ffmpeg.createProcessor({
          inputStream:  fs.createReadStream(info.srcFile),
          outputStream: fs.createWriteStream(info.dstFile),
          emitInputAudioCodecEvent: true,
          emitInfoEvent: true,
          emitProgressEvent: true,
          niceness: 10,
          timeout: 10 * 60 * 1000,
          arguments: { '-vn': null, '-ar': 44100, '-ab': '128k', '-acodec': 'libfaac', '-f': 'adts' }
        })
        processor.on 'progress', (bytes) ->
          return
        processor.on 'success', (retcode, signal) ->
          callback(null, info)
          return
        processor.on 'failure', (retcode, signal) ->
          callback(['FFmpeg error.(process failure)', info])
          return
        processor.on 'timeout', (processor) ->
          processor.terminate()
          callback(['FFmpeg error.(timeout error)', info])
          return
        processor.execute()
        return
      , (info, callback) ->
        info.status = convertStatus.finished
        result = info.save()
        result.success ->
          return
        result.error ->
          callback(['Database error.(to "Finish")', info])
          return
        return
    ], (params) ->
      [err, info] = params
      console.log(err) if err
      if info
        info.status = convertStatus.error
        result = info.save()
        result.success ->
          return
        result.error ->
          console.log('Database error.(to "Error")')
          return
      return
    return
  return
  
app.get '/tickets/:ticketCode/progress', (req, res) ->
  result = ConvertInformation.find({where: {ticketCode: req.params.ticketCode}})
  result.success (info) ->
    switch info.status
      when convertStatus.waiting
        json = { status: info.status }
      when convertStatus.processing
        json = { status: info.status }
      when convertStatus.finished
        json = { status: info.status }
      when convertStatus.error
        json = { status: info.status }
    res.send(json)
    return
  result.error () ->
    json = { status: 'RecordNotFound' }
    res.send(json)
    return
  return

app.get '/tickets/:ticketCode/audio.m4a', (req, res) ->
  result = ConvertInformation.find({where: {ticketCode: req.params.ticketCode, status: convertStatus.finished}})
  result.success (info) ->
    unless info
      # 404 not found
      res.send('AudioNotFound', 404)
      return
    fs.readFile info.dstFile, (err, binary) ->
      if err
        console.log(err)
        res.send(err, 'Server Error', 500)
        return
      else
        res.send(binary, {'Content-Type': 'audio/mp4'}, 200)
        return
      return
    return
  return
  
app.listen 3000

