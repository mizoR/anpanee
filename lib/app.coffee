#!/bin/env coffee

express = require 'express'
async = require 'async'
fs = require 'fs'
md5 = require './libs/md5'
config = require 'config'
convertStatus = config.ConvertStatus

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
      fs.writeFile('./tmp/src/' + hashedFileName + '.mp4', binary, 'binary', (err) ->
        callback(err) if err
        callback(null, ticketCode, name, hashedFileName)
      )
    , (ticketCode, fileName, hashedFileName, callback) ->
      console.log(ticketCode)
      console.log(hashedFileName)
      convertInformation = ConvertInformation.build
        status: convertStatus.waiting
        ticketCode: ticketCode
        fileName: fileName
        srcFile:  hashedFileName + '.mp4'
        dstFile:  hashedFileName + '.m4a'
        pubFile:  hashedFileName + '.m4a'
      console.log(ticketCode)
      console.log(hashedFileName)
      convertInformation.save().success ->
        console.log('Success')
        res.send({status:'OK', ticketCode: ticketCode})
        return
      return
  ], (err) ->
    console.log(err) if err
    return
  return

app.get '/progress/:ticketCode', (req, res) ->
  console.log(req.params.ticketCode)
  result = ConvertInformation.find({where: {ticketCode: req.params.ticketCode}})
  result.success (convertInformation) ->
    json = { status: convertInformation.status, percentage: 80 }
    res.send(json)
  result.error () ->
    json = { status: 'RecordNotFound' }
    res.send(json)

app.listen 3000

