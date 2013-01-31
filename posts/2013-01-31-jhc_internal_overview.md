---
title: jhcコンパイルパイプラインの全体像
description: jhc内部の概要を掴むでゲッソ!
tags: haskell, jhc, internal, compiler
---

jhcコンパイルパイプラインの図は
[An informal graph of the internal code motion in jhc (pdf)](http://repetae.net/computer/jhc/big-picture.pdf)
にあるんでゲソがどうにも概念寄りで、実際にソースコードのどの箇所で処理を行なっているのか分かり難いでゲソ。
そこで、上記の図よりも実装寄りの図を描いてみたでゲソ。
だいたいさっきのbig-picture.pdfと対応が取れているでゲソ。

![](/draw/2013-01-25-jhc_compile_flow.png)

これで地図が手にはいったので、気になる部分を読もうじゃなイカ。
この図の中で最適化を行なっていそうな3つの関数ソースコードから、
最適化してそうな部分をイカに抜き出してみたでゲソ。

## processDecls関数

~~~ {.haskell}
processDecls :: CollectedHo -> Ho -> TiData -> IO (CollectedHo,Ho)
processDecls cho ho' tiData = do
    let prog = program {
            progDataTable = fullDataTable,
            progExternalNames = choExternalNames cho,
            progModule = head (fsts $ tiDataModules tiData)
            }
    prog <- return prog { progSeasoning = seasoning }
    Identity prog <- return $ programMapDs (\ (t,e) -> return (shouldBeExported (getExports $ hoTcInfo ho') t,e)) $ atomizeApps False (programSetDs ds prog)
    prog <- return $ progCombinators_u (map addRule) prog
    prog <- return $ runIdentity $ annotateProgram (choVarMap cho) (idann theProps) letann lamann prog
    prog <- return $ prog { progEntry = entryPoints `mappend` progSeasoning prog }
    prog <- programPrune prog
    prog <- transformProgram tparms {
        transformCategory = "FloatInward",
        transformOperation = programFloatInward
        } prog
    prog <- programMapProgGroups mempty fint prog
    prog <- etaExpandProg "Init-Big-One" prog { progStats = mempty }
    prog <- transformProgram tparms {
        transformPass = "Init-Big-One",
        transformCategory = "FloatInward",
        transformOperation = programFloatInward
        } prog
    prog <- Demand.analyzeProgram prog
    prog <- simplifyProgram' sopt "Init-Big-One" verbose (IterateMax 4) prog
    prog <- evalStateT (programMapProgGroups mempty optWW prog { progStats = mempty }) (SS.so_boundVars sopt)
    prog <- programPrune prog
    let newHoBuild = (hoBuild ho') {
        hoDataTable = dataTable,
        hoEs = programDs prog,
        hoRules = hoRules (hoBuild ho') `mappend` rules
        }
        newMap = fmap (\c -> Just (EVar $ combHead c)) $ progCombMap prog
    return (updateChoHo $ mempty {
        choHoMap = Map.singleton (hoModuleGroup ho') ho' { hoBuild = newHoBuild},
        choCombinators = fromList $ [ (combIdent c,c) | c <- progCombinators prog ],
        choExternalNames = idMapToIdSet newMap
        } `mappend` cho,ho' { hoBuild = newHoBuild })
~~~

## compileWholeProgram関数

~~~ {.haskell}
    prog <- return $ programUpdate prog {
        progMain   = tvrIdent main,
        progEntry = fromList $ map tvrIdent (main:ffiExportNames),
        progCombinators = emptyComb { combHead = main, combBody = mainv }:map (unsetProperty prop_EXPORTED) (progCombinators prog)
        }
    prog <- transformProgram transformParms {
        transformCategory = "PruneUnreachable",
        transformOperation = evaluate . programPruneUnreachable
        } prog
    prog <- programPrune prog
    prog <- evaluate $ progCombinators_s ([ p | p <- progCombinators prog,
        combHead p `notElem` map combHead cmethods] ++ cmethods) prog
    prog <- annotateProgram mempty (\_ nfo -> return $ unsetProperty prop_INSTANCE nfo)
        letann (\_ nfo -> return nfo) prog
    prog <- transformProgram transTypeAnalyze {
        transformPass = "Main-AfterMethod",
        transformDumpProgress = verbose } prog
    prog <- simplifyProgram SS.emptySimplifyOpts "Main-One" verbose prog
    prog <- etaExpandProg "Main-AfterOne" prog
    prog <- transformProgram transTypeAnalyze {
        transformPass = "Main-AfterSimp", transformDumpProgress = verbose } prog
    prog <- simplifyProgram SS.emptySimplifyOpts "Main-Two" verbose prog
    prog <- return $ runIdentity $ annotateProgram mempty (\_ nfo -> return $
        modifyProperties (flip (foldr S.delete) [prop_HASRULE,prop_WORKER]) nfo)
        letann (\_ -> return) prog
    prog <- simplifyProgram SS.emptySimplifyOpts { SS.so_finalPhase = True }
        "SuperSimplify no rules" verbose prog
    prog <- transformProgram transformParms {
        transformCategory = "BoxifyProgram",
        transformDumpProgress = dump FD.Progress,
        transformOperation = boxifyProgram } prog
    prog <- programPrune prog
    prog <- Demand.analyzeProgram prog
    prog <- return $ E.CPR.cprAnalyzeProgram prog
    prog <- transformProgram transformParms {
        transformCategory = "Boxy WorkWrap",
        transformDumpProgress = dump FD.Progress,
        transformOperation = evaluate . workWrapProgram } prog
    prog <- simplifyProgram SS.emptySimplifyOpts { SS.so_finalPhase = True }
        "SuperSimplify after Boxy WorkWrap" verbose prog
    prog <- return $ runIdentity $ programMapBodies (return . cleanupE) prog
    prog <- transformProgram transformParms {
        transformCategory = "LambdaLift",
        transformDumpProgress = dump FD.Progress,
        transformOperation = lambdaLift } prog
    prog <- Demand.analyzeProgram prog
    prog <- return $ E.CPR.cprAnalyzeProgram prog
    prog <- simplifyProgram SS.emptySimplifyOpts {
        SS.so_postLift = True, SS.so_finalPhase = True } "PostLiftSimplify" verbose prog
    prog <- return $ atomizeApps True prog
~~~

## compileToGrin関数

~~~ {.haskell}
    x <- Grin.FromE.compile prog
    x <- transformGrin simplifyParms x
    x <- explicitRecurse x
    lintCheckGrin x
    x <- transformGrin deadCodeParms x
    x <- transformGrin simplifyParms x
    x <- transformGrin pushParms x
    x <- transformGrin simplifyParms x
    x <- grinSpeculate x
    lintCheckGrin x
    x <- transformGrin deadCodeParms x
    x <- transformGrin simplifyParms x
    x <- transformGrin pushParms x
    x <- transformGrin simplifyParms x
    x <- transformGrin nodeAnalyzeParms x
    x <- transformGrin simplifyParms x
    x <- transformGrin nodeAnalyzeParms x
    x <- transformGrin simplifyParms x
    x <- createEvalApply x
    x <- transformGrin simplifyParms x
    x <- transformGrin devolveTransform x
    x <- transformGrin simplifyParms x
    x <- return $ twiddleGrin x
    x <- storeAnalyze x
~~~

## コールグラフ

この調査のために一旦コールグラフを書いたので、念の為はりつけておくでゲッソ。
ひょっとすると後日使うかもしれないじゃなイカ？

~~~
main
=> processFiles
   => (_, cho) <- parseFiles
      => loadModules
      => processCug
      => typeCheckGraph
         => parseHsSource
            => preprocessHs
            => runParserWithMode
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
      => compileCompNode
         => processInitialHo
         => processDecls # Program型をこねこねする
         => recordHoFile
   => processCollectedHo cho
      => dataTable = choDataTable cho
      => combinators = values $ choCombinators cho
      => Control.Exception.evaluate dataTable / evaluate combinators
      => prog = programUpdate E.Program.program {
            progCombinators = combinators,
            progDataTable = dataTable
            }
      => compileWholeProgram prog
      => compileToGrin prog
         => Grin.FromE.compile
            => progEntryPoints
            => constantCaf
            => compile'
            => grin = setGrinFunctions theFuncs emptyGrin {
                  grinEntryPoints = minsert funcMain (FfiExport "_amain" Safe CCall [] "void") $
                                fromList epv,
                  grinPhase = PhaseInit,
                  grinTypeEnv = newTyEnv,
                  grinCafs = [ (x,node) | (x,node) <- cafs]
                  }
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

## 主要な関数の型

さらにこの調査のために関数の型を調べる必要があったでゲソ。
どうもjhcの作者のJohnさんはトップレベルの関数に型シグニチャをつけない傾向があるでゲソ...イカンでげゲソ!
主要な関数の型はイカの通りでゲソ。

~~~ {.haskell}
parseFiles :: Opt -> [FilePath] -> [String] -> [Either Module FilePath] -> (CollectedHo -> Ho -> IO CollectedHo) -> (CollectedHo -> Ho -> TiData -> IO (CollectedHo,Ho)) -> IO (CompNode,CollectedHo)
loadModules :: Opt -> [FilePath] -> [String] -> SrcLoc -> [Either Module FilePath] -> IO (Map.Map SourceHash (Module,[(Module,SrcLoc)]),HoHash,CompUnitGraph)
processCug :: CompUnitGraph -> HoHash -> IO CompNode
typeCheckGraph :: Opt -> CompNode -> IO ()
parseHsSource :: Opt -> FilePath -> LBS.ByteString -> IO (HsModule,LBS.ByteString)
preprocessHs :: Opt -> FilePath -> LBS.ByteString -> IO LBS.ByteString
runParserWithMode :: ParseMode -> P a -> String -> ([Warning],ParseResult a)
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
recordHoFile :: Ho -> HoIDeps -> [FilePath] -> HoHeader -> IO ()
processCollectedHo :: CollectedHo -> IO ()
choDataTable :: CollectedHo -> DataTable
choCombinators :: CollectedHo -> IdMap Comb
Control.Exception.evaluate :: a -> IO a
programUpdate :: Program -> Program
compileWholeProgram :: Program -> IO Program
compileToGrin :: Program -> IO ()
Grin.FromE.compile :: Program -> IO Grin
progEntryPoints :: Program -> [TVr]
constantCaf :: Program -> ([(TVr,Var,Val)],[Var],[(TVr,Var,Val)])
compile' :: CEnv -> (TVr,[TVr],E) -> C (Atom,Lam)
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
