---
title: (作成中) Build forkOS API using pthread.
description: pthreadでHaskellのforkOSを作ってみるでゲソ!
tags: jhc, ajhc, thread, pthread
---

再入可能にしようとして、まずは
[forkOS](http://hackage.haskell.org/packages/archive/base/latest/doc/html/Control-Concurrent.html#v:forkOS)
を作ろうとしたらハマったでゲソ。
このページはforkOSをpthread\_createを使って作るメモ書きでゲソ。

## 作成方法を考えよう

作る前にまずは作戦をねるでゲソー。

### GHC baseパッケージの設計をまねる

[GHCでのforkOSの実装](http://hackage.haskell.org/packages/archive/base/latest/doc/html/src/Control-Concurrent.html#forkOS)
を見ると、StablePtrにIO関数を包んで、C言語のforkOS\_createThread関数に渡しているでゲソ。
pthread\_createは

~~~ {.haskell}
-- File: ghc/libraries/base/Control/Concurrent.hs
foreign export ccall forkOS_entry
    :: StablePtr (IO ()) -> IO ()

foreign import ccall "forkOS_entry" forkOS_entry_reimported
    :: StablePtr (IO ()) -> IO ()

forkOS_entry :: StablePtr (IO ()) -> IO ()
forkOS_entry stableAction = do
        action <- deRefStablePtr stableAction
        action

foreign import ccall forkOS_createThread
    :: StablePtr (IO ()) -> IO CInt

forkOS :: IO () -> IO ThreadId
forkOS action0
    | rtsSupportsBoundThreads = do
-- snip --
        entry <- newStablePtr (myThreadId >>= putMVar mv >> action_plus)
        err <- forkOS_createThread entry
        when (err /= 0) $ fail "Cannot create OS thread."
        tid <- takeMVar mv
        freeStablePtr entry
        return tid
~~~

~~~ {.c}
/* File: ghc/rts/posix/OSThreads.c */
static void *
forkOS_createThreadWrapper ( void * entry )
{
    Capability *cap;
    cap = rts_lock();
    rts_evalStableIO(&cap, (HsStablePtr) entry, NULL);
    rts_unlock(cap);
    return NULL;
}

int
forkOS_createThread ( HsStablePtr entry )
{
    pthread_t tid;
    int result = pthread_create(&tid, NULL,
				forkOS_createThreadWrapper, (void*)entry);
    if(!result)
        pthread_detach(tid);
    return result;
}
~~~

どうやらGHCではStablePtrはFFIを越えることができて、その型はHsStablePtrのようでゲソ。
このようなコードをAjhcでも実現できなイカ？
ところが
[それぽいコード](https://github.com/ajhc/ajhc-dumpyard/tree/master/try_pthread1)
を書いてみたところエラーになるじゃなイカ。
これはStablePtrは単なるスマートポインタになるはずでゲソが、
どうもこのスマートポインタを直接C言語コードに渡すのが禁止されているようでゲソ。

~~~
$ make
--snip--
Compiling...
[1 of 1] Jhc.Conc         
jhc-conc-pthread/Jhc/Conc.hs:28  - Error: caught error processing decl: user error (createFunc: attempt to pass a void argument)
jhc-conc-pthread/Jhc/Conc.hs:28  - Error: Type 'Foreign.StablePtr.StablePtr (IO ())' cannot be used in a foreign declaration
~~~

このスマートポインタを直接C言語コードに見せる行為をはたして許して良いものか考えどころでゲソ。。。
イカはforeignで使って良い要素を判定している箇所の抜き出しでゲソ。

~~~ {.haskell}
-- File: ajhc/src/E/FromHs.hs
instance DataTableMonad C where
    getDataTable = asks ceDataTable

ffiTypeInfo bad t cont = do
    dataTable <- getDataTable
    case lookupExtTypeInfo dataTable t of
        Just r -> cont r
        Nothing -> do
            sl <- getSrcLoc
            liftIO $ warn sl InvalidFFIType $ printf "Type '%s' cannot be used in a foreign declaration" (pprint t :: String)
            return bad

convertDecls tiData props classHierarchy assumps dataTable hsDecls = res where
    res = do
        (a,ws) <- evalRWST ans ceEnv 2
        mapM_ addWarning ws
        return a
    ceEnv = CeEnv {
        ceCoerce = tiCoerce tiData,
        ceAssumps = assumps,
        ceFuncs = funcs,
        ceProps = props,
        ceSrcLoc = bogusASrcLoc,
        ceDataTable = dataTable
        }

-- File: ajhc/src/E/Main.hs
processDecls ::
    CollectedHo             -- ^ Collected ho
    -> Ho                   -- ^ preliminary haskell object  data
    -> TiData               -- ^ front end output
    -> IO (CollectedHo,Ho)  -- ^ (new accumulated ho, final ho for this modules)
processDecls cho ho' tiData = withStackStatus "processDecls" $  do
--snip--
    let derives = (collectDeriving originalDecls)
    let dataTable = toDataTable (getConstructorKinds (hoKinds $ hoTcInfo ho'))
            (tiAllAssumptions tiData) originalDecls (hoDataTable $ hoBuild ho)
        classInstances = deriveClasses (choCombinators cho) fullDataTable derives
        fullDataTable = dataTable `mappend` hoDataTable (hoBuild ho)
--snip--
    ds' <- convertDecls tiData theProps
        (hoClassHierarchy $ hoTcInfo ho') allAssumps  fullDataTable decls
~~~

### foreign import ccall "wrapper"で関数ポインタを作る

wrapperというforeign import宣言
^[[本物のプログラマはHaskellを使う - 第22回　FFIを使って他の言語の関数を呼び出す：ITpro](http://itpro.nikkeibp.co.jp/article/COLUMN/20080805/312151/?ST=develop&P=4)]
があり、これを使えば任意のIOを関数ポインタに変換することができるようでゲソ。
wrapperを使えば簡単にpthread\_createにHaskellのIOを呼び出してもらえるじゃなイカ？
やってみるでゲソ!




### グローバル関数テーブルのインデックスを引数渡し



## 実装
