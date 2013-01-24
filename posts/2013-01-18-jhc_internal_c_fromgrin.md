---
title: jhcコンパイルパイプライン全体
description: jhcの概要を掴むでゲッソ!
tags: haskell, jhc, c, internal, compiler
---

jhcの全体像を探るためにコールグラフを書いてみたでゲソ。

~~~
main
=> processFiles
   => (_, cho) <- parseFiles
      => loadModules
      => processCug
      => typeCheckGraph
         => parseHsSource
         => doModules
            => determineExports
            => tiModules # xxx 要調査
               => processModule
                  => renameModule
                     => FrontEnd.Rename.runRename
                        => desugarHsModule
                           => desugarDecl
                        => FrontEnd.Rename.renameDecls
                        => driftDerive
      => compileCompNode # xxx 要調査
         => processInitialHo
         => processDecls
   => processCollectedHo cho
      => dataTable = choDataTable cho
      => combinators = values $ choCombinators cho
      => evaluate dataTable
      => evaluate combinators
      => prog = programUpdate E.Program.program {
            progCombinators = combinators,
            progDataTable = dataTable
            }
      => compileWholeProgram prog
      => compileToGrin prog
         => Grin.FromE.compile
         => transformGrin # 色々な種類の変換があるみたい
         => explicitRecurse
         => lintCheckGrin
         => grinSpeculate
         => createEvalApply
         => twiddleGrin
         => storeAnalyze
         => compileGrinToC
            => compileGrin
            => System.system comm # gccでコンパイル
~~~


その型はイカの通りでゲソ。

~~~ {.haskell}
parseFiles :: Opt -> [FilePath] -> [String] -> [Either Module FilePath] -> (CollectedHo -> Ho -> IO CollectedHo) -> (CollectedHo -> Ho -> TiData -> IO (CollectedHo,Ho)) -> IO (CompNode,CollectedHo)
loadModules :: Opt -> [FilePath] -> [String] -> SrcLoc -> [Either Module FilePath] -> IO (Map.Map SourceHash (Module,[(Module,SrcLoc)]),HoHash,CompUnitGraph)
processCug :: CompUnitGraph -> HoHash -> IO CompNode
typeCheckGraph :: Opt -> CompNode -> IO ()
parseHsSource :: Opt -> FilePath -> LBS.ByteString -> IO (HsModule,LBS.ByteString)
doModules :: HoTcInfo -> [HsModule] -> IO  (HoTcInfo,Tc.TiData)
determineExports :: [(Name,SrcLoc,[Name])] -> [(Module,[Name])] -> [ModInfo]  -> IO [ModInfo]
tiModules ::  HoTcInfo -> [ModInfo] -> IO (HoTcInfo,TiData)
processModule :: FieldMap -> ModInfo -> IO (ModInfo,[Warning])
renameModule :: MonadWarn m => Opt -> FieldMap -> [(Name,[Name])] -> HsModule -> m ((HsModule,[HsDecl]),Map.Map Name Name)
FrontEnd.Rename.runRename :: MonadWarn m => (a -> RM b) -> Opt -> Module -> FieldMap -> [(Name,[Name])] -> a -> m (b,Map.Map Name Name)
desugarHsModule :: HsModule -> HsModule
desugarDecl :: HsDecl -> PatSM [HsDecl]
FrontEnd.Rename.hs.renameDecls :: HsModule -> RM HsModule
driftDerive :: HsModule -> [HsDecl]
compileCompNode :: (CollectedHo -> Ho -> IO CollectedHo) -> (CollectedHo -> Ho -> TiData  -> IO (CollectedHo,Ho)) -> Map.Map SourceHash (Module,[(Module,SrcLoc)]) -> CompNode -> IO CollectedHo
processInitialHo :: CollectedHo -> Ho -> IO CollectedHo
processDecls :: CollectedHo -> Ho -> TiData -> IO (CollectedHo,Ho)
processCollectedHo :: CollectedHo -> IO ()
choDataTable :: CollectedHo -> DataTable
choCombinators :: CollectedHo -> IdMap Comb
evaluate :: Grin -> IO (Val,Stats.Stats)
programUpdate :: Program -> Program
compileWholeProgram :: Program -> IO Program
compileToGrin :: Program -> IO ()
Grin.FromE.compile :: Program -> IO Grin
transformGrin :: TransformParms Grin -> Grin -> IO Grin
explicitRecurse :: Grin -> IO Grin
lintCheckGrin :: Grin -> IO ()
grinSpeculate :: Grin -> IO Grin
createEvalApply :: Grin -> IO Grin
twiddleGrin :: Grin -> Grin
storeAnalyze :: Grin -> IO Grin
compileGrinToC :: Grin -> IO ()
compileGrin :: Grin -> (LBS.ByteString,Requires)
~~~

この結果をふまえて、パイプラインの図を
[An informal graph of the internal code motion in jhc (pdf)](http://repetae.net/computer/jhc/big-picture.pdf)
よりも詳細に図にしてみるでゲソー。
