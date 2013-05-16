---
title: (作成中) Detail of the jgc garbage collector
description: 再入を実現する前によくGCを観察してみるでゲソ!
tags: jhc, jgc, gc, haskell
---

AjhcのデフォルトのGCはjgcでゲソ。
このjgcについての解説は
[@dec9ue](https://twitter.com/dec9ue)
氏のプレゼン資料が詳しいかったでゲソ。

<iframe src="http://www.slideshare.net/slideshow/embed_code/16298437" width="427" height="356" frameborder="0" marginwidth="0" marginheight="0" scrolling="no" style="border:1px solid #CCC;border-width:1px 1px 0;margin-bottom:5px" allowfullscreen webkitallowfullscreen mozallowfullscreen> </iframe> <div style="margin-bottom:5px"> <strong> <a href="http://www.slideshare.net/dec9ue/gc-16298437" title="小二病でもGCやりたい" target="_blank">小二病でもGCやりたい</a> </strong> from <strong><a href="http://www.slideshare.net/dec9ue" target="_blank">dec9ue</a></strong> </div>

これからAjhcを使って以下を実現したいでゲソ。

* クリティカルリージョンの保護
* 割り込みコンテキストをHaskellで記述
* 並列実行
* GCの中断と再開

とすると、jgcに対してもう少し突っ込んだ理解を今しておいた方が良さそうでゲソ。

## GCのルート

gc_perform_gc関数の前半でヒープにマーキングしているはずなので、読めばわかるはずじゃなイカ。

~~~ {.c}
void A_STD
gc_perform_gc(gc_t gc)
{
        profile_push(&gc_gc_time);
        arena->number_gcs++;

        unsigned number_redirects = 0;
        unsigned number_stack = 0;
        unsigned number_ptr = 0;
        struct stack stack = EMPTY_STACK;

        clear_used_bits(arena);

        debugf("Setting Roots:");
        stack_check(&stack, root_stack.ptr);
        for(unsigned i = 0; i < root_stack.ptr; i++) {
                gc_add_grey(&stack, root_stack.stack[i]);
                debugf(" %p", root_stack.stack[i]);
        }
        debugf(" # ");
        struct StablePtr *sp;
        LIST_FOREACH(sp, &root_StablePtrs, link) {
            gc_add_grey(&stack, (entry_t *)sp);
            debugf(" %p", root_stack.stack[i]);
        }
~~~

gc_perform_gc関数が開始すると...

1. stack一時変数を初期化
2. arenaの中身のused_bitを一般0クリア
3. stack_check関数を呼び出してstack一時変数がroot_stack.ptr個分のエントリを格納できるか調べ
4. stack一時変数のサイズが足りなければstack_grow関数でreallocを呼び出し拡張
5. root_stack.stack配列の要素を一つずつgc_add_grey関数に食わせる
6. gc_add_grey関数はroot_stack.stack配列の要素がヒープ中かどうかチェックする。nh_stuff配列の中にある要素は静的確保されたもの
7. さらにgc_add_grey関数はroot_stack.stack配列の要素にused_bitが立ってないことを確認してから立てる
8. 6と7に成功したらstack->stack配列に当該root_stack.stack配列の要素を積む
9. BSDリストであるroot_StablePtrsを順番に辿る
10. 6と7と同様にしてgc_add_grey関数でチェックした後stack->stack配列にroot_StablePtrsの要素を積む

ということはroot_stackとroot_StablePtrsの2つがGCルートということになるでゲソ。

ところでちょっと気になるんでゲソが、
root_StablePtrsをgc_add_grey関数にかける前にstack_checkをもう一度呼び出してstack一時変数のサイズが足りてるかチェックした方がいいんじゃなイカ...
このままだとStablePtrの個数が多い場合にはふっとぶ気がするでゲソ。

### root_stackとは何か

これはふつーのプログラムでは使われないようでゲソ。
jhcのGrinがgc_add_root関数を使うコード吐き出すことがあるようでゲソ。

~~~ {.haskell}
-- File: ajhc/src/C/FromGrin2.hs
declareEvalFunc isCAF n = do
    fn <- tagToFunction n
    grin <- asks rGrin
    declareStruct n
    nt <- nodeType n
    let ts = runIdentity $ findArgs (grinTypeEnv grin) n
        fname = toName $ "E_" ++ show fn
        aname = name "arg"
        rvar = localVariable wptr_t (name "r")
        atype = ptrType nt
        body = rvar =* functionCall (toName (show $ fn)) (mgc [ project' (arg i) (variable aname) | _ <- ts | i <- [(1 :: Int) .. ] ])
        update =  f_update (variable aname) rvar
        addroot =  if isCAF && fopts FO.Jgc then f_gc_add_root (cast sptr_t rvar) else emptyExpression
        body' = if not isCAF && fopts FO.Jgc then subBlock (gc_roots [f_MKLAZY(variable aname)] & rest) else rest
        rest = body & update & addroot & creturn rvar
    tellFunctions [function fname wptr_t (mgct [(aname,atype)]) [a_STD, a_FALIGNED] body']
    return fname
~~~

ちょっとコードの意図が取りにくいでゲソが"E\_"ではじまる関数はサンクの評価関数であるはずなので、
スタティックサンクだとGCルートになるんじゃなイカ？
その時に"E\_"ではじまる評価関数の中にgc_add_root関数が埋め込まれるはずでゲソ。
...でもなんかそのケースは稀な気がするでゲソ。
grinの最適化の中でほとんどのスタティックサンクは使用元の関数の中に展開されてしまいそうでゲソ。
簡単な例を作ってみてもgc_add_root関数が埋め込まれたC言語コードをajhcは吐き出さないようでゲソ。
まぁここではこんなものがGCルートになる可能性があるよ、ということでいいんじゃなイカ？

### root_StablePtrsとは何か

[Foreign.StablePtr.newStablePtr(これはGHCのAPI)](http://www.haskell.org/ghc/docs/latest/html/libraries/base/Foreign-StablePtr.html#v:newStablePtr)
をHaskellコードから呼ぶとstruct StablePtrがstableptr.cでmalloc確保されて、
root_StablePtrsに繋がれるんでゲソ。
つまりStablePtrを保管する器ということじゃなイカ。リストより木構造の方が良い気もするでゲソ...

~~~ {.haskell}
-- | newStablePtr will seq its argument to get rid of nasty GC issues and be
-- compatible with FFI calling conventions, if this is an issue, you can put an
-- extra box around it.
newStablePtr :: a -> IO (StablePtr a)
newStablePtr x = do
    fromUIO $ \w -> case c_newStablePtr (toBang_ x) w of
        (# w', s #) -> (# w', fromBang_ s #)
~~~

~~~ {.c}
wptr_t c_newStablePtr(sptr_t c) {
    struct StablePtr* sp = malloc(sizeof(struct StablePtr));
    sp->contents = c;
    LIST_INSERT_HEAD(&root_StablePtrs, sp, link);
    assert(GET_PTYPE(sp) == 0);
    return (wptr_t)TO_SPTR(P_VALUE,(wptr_t)sp);
}
~~~

### 他にGCルートになるものは？

さすがに上の2つだけがGCルートのはずないでゲソ。根っこがスカスカじゃなイカ。

xxxxx

## C言語スタックとGCスタックの関係

* gc引数って何？
* saved_gcって何？
* gc_stack_baseって何？

## ミューテターにとってのクリティカルリージョンは？

## 参照はループになるか？
