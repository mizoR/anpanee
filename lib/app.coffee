#!/bin/env coffee

fs      = require 'fs'
util    = require 'util'
async   = require 'async'
config  = require 'config'
ffmpeg  = require 'basicFFmpeg'
express = require 'express'
md5     = require './libs/md5'
ConvertInformation = require './models/convert_information'
UploadedFileParser = require './libs/uploaded_file_parser'

convertStatus = config.ConvertStatus
filePath      = config.FilePath
fileValid     = config.FileValid

app = express.createServer()

app.get '/', (req,res) ->
  res.send { status: 'ServerListened' }
  return

app.post '/', (req, res) ->
  async.waterfall [
    (callback) ->
      # アップロードデータパース
      parser = new UploadedFileParser
      parser.parse req, (name, binary) ->
        callback(null, name, binary)
        return
      return
    , (name, binary, callback) ->
      #  変換チケット生成
      if binary.length >= fileValid.maxSize
        callback('Uploaded file size is so large.')
        return
      date = new Date
      rand = Math.random().toString()
      ticketCode = md5.digestHex(date + rand)
      hashedFileName = md5.digestHex(ticketCode + rand)
      srcFilePath = util.format(filePath.src, hashedFileName)
      fs.writeFile srcFilePath, binary, 'binary', (err) ->
        if err
          callback(err)
        else
          callback(null, ticketCode, name, hashedFileName)
        return
      return
    , (ticketCode, fileName, hashedFileName, callback) ->
      #  変換チケット保存
      info = ConvertInformation.build
        status: convertStatus.waiting
        ticketCode: ticketCode
        fileName: fileName
        srcFile:  util.format(filePath.src, hashedFileName)
        dstFile:  util.format(filePath.dst, hashedFileName)
      result = info.save()
      result.success ->
        res.send({status:'OK', ticketCode: ticketCode})
        callback(null, info)
        return
      result.error ->
        callback('ticket creation error')
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
        callback('status change error (to "Processing")')
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
      processor.on 'success', (retcode, signal) ->
        callback(null, info)
        return
      processor.on 'failure', (retcode, signal) ->
        callback('process failure')
        return
      processor.on 'timeout', (processor) ->
        processor.terminate()
        callback('timeout error')
        return
      processor.execute()
      return
    , (info, callback) ->
      info.status = convertStatus.finished
      result = info.save()
      result.success ->
        return
      result.error ->
        callback('status change error (to "Finish")')
        return
      return
  ], (err, info) ->
    if err
      console.log(err)
      return
    else
      info.status = convertStatus.error
      result = info.save()
      result.success ->
        console.log('status change success (to "Error")')
        return
      result.error ->
        console.log('status change error (to "Error")')
        return
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
        json = { status: info.status }
      when convertStatus.error
        json = { status: info.error }
    res.send(json)
    return
  result.error () ->
    json = { status: 'RecordNotFound' }
    res.send(json)
    return
  return

app.get '/audio/:ticketCode', (req, res) ->
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

