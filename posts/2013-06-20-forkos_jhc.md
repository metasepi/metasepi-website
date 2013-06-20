---
title: Build forkOS API using pthread.
description: pthreadでHaskellのforkOSを作ってみるでゲソ!
tags: jhc, ajhc, thread, pthread
---

再入可能にしようとして、まずは
[forkOS](http://hackage.haskell.org/packages/archive/base/latest/doc/html/Control-Concurrent.html#v:forkOS)
を作ろうとしたらハマったでゲソ。
このページはforkOSをpthread\_createを使って作るメモ書きでゲソ。

## 作成方法を考えよう

作る前にまずは作戦をねるでゲソー。

### (1) GHC baseパッケージの設計をまねる

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

### (2) foreign import ccall "wrapper"で関数ポインタを作る

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

[Commentary/Rts/FFI – GHC](http://hackage.haskell.org/trac/ghc/wiki/Commentary/Rts/FFI)
を読んでみたでゲソが、具体的な実現方法については言及がないでゲソ。

### (3) グローバル関数テーブルのインデックスを引数渡し

StablePtrを使わずにコンテキスト間でIOを授受する方法として無理矢理考えてみたでゲソ。
結局インデックスの意味がC言語側に漏れるので、
StablePtrを直接C言語に渡すケースと比較して危険度はほとんど変わらない気もするでゲソ...

### (4) ラムダ式を使うために-std=gnu++11でコンパイル

さすがにこれは筋が悪すぎるので、困った時の隠し玉に取っておかなイカ？

## 結論: やはりnewStablePtrに直接IO ()を突っ込んだ際の挙動を観察するべき

~~~
ajhc: Grin.FromE.compile'.ce in function: theMain
can't grok expression: <fromBang_ x128471745∷IO ()> x62470114
~~~

このメッセージはcompile'関数が以下の型を意図せず受け取ったことをしめしているでゲソ。

~~~ {.haskell}
(EAp (EPrim (PrimPrim "fromBang_") [x] e1) e2)
~~~

ということはこのEApという型はどこかで変換されるべきで、そのしくみから漏れてきたと考えられるじゃなイカ。
しかし仮にイカのようなpatchをあてても...

~~~ {.diff}
--- a/lib/haskell-extras/Foreign/StablePtr.hs
+++ b/lib/haskell-extras/Foreign/StablePtr.hs
@@ -5,7 +5,9 @@ module Foreign.StablePtr(
     castPtrToStablePtr,
     newStablePtr,
     deRefStablePtr,
-    freeStablePtr
+    freeStablePtr,
+    newStablePtrIO,
+    deRefStablePtrIO,
     ) where
 
 import Jhc.Prim.Rts
@@ -37,6 +39,19 @@ deRefStablePtr x = do
     fromUIO $ \w -> case c_derefStablePtr (toBang_ x) w of
         (# w', s #) -> (# w', fromBang_ s #)
 
+newStablePtrIO :: IO a -> IO (StablePtr (IO a))
+newStablePtrIO x = do
+    fromUIO $ \w -> case c_newStablePtrIO x w of
+        (# w', s #) -> (# w', s #)
+
+deRefStablePtrIO :: StablePtr (IO a) -> IO (IO a)
+deRefStablePtrIO x = do
+    fromUIO $ \w -> case c_derefStablePtrIO x w of
+        (# w', s #) -> (# w', s #)
+
 foreign import ccall unsafe "rts/stableptr.c c_freeStablePtr"  c_freeStablePtr   :: Bang_ (StablePtr a) -> IO ()
 foreign import ccall unsafe "rts/stableptr.c c_newStablePtr"   c_newStablePtr    :: Bang_ a -> UIO (Bang_ (StablePtr a))
 foreign import ccall unsafe "rts/stableptr.c c_derefStablePtr" c_derefStablePtr :: Bang_ (StablePtr a) -> UIO (Bang_ a)
+
+foreign import ccall unsafe "rts/stableptr.c c_newStablePtr"   c_newStablePtrIO   :: IO a -> UIO (StablePtr (IO a))
+foreign import ccall unsafe "rts/stableptr.c c_derefStablePtr" c_derefStablePtrIO :: StablePtr (IO a) -> UIO (IO a)
~~~

ajhcのコンパイルでイカのようにエラーになってしまうでゲソ。
どうやらforeign importに渡せる型は限定されているようでゲソ。

~~~
Compiling...
[1 of 4] Foreign.StablePtr
lib/haskell-extras/Foreign/StablePtr.hs:56  - Error: Type 'Foreign.StablePtr.StablePtr (IO Foreign.StablePtr.37_a)' cannot be used in a foreign declaration
lib/haskell-extras/Foreign/StablePtr.hs:57  - Error: Type 'IO Foreign.StablePtr.39_a' cannot be used in a foreign declaration
make[2]: *** [haskell-extras-0.8.1.hl] エラー 1
~~~

じゃあUIOを経由してStablePtrを作るのはどーなんでゲソ？

~~~ {.haskell}
newStablePtrIO :: IO a -> IO (StablePtr (UIO a))
newStablePtrIO x = newStablePtr (unIO x)

deRefStablePtrIO :: StablePtr (UIO a) -> IO (IO a)
deRefStablePtrIO x = do
  u <- deRefStablePtr x
  return $ fromUIO u
~~~

エラーは変化せず、そりゃそうカー。

ちょっと立ち返って、StablePtrを経由したIO ()の授受というのは本来どのようなコードになるべきなんでゲソ？
イカのようなコード、つまりIO ()をStablePtrとBang_で二重に包んだような型を作り、
この型をpthread_create()で生成されるスレッドに渡して復元してほしいでゲソ。

~~~ {.haskell}
import Foreign.StablePtr
import Jhc.Prim.Rts

iToB :: IO () -> IO (Bang_ (StablePtr (IO ())))
iToB io = do
  s <- newStablePtr io
  return $ toBang_ s

runB :: Bang_ (StablePtr (IO ())) -> IO ()
runB b = do
  io <- deRefStablePtr $ fromBang_ b
  io

main :: IO ()
main = do
  l <- getLine
  b <- iToB $ print l
  runB b
~~~

ところが先のエラーがなぜ起きていたかというと予期しないEApがあったからじゃなイカ。
この変なEApだけごまかせばなんとかなるんじゃなイカ？
どうやらこのEApという型はfromAp関数でEVarを剥き出しにしてからパターンマッチされるようでゲソ。

~~~ {.haskell}
-- File: ajhc/src/E/Type.hs
fromAp :: E -> (E,[E])
fromAp e = f [] e where
    f as (EAp e a) = f (a:as) e
    f as e  =  (e,as)

-- File: ajhc/src/Grin/FromE.hs
    ce e | (EVar tvr,as) <- fromAp e = do
        as <- return $ args as
        lfunc <- asks lfuncMap
        let fty = toTypes TyNode (getType e)
        case mlookup (tvrIdent tvr) (ccafMap cenv) of
            Just (Const c) -> app fty (Return [c]) as
            Just x@Var {} -> app fty (gEval x) as
            Nothing | Just (v,n,rt) <- mlookup (tvrIdent tvr) lfunc -> do
                    let (x,y) = splitAt n as
                    app fty (App v (keepIts x) rt) y
            Nothing -> case mlookup (tvrIdent tvr) (scMap cenv) of
                Just (v,as',es)
                    | length as >= length as' -> do
                        let (x,y) = splitAt (length as') as
                        app fty (App v (keepIts x) es) y
                    | otherwise -> do
                        let pt = partialTag v (length as' - length as)
                        return $ dstore (NodeC pt (keepIts as))
                Nothing | not (isLifted $ EVar tvr) -> do
                    mtick' "Grin.FromE.app-unlifted"
                    app fty (Return [toVal tvr]) as
                Nothing -> do
                    case as of
                        [] -> evalVar fty tvr
                        _ -> do
                            ee <- evalVar [TyNode] tvr
                            app fty ee as
            _ -> error "FromE.ce: bad."
~~~

そこでイカのようなfromBang_プリミティブを抹殺する関数を作ったでゲソ!

~~~ {.haskell}
    stripBang :: E -> E
    stripBang e = f e where
      f (EAp p a) = g p a
      f e = e
      g (EPrim (PrimPrim "fromBang_") [b] _) a = EAp b a
      g e a = EAp e a
~~~

このstripBangを通してからfromApにeを食わせたところ無事エラーが出なくなったでゲソ。
ちょっと危険な気もするが、大目に見てほしいでゲソ。

## 実装

ここまで来ればforkOSを実装するのは簡単でゲソ。

~~~ {.haskell}
-- File: ajhc/lib/haskell-extras/Control/Concurrent.hs
{-# LANGUAGE ForeignFunctionInterface #-}
module Control.Concurrent (forkOS, ThreadId) where
import Foreign.Ptr
import Foreign.StablePtr
import Foreign.Storable
import Foreign.Marshal.Alloc
import Control.Monad (when)
import Jhc.Prim.Rts

data {-# CTYPE "rts/conc.h jhc_threadid_t" #-} CthreadIdT
data ThreadId = ThreadId CthreadIdT

foreign import ccall "rts/conc.h forkOS_createThread" forkOScreateThread ::
   FunPtr (Bang_ (StablePtr (IO ())) -> IO (Ptr ())) -> Bang_ a -> Ptr Int -> IO CthreadIdT

forkOScreateThreadWrapper :: Bang_ (StablePtr (IO ())) -> IO (Ptr ())
forkOScreateThreadWrapper b = do
  let s = fromBang_ b
  d <- deRefStablePtr s
  d
  freeStablePtr s
  return nullPtr

foreign export ccall "forkOScreateThreadWrapper" forkOScreateThreadWrapper ::
  Bang_ (StablePtr (IO ())) -> IO (Ptr ())
foreign import ccall "&forkOScreateThreadWrapper" p_forkOScreateThreadWrapper ::
  FunPtr (Bang_ (StablePtr (IO ())) -> IO (Ptr ()))

forkOS :: IO () -> IO ThreadId
forkOS f = alloca $ \ip -> do
  s <- newStablePtr f
  pth <- forkOScreateThread p_forkOScreateThreadWrapper (toBang_ s) ip
  i <- peek ip
  when (i /= 0) $ fail "Cannot create OS thread."
  return $ ThreadId pth
~~~

~~~ {.c}
// File: ajhc/rts/rts/conc.c
jhc_threadid_t
forkOS_createThread(void *(*wrapper) (void *), void *entry, int *err)
{
        pthread_t tid;
        *err = pthread_create(&tid, NULL, wrapper, entry);
        if (*err) {
                pthread_detach(tid);
        }
        return tid;
}
~~~
