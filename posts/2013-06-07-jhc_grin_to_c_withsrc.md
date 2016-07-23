---
title: '(作成中) Jhc compile pipeline: Grin => C'
description: jhcコンパイルパイプラインの最後段をソースコードから理解してみるでゲソ
tags: compiler, jhc, c, grin
---

[Jhc compile pipeline: Grin => C (code example)](2013-05-16-jhc_grin_to_c.html)
ではjhcのgrinコードのダンプとコンパイル結果のC言語コードを比較することで、
Grin=>Cの変換を理解した気になっていたでゲソ。
しかし、Ajhcを再入可能にするためにはコンパイルパイプラインの吐き出すC言語コードの生成ルールそのものに修正を加える必要があるでゲソ。
まずは落ち着いてjhcのGrin=>Cの変換エンジンを読んでみなイカ？

## Grin => C変換の最上位層

ズバリ
[compileGrin](http://hackage.haskell.org/packages/archive/ajhc/0.8.0.6/doc/html/C-FromGrin2.html#v:compileGrin)
という関数が用意されているでゲソ。

~~~ {.haskell}
-- File: ajhc/src/C/FromGrin2.hs
compileGrin :: Grin -> (LBS.ByteString,Requires)
compileGrin grin = (LBS.fromChunks code, req)  where
    code = [
        BS.fromString "#include \"jhc_rts_header.h\"\n",
        BS.fromString $ P.render ans,
        BS.fromString "\n"
        ]
    ans = vcat [
        vcat jgcs,
        vcat includes,
        text "",
        enum_tag_t,
        header,
        cafs,
        buildConstants cpr grin finalHcHash,
        text "",
        nh_stuff,
        text "",
        body
        ]
~~~

Grinという型をC言語のByteStringに変換するというそのまんまの型がcompileGrin関数でゲソ。
ansというのが出力するC言語コードの構造で、
[jhc禅](2013-02-19-jhc_zen.html)
で調べた最小のHaskellコードをコンパイルした結果と見比べると何がどこに対応するのかすぐにわかるでゲソ。

## Grin型

注目すべきはイカの型でゲソ。

* [Grin型](http://hackage.haskell.org/packages/archive/ajhc/0.8.0.6/doc/html/Grin-Grin.html#t:Grin)
* [FuncDef型](http://hackage.haskell.org/packages/archive/ajhc/0.8.0.6/doc/html/Grin-Grin.html#t:FuncDef)
* [Lam型](http://hackage.haskell.org/packages/archive/ajhc/0.8.0.6/doc/html/Grin-Grin.html#t:Lam)
* [Val型](http://hackage.haskell.org/packages/archive/ajhc/0.8.0.6/doc/html/Grin-Grin.html#t:Val)
* [Exp型](http://hackage.haskell.org/packages/archive/ajhc/0.8.0.6/doc/html/Grin-Grin.html#t:Exp)
* [Ty型](http://hackage.haskell.org/packages/archive/ajhc/0.8.0.6/doc/html/Grin-Grin.html#t:Ty)

~~~ {.haskell}
-- File: ajhc/src/Grin/Grin.hs
data Grin = Grin {
    grinEntryPoints :: GMap Atom FfiExport,
    grinPhase :: !Phase,
    grinTypeEnv :: TyEnv,
    grinFunctions :: [FuncDef],
    grinSuspFunctions :: Set.Set Atom,
    grinPartFunctions :: Set.Set Atom,
    grinStats :: !Stats.Stat,
    grinCafs :: [(Var,Val)]
}
data Phase = PhaseInit | PostInlineEval | PostAeOptimize | PostDevolve
data FuncDef = FuncDef {
    funcDefName  :: Atom,
    funcDefBody  :: Lam,
    funcDefCall  :: Val,
    funcDefProps :: FuncProps
    } deriving(Eq,Ord,Show)
data Lam = [Val] :-> Exp
data Val =
    NodeC !Tag [Val]          -- ^ Complete node, of type TyNode
    | Const Val               -- ^ constant data, only Lit, Const and NodeC may be children. of type TyINode
    | Lit !Number Ty          -- ^ Literal
    | Var !Var Ty             -- ^ Variable
    | Unit                    -- ^ Empty value used as placeholder
    | ValPrim Prim [Val] Ty   -- ^ Primitive value
    | Index Val Val           -- ^ A pointer incremented some number of values (Index v 0) == v
    | Item Atom Ty            -- ^ Specific named thing. function, global, region, etc..
    | ValUnknown Ty           -- ^ Unknown or unimportant value
data FuncProps = FuncProps {
    funcInfo    :: Info.Info,
    funcFreeVars :: Set.Set Var,
    funcTags    :: Set.Set Tag,
    funcType    :: ([Ty],[Ty]),
    funcExits   :: Perhaps,      -- ^ function quits the program
    funcCuts    :: Perhaps,      -- ^ function cuts to a value
    funcAllocs  :: Perhaps,      -- ^ function allocates memory
    funcCreates :: Perhaps,      -- ^ function allocates memory and stores or returns it
    funcLoops   :: Perhaps       -- ^ function may loop
    }
data Exp =
     Exp :>>= Lam                                                         -- ^ Sequencing - the same as >>= for monads.
    | BaseOp    { expBaseOp :: BaseOp,
                  expArgs :: [Val]
                }
    | App       { expFunction  :: Atom,
                  expArgs :: [Val],
                  expType :: [Ty] }                                       -- ^ Application of functions and builtins
    | Prim      { expPrimitive :: Prim,
                  expArgs :: [Val],
                  expType :: [Ty] }                                       -- ^ Primitive operation
    | Case      { expValue :: Val, expAlts :: [Lam] }                     -- ^ Case statement
    | Return    { expValues :: [Val] }                                    -- ^ Return a value
    | Error     { expError :: String, expType :: [Ty] }                   -- ^ Abort with an error message, non recoverably.
    | Call      { expValue :: Val,
                  expArgs :: [Val],
                  expType :: [Ty],
                  expJump :: Bool,                                        -- ^ Jump is equivalent to a call except it deallocates the region it resides in before transfering control
                  expFuncProps :: FuncProps,
                  expInfo :: Info.Info }                                  -- ^ Call or jump to a callable
    | NewRegion { expLam :: Lam, expInfo :: Info.Info }                   -- ^ create a new region and pass it to its argument
    | Alloc     { expValue :: Val,
                  expCount :: Val,
                  expRegion :: Val,
                  expInfo :: Info.Info }                                  -- ^ allocate space for a number of values in the given region
    | Let       { expDefs :: [FuncDef],
                  expBody :: Exp,
                  expFuncCalls :: (Set.Set Atom,Set.Set Atom),            -- ^ cache
                  expIsNormal :: Bool,                                    -- ^ cache, True = definitely normal, False = maybe normal
                  expNonNormal :: Set.Set Atom,                           -- ^ cache, a superset of functions called in non-tail call position.
                  expInfo :: Info.Info }                                  -- ^ A let of local functions
    | MkClosure { expValue :: Val,
                  expArgs :: [Val],
                  expRegion :: Val,
                  expType :: [Ty],
                  expInfo :: Info.Info }                   -- ^ create a closure
    | MkCont    { expCont :: Lam,                          -- ^ the continuation routine
                  expLam :: Lam,                           -- ^ the computation that is passed the newly created computation
                  expInfo :: Info.Info }                   -- ^ Make a continuation, always allocated on region encompasing expLam
    | GcRoots   { expValues :: [Val],                  -- ^ add some new variables to the GC roots for a subcomputation
                  expBody :: Exp }
data Ty =
    TyPtr Ty                     -- ^ pointer to a memory location which contains its argument
    | TyNode                     -- ^ a whole node
    | TyINode                    -- ^ a whole possibly indirect node
    | TyAttr Ty Ty               -- ^ attach an attribute to a type
    | TyAnd Ty Ty                -- ^ boolean conjunction of types
    | TyOr  Ty Ty                -- ^ boolean disjunction of types
    | TyPrim Op.Ty               -- ^ a basic type
    | TyUnit                     -- ^ type of Unit
    | TyCall Callable [Ty] [Ty]  -- ^ something call,jump, or cut-to-able
    | TyRegion                   -- ^ a region
    | TyGcContext                -- ^ the context for garbage collection
    | TyRegister Ty              -- ^ a register contains a mutable value, the register itself cannot be addressed,
                                 --   hence they may not be returned from functions or passed as arguments.
    | TyComplex Ty               -- ^ A complex version of a basic type
    | TyVector !Int Ty           -- ^ A vector of a basic type
    | TyUnknown                  -- ^ an unknown possibly undefined type, All of these must be eliminated by code generation
data Callable = Continuation | Function | Closure | LocalFunction | Primitive'
data TyThunk
    = TyNotThunk               -- ^ not the thunk
    | TyPApp (Maybe Ty) Atom   -- ^ can be applied to (possibly) an argument, and what results
    | TySusp Atom              -- ^ can be evaluated and calls what function
data TyTy = TyTy {
    tySlots :: [Ty],
    tyReturn :: [Ty],
    tyThunk :: TyThunk,
    tySiblings :: Maybe [Atom]
}
newtype TyEnv = TyEnv (GMap Atom TyTy)
~~~

~~~ {.haskell}
-- File: ajhc/src/StringTable/Atom.hsc
newtype Atom = Atom (#type atom_t)
~~~

~~~ {.c}
/* File: ajhc/src/StringTable/StringTable_cbits.h */
typedef uint32_t atom_t;
~~~

~~~ {.haskell}
-- File: ajhc/src/C/FFI.hs
data FfiExport = FfiExport {
    ffiExportCName    :: CName,
    ffiExportSafety   :: Safety,
    ffiExportCallConv :: CallConv,
    ffiExportArgTypes :: [ExtType],
    ffiExportRetType  :: ExtType
    }
type CName = String
-- File: ajhc/src/C/Prims.hs
data Safety = Safe | Unsafe deriving(Eq,Ord,Show)
data CallConv = CCall | StdCall | CApi | Primitive | DotNet
newtype ExtType = ExtType PackedString
~~~

xxx Op.Ty

## Cモナド?

ここでも注目すべきはイカの型でゲソ。

* [Expression型](http://hackage.haskell.org/packages/archive/ajhc/0.8.0.6/doc/html/C-Generate.html#t:Expression)
* [Statement型](http://hackage.haskell.org/packages/archive/ajhc/0.8.0.6/doc/html/C-Generate.html#t:Statement)
* [functionCall関数](http://hackage.haskell.org/packages/archive/ajhc/0.8.0.6/doc/html/C-Generate.html#v:functionCall)

## ユーティリティ関数

~~~ {.haskell}
-- File: ajhc/src/C/FromGrin2.hs
runC :: Grin -> C a -> ((a,HcHash,Written),Map.Map Atom TyRep)
convertBody :: Exp -> C Statement
convertConst :: Val -> C (Maybe Expression)
compileGrin :: Grin -> (LBS.ByteString,Requires)
castFunc :: Op.ConvOp -> Op.Ty -> Op.Ty -> Expression -> Expression
convertPrim p vs ty
~~~
