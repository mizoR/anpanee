#!/bin/env coffee

config = require 'config'
databaseConfig = config.Database

Sequelize = require 'sequelize'

sequelize = new Sequelize '', '', '',
  dialect: databaseConfig.type
  storage: databaseConfig.filePath

module.exports = ConvertInformation = sequelize.define 'ConvertInformation',
  id: { type: Sequelize.INTEGER, allowNull: false, autoIncrement: true, defaultValue: 1 }
  status: { type: Sequelize.STRING, allowNull: false }
  ticketCode: { type: Sequelize.STRING, allowNull: false, unique: true }
  fileName: { type: Sequelize.STRING, allowNull: false }
  srcFile: { type: Sequelize.STRING, allowNull: true, unique: true }
  dstFile: { type: Sequelize.STRING, allowNull: true, unique: true }

sequelize.sync()

