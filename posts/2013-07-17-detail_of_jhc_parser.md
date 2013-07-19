---
title: (作成中) Detail of jhc's parser.
description: パーサを理解してコンパイルパイプライン上段を改造しまくるでゲソ!
tags: jhc, ajhc, parser
---

## 全体

~~~
loadModules
=> fetchSource :: Opt -> IORef Done -> [FilePath] -> Maybe (Module,SrcLoc) -> IO Module
   => parseHsSource :: Opt -> FilePath -> LBS.ByteString -> IO (HsModule,LBS.ByteString)
      => runParserWithMode :: ParseMode -> P a -> String -> ([Warning],ParseResult a)
         => parse :: P HsModule
~~~

このparseという関数は src/FrontEnd/HsParser.y で定義されていて、


## src/Ho/Build.hs
## src/Ho/ReadSource.hs
## src/FrontEnd/HsParser.y
## src/FrontEnd/ParseUtils.hs
