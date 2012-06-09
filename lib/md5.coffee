#!/bin/env coffee

crypto = require 'crypto'

module.exports = digestHex:(str) ->
  md5 = crypto.createHash('md5')
  md5.update(str, 'utf8')
  return md5.digest('hex')

