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

app = express.createServer()

app.get '/', (req,res) ->
  res.send { status: 'ServerListened' }
  return

app.post '/ticket', (req, res) ->
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
      #  変換ステータス変更
      info.status = convertStatus.processing
      info.save().success ->
        callback(null, info)
        return
      return
    , (info, callback) ->
      #  変換処理
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
      # 公開ファイルの保存
      fs.rename info.dstFile, info.pubFile, (err) ->
        if err
          callback(err)
        else
          callback(null, info)
        return
      return
    , (info, callback) ->
      info.status = convertStatus.finished
      info.save().success ->
        console.log('Finished.')
        return
      return
  ], (err, info) ->
    if err
      console.log(err)
    else
      info.status = convertStatus.error
      info.save().success ->
        console.log('Saved error status')
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
        json = { status: info.status, path:info.pubFile }
      when convertStatus.error
        json = { status: info.error }
    res.send(json)
    return
  result.error () ->
    json = { status: 'RecordNotFound' }
    res.send(json)
    return

app.listen 3000

