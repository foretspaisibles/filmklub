s/'//g
/^File/{
  d
}
/^Track/{
  s/ ID /|/
  s/: /|/
  s/ (\(.*\))/|\1/
}
/^Attachment/{
  s/ ID /|/
  s/: type /|/
  s/. size /|/
  s/ bytes, file name /|/
}
