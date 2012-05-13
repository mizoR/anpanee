#!/bin/env coffee

express = require 'express'
async = require 'async'
fs = require 'fs'
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
      srcFilePath = util.format(filePath.src.mp4, hashedFileName)
      fs.writeFile(srcFilePath, binary, 'binary', (err) ->
        callback(err) if err
        callback(null, ticketCode, name, hashedFileName)
      )
    , (ticketCode, fileName, hashedFileName, callback) ->
      srcFilePath = util.format(filePath.src.mp4, hashedFileName)
      dstFilePath = util.format(filePath.dst.m4a, hashedFileName)
      pubFilePath = util.format(filePath.pub.m4a, hashedFileName)
      convertInformation = ConvertInformation.build
        status: convertStatus.waiting
        ticketCode: ticketCode
        fileName: fileName
        srcFile:  srcFilePath
        dstFile:  dstFilePath
        pubFile:  pubFilePath
      convertInformation.save().success ->
        res.send({status:'OK', ticketCode: ticketCode})
        callback(null, convertInformation)
        return
      return
    , (convertInformation) ->
      console.log('start file encoding..')
      return
  ], (err) ->
    console.log(err) if err
    return
  return

app.get '/progress/:ticketCode', (req, res) ->
  result = ConvertInformation.find({where: {ticketCode: req.params.ticketCode}})
  result.success (convertInformation) ->
    json = { status: convertInformation.status, percentage: 80 }
    res.send(json)
  result.error () ->
    json = { status: 'RecordNotFound' }
    res.send(json)

app.listen 3000

