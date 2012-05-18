module.exports =
  Database:
    filePath: './db/development.sqlite3'
    type: 'sqlite'
  ConvertStatus:
    waiting:     'Waiting'
    processing:  'Processing'
    finished:    'Finished'
  FilePath:
    src: './tmp/src/%s.mp4'
    dst: './tmp/dst/%s.m4a'
    pub: './public/%s.m4a'

