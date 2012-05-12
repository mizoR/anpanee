#!/bin/env coffee

express = require 'express'
Sequelize = require 'sequelize'
fs = require 'fs'
crypto = require 'crypto'

sequelize = new Sequelize '', '', '',
  dialect: 'sqlite'
  storage: './db/development.sqlite3'

ConvertInformation = sequelize.define 'ConvertInformation',
  id: { type: Sequelize.INTEGER, allowNull: false, autoIncrement: true, defaultValue: 1 }
  status: { type: Sequelize.STRING, allowNull: false }
  ticketCode: { type: Sequelize.STRING, allowNull: false, unique: true }
  fileName: { type: Sequelize.STRING, allowNull: false }
  srcFile: { type: Sequelize.STRING, allowNull: true, unique: true }
  dstFile: { type: Sequelize.STRING, allowNull: true, unique: true }
  pubFile: { type: Sequelize.STRING, allowNull: true, unique: true }
sequelize.sync()

app = express.createServer()

app.get '/', (req,res) ->
  res.send 'Hello World'

app.post '/ticket', (req, res) ->
  headerFlag = true
  header = ''
  body = ''
  fileName = ''
  content_type = req.headers['content-type']
  boundary = content_type.split('; ')[1].split('=')[1]
  req.on 'data', (raw) ->
    i = 0
    while i < raw.length
      if headerFlag
        chars = raw.slice(i, i+4).toString()
        if chars == '\r\n\r\n'
          headerFlag = false
          header = raw.slice(0, i+4).toString()
          fileName = (/filename="(.*)"/m).exec(header)[1]
          i += 4
        else
          i += 1
      else
        body += raw.toString('binary', i, raw.length)
        i = raw.length
  req.on 'end', () ->
    body = body.slice(0, body.length - (boundary.length + 8))
    key = ((new Date).toString() + (Math.random()).toString())
    ticketCode = crypto.createHash('md5').update(key).digest('hex')
    hashedFileName = crypto.createHash('md5').update(key + fileName).digest('hex')
    srcFile = hashedFileName + '.mp4'
    dstFile = hashedFileName + '.m4a'
    pubFile = hashedFileName + '.m4a'
    fs.writeFileSync('./tmp/src/' + srcFile, body, 'binary')
    convertInformation = ConvertInformation.build
      status: 'Progressing'
      ticketCode: ticketCode
      fileName: fileName
      srcFile:  srcFile
      dstFile:  dstFile
      pubFile:  pubFile
    result = convertInformation.save()
    result.success ->
      console.log('Success')
      res.send({status:'OK', ticketCode: ticketCode})
    result.error ->
      console.log(result)
      res.send({status:'NG'})

app.get '/progress/:ticket_code', (req, res) ->
  json = { status: 'Progressing', percentage: 80 }
  json = { status: 'Completed', url:'http://example.com/oieafnboigwuior40f434rt3h53y.m4a' }
  res.send(json)

app.listen 3000

