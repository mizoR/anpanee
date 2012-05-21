module.exports =
  Database:
    filePath: './db/development.sqlite3'
    type: 'sqlite'
  ConvertStatus:
    preparing:   'Preparing'
    processing:  'Processing'
    finished:    'Finished'
    error:       'Error'
  FilePath:
    src: './tmp/src/%s.mp4'
    dst: './tmp/dst/%s.m4a'
    pub: './public/%s.m4a'
  FileValid:
    maxSize: 1000000000000
