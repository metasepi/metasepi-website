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

もう一つ気になるのはdeRefStablePtrを使ってIOを元に戻しても実行不能という点でゲソ。

~~~ {.haskell}
import Foreign.StablePtr

main :: IO ()
main = do
  p <- newStablePtr $ print "hoge"
  d <- deRefStablePtr p
  d
~~~

上のコードをコンパイルすると、イカのようなエラーになるでゲソ。

~~~
$ ajhc --tdir=tmp -o Main Main.hs
--snip--
Typechecking...
Compiling...
Collected Compilation...
-- TypeAnalyzeMethods
-- BoxifyProgram
-- Boxy WorkWrap
-- LambdaLift
Converting to Grin...
Updatable CAFS: 0
Constant CAFS:  0
Recursive CAFS: 0
Exiting abnormally. Work directory is 'tmp'
ajhc: Grin.FromE.compile'.ce in function: theMain
can't grok expression: <fromBang_ x128471745∷IO ()> x62470114
~~~

### foreign import ccall "wrapper"で関数ポインタを作る

wrapperというforeign import宣言
^[[本物のプログラマはHaskellを使う - 第22回　FFIを使って他の言語の関数を呼び出す：ITpro](http://itpro.nikkeibp.co.jp/article/COLUMN/20080805/312151/?ST=develop&P=4)]
があり、これを使えば任意のIOを関数ポインタに変換することができるようでゲソ。
wrapperを使えば簡単にpthread\_createにHaskellのIOを呼び出してもらえるじゃなイカ？
やってみるでゲソ!

...と、
[ものすごくいい加減なコード](https://github.com/ajhc/ajhc-dumpyard/tree/master/try_pthread2)
を書いてみたでゲソ。
ところが今度はFunPtrというC言語の型がみつからないとGCCに怒られるでゲソ。

~~~
Running: gcc tmp/rts/profile.c tmp/rts/rts_support.c tmp/rts/gc_none.c tmp/rts/jhc_rts.c tmp/lib/lib_cbits.c tmp/rts/gc_jgc.c tmp/rts/stableptr.c -Itmp/cbits -Itmp tmp/main_code.c -o Main '-std=gnu99' -D_GNU_SOURCE '-falign-functions=4' -ffast-math -Wextra -Wall -Wno-unused-parameter -fno-strict-aliasing -DNDEBUG -O3 '-D_JHC_GC=_JHC_GC_JGC'
tmp/main_code.c: In function ‘fFE$__CCall_testThread’:
tmp/main_code.c:659:17: warning: statement with no effect [-Wunused-value]
tmp/main_code.c: In function ‘ftheMain’:
tmp/main_code.c:1146:68: error: ‘FunPtr’ undeclared (first use in this function)
tmp/main_code.c:1146:68: note: each undeclared identifier is reported only once for each function it appears in
Exiting abnormally. Work directory is 'tmp'
ajhc: user error (C code did not compile.)
~~~

これはイカのようなC言語コードをAjhcが吐き出すためでゲソ。
もうちょっと小細工すれば関数ポインタが使えるようになりそうじゃなイカ？

~~~ {.c}
static void A_STD
ftheMain(gc_t gc)
{
        saved_gc = gc;
        (uint32_t)pthread_create((pthread_t*)0,(pthread_attr_t*)0,(FunPtr)((uintptr_t)&testThread),(HsPtr)0);
        return;
}

HsPtr
testThread(HsPtr x30)
{
        return (HsPtr)fFE$__CCall_testThread(saved_gc,(uintptr_t)x30);
}
~~~

どうも上の不具合はイカのpatchで簡単に修正できるようでゲソ。たぶんこれはイージーミスだと思うでゲソ。

~~~ {.diff}
--- a/lib/jhc/Jhc/Type/Ptr.hs
+++ b/lib/jhc/Jhc/Type/Ptr.hs
@@ -3,4 +3,4 @@ module Jhc.Type.Ptr where
 import Jhc.Prim.Bits

 data {-# CTYPE "HsPtr" #-} Ptr a = Ptr Addr_
-data {-# CTYPE "FunPtr" #-} FunPtr a = FunPtr FunAddr_
+data {-# CTYPE "HsFunPtr" #-} FunPtr a = FunPtr FunAddr_
~~~

しかしこれでFunPtrを使った関数ポインタを実現できたんでゲソが、
任意のIOを関数ポインタ化できることにはならないでゲソ。
具体的にはイカのような型になってしまっているforkOSの引数をIO ()にしたいでゲソ。

~~~ {.haskell}
forkOS :: FunPtr (Ptr () -> IO (Ptr ())) -> IO Int
~~~

GHCはどんな魔法を使っているのでゲソ？
[GHCでforeign import ccall "wrapper"を使う例](https://github.com/ajhc/ajhc-dumpyard/tree/master/ghc_foreign_wrapper)
を解析すれば何かわかるかもしれないでゲソ。
freeHaskellFunPtrの行方を探ったところ、
どうもghc/rts/Adjustor.cでwrapperが作ったコード片のラッパーを作るようでゲソ。
createAdjustorというのが主犯のようじゃなイカ。

とりあえず任意のIOをFunPtrに変換するのはキツいにしても、
定数的なIOはラベルをふるだけなのだから比較的簡単にFunPtr化できるんじゃなイカ？

### グローバル関数テーブルのインデックスを引数渡し

StablePtrを使わずにコンテキスト間でIOを授受する方法として無理矢理考えてみたでゲソ。
結局インデックスの意味がC言語側に漏れるので、
StablePtrを直接C言語に渡すケースと比較して危険度はほとんど変わらない気もするでゲソ...

### ラムダ式を使うために-std=gnu++11でコンパイル

さすがにこれは筋が悪すぎるので、困った時の隠し玉に取っておかなイカ？

## 実装
