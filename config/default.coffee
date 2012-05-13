module.exports =
  Database:
    filePath: './db/development.sqlite3'
    type: 'sqlite'
  ConvertStatus:
    waiting:     'Waiting'
    progressing: 'Progressing'
    finished:    'Finished'
  FilePath:
    src:
      mp4: './tmp/src/%s.mp4'
      m4a: './tmp/src/%s.m4a'
    dst:
      mp4: './tmp/src/%s.mp4'
      m4a: './tmp/src/%s.m4a'
    pub:
      mp4: './public/%s.mp4'
      m4a: './public/%s.m4a'

