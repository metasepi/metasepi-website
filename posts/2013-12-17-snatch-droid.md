---
title: 簡約!? λカ娘 Rock!の紹介とHaskell製Androidアプリの解説
description: NDKでHaskellも動くでゲソー
tags: haskell, book, android, ajhc
---

![](http://www.paraiso-lang.org/ikmsm/images/c85-cover-s.jpg)

この記事は
[Android Advent Calendar 2013 - Qiita [キータ]](http://qiita.com/advent-calendar/2013/android)
の12/17(火曜)分じゃなイカ。

だいぶ息切れしてきた関数型プログラミングの本
[簡約!? λカ娘 Rock!](http://www.paraiso-lang.org/ikmsm/books/c85.html)
がコミックマーケット85
[3日目 西地区 す-03a](http://twitcmap.jp/?id=0085-3-SUh-03-a)
で出るでゲソ。みんな買ってほしいでゲソ!

* 第1章 λカ娘探索2?
* 第2章 僕のカノジョはスナッチャー # <= コレ書いた

がもくじで、
[@master_q](https://twitter.com/master_q)
は第2章を書いたらしいでゲソ。
この記事では
[Android NDK](http://developer.android.com/tools/sdk/ndk/index.html)
に付属しているnative-activityサンプルアプリケーションをHaskell化するでゲソ。
当然native-activityはC言語で書かれているので、いきなり全部をHaskell化できないじゃなイカ。
そこで
[スナッチ設計](http://www.slideshare.net/master_q/20131020-osc-tokyoajhc)
という手法を使って動作可能なまま少しずつHaskellで設計置換していくんでゲソ。

記事が気になったら是非
[サンプル版pdf](http://www.paraiso-lang.org/ikmsm/books/c85-sample.pdf)
を読んでみてほしいでゲッソ!


## Haskellで書いたAndroid NDKアプリってどんな感じ？

Android NDKに対するスナッチ設計の詳細は先の同人誌に書いたので、
この記事ではHaskellで書いたAndroid NDKアプリの中身を見てみようと思うでゲソ。
題材はGoogle Playからダウンロードできる
[Cube](https://play.google.com/store/apps/details?id=org.metasepi.ajhc.android.cube)
というアプリでゲソ。

[![](/img/20131217_haskell_cube.png)](https://play.google.com/store/apps/details?id=org.metasepi.ajhc.android.cube)

このアプリは単なるOpenGL ESのデモアプリで使い方はイカの動画を見ればすぐわかると思うでゲソ。

<iframe width="420" height="315" src="//www.youtube.com/embed/n6cepTfnFoo" frameborder="0" allowfullscreen></iframe>

このCubeアプリのソースコードは
[https://github.com/ajhc/demo-android-ndk/tree/master/cube](https://github.com/ajhc/demo-android-ndk/tree/master/cube)
にあり、以下のようなディレクトリツリーを持っているでゲソ。

~~~
$ pwd
/home/kiwamu/src/demo-android-ndk/cube
$ tree
.
|-- AndroidManifest.xml
|-- Makefile
|-- cube.xcf
|-- hs_src
|   |-- CubeVertices.hs
|   `-- Main.hs
|-- jni
|   |-- Android.mk
|   |-- Application.mk
|   |-- c_extern.h
|   |-- dummy4jhc.c
|   `-- main.c
`-- res
    |-- drawable-hdpi
    |   `-- ic_launcher.png
    |-- drawable-ldpi
    |   `-- ic_launcher.png
    |-- drawable-mdpi
    |   `-- ic_launcher.png
    |-- drawable-xhdpi
    |   `-- ic_launcher.png
    `-- values
        `-- strings.xml
~~~

C言語とHaskellの界面の話題や、ビルド手順は先の同人誌が詳しいでゲソ。
この記事では上記ファイルの内、Haskellで書かれているCubeVertices.hsとMain.hsについて解説するでゲソ。

## CubeVertices.hsファイルについて

まずこの立方体のデータがどこにあるかでゲソ。
それは簡単でイカのモジュールでゲソ。

[https://github.com/ajhc/demo-android-ndk/blob/master/cube/hs_src/CubeVertices.hs](https://github.com/ajhc/demo-android-ndk/blob/master/cube/hs_src/CubeVertices.hs)

~~~ {.haskell}
module CubeVertices where

import AndroidNdk

vertices :: [GLfloat]
vertices = [
    -- front
    -0.5, 0.5, 0.5, 
    -0.5, -0.5, 0.5, 
    0.5, 0.5, 0.5,
    0.5, 0.5, 0.5, 
    -0.5, -0.5, 0.5, 
    0.5, -0.5, 0.5,
    -- right
    0.5, 0.5, 0.5, 
--snip--
colors :: [GLfloat]
colors = [
    -- front
    0.0625,0.57421875,0.92578125,1.0,
    0.0625,0.57421875,0.92578125,1.0,
    0.0625,0.57421875,0.92578125,1.0,
    0.0625,0.57421875,0.92578125,1.0,
    0.0625,0.57421875,0.92578125,1.0,
    0.0625,0.57421875,0.92578125,1.0,
    -- right
    0.29296875,0.66796875,0.92578125,1.0,
~~~

verticesとcolorsという名前のリストが入っているだけでゲソ。
このリストはMain.hsで使用されて、それぞれglVertexPointerとglColorPointerに渡されるだけじゃなイカ。
あとはHaskellじゃなくてOpenGLの知識でゲソ。

## glVertexPointerとglColorPointerの呼び出し

そのglVertexPointerとglColorPointerはどこから呼び出されるかというとMain.hsのengineDrawFrame関数でゲソ。

[https://github.com/ajhc/demo-android-ndk/blob/master/cube/hs_src/Main.hs#L80](https://github.com/ajhc/demo-android-ndk/blob/master/cube/hs_src/Main.hs#L80)

~~~ {.haskell}
engineDrawFrame :: AndroidEngine -> IO ()
engineDrawFrame enghs = do
  let disp  = engEglDisplay enghs
      surf  = engEglSurface enghs
      w     = fromIntegral $ engWidth enghs
      h     = fromIntegral $ engHeight enghs
      s     = engState enghs
      dx    = fromIntegral $ sStateDx s
      dy    = fromIntegral $ sStateDy s
      angle = sStateAngle s
  when (disp /= c_EGL_NO_DISPLAY) $ do
    c_glClear $ c_GL_COLOR_BUFFER_BIT .|. c_GL_DEPTH_BUFFER_BIT
    withArray vertices $ \vp -> withArray colors $ \cp -> do -- xxx heavy
      c_glEnableClientState c_GL_VERTEX_ARRAY
      c_glEnableClientState c_GL_COLOR_ARRAY
      c_glVertexPointer 3 c_GL_FLOAT 0 vp
      c_glColorPointer 4 c_GL_FLOAT 0 cp
      c_glRotatef ((sqrt (dx ** 2 + dy ** 2)) / 10.0) dy dx 0.0
      c_glDrawArrays c_GL_TRIANGLES 0 36
      c_glDisableClientState c_GL_VERTEX_ARRAY
      c_glDisableClientState c_GL_COLOR_ARRAY
    void $ c_eglSwapBuffers disp surf
~~~

このコード、前半はAndroidEngine型から現在の状態を引き出しているようじゃなイカ。
その後ディスプレイが初期化されていたら"c_gl"ではじまる名前の関数群、
つまりOpenGL ESの関数群を呼び出して画面描画をするでゲソ。
このOpenGL ESの関数群は以下のファイルで定義されているでゲソ。
HaskellからC言語の関数が呼び出せて便利でゲソ!

[https://github.com/ajhc/demo-android-ndk/blob/master/lib/android-ndk/AndroidNdk/OpenGLES.hs](https://github.com/ajhc/demo-android-ndk/blob/master/lib/android-ndk/AndroidNdk/OpenGLES.hs)

## AndroidEngine型の状態変更

engineDrawFrame関数の実装を見ていると、AndroidEngine型に変更がないと立方体は微塵とも動かないことがわかるでゲソ。
誰かがAndroidEngine型の状態を変更していないとつじつまが合わないんじゃなイカ？
この状態を変更する犯人は二人いるんでゲソ。

まず一人目はeHandleInput関数でゲソ。
この関数はタッチパネルのドラッグ動作を検出して、
AndroidEngine型に格納されている以下4つの状態を変更するでゲソ。

* sStateX: 現在タッチされているX座標
* sStateY: 現在タッチされているY座標
* sStateDx: X方向のドラッグされた距離
* sStateDy: Y方向のドラッグされた距離

[https://github.com/ajhc/demo-android-ndk/blob/master/cube/hs_src/Main.hs#L38](https://github.com/ajhc/demo-android-ndk/blob/master/cube/hs_src/Main.hs#L38)

~~~ {.haskell}
eHandleInput :: AndroidEngine -> AInputEventType -> AMotionEventAction -> (Float, Float) -> IO (Maybe AndroidEngine)
eHandleInput eng = go
  where go AInputEventTypeMotion AMotionEventActionUp _ = return Nothing
        go AInputEventTypeMotion act (x,y) = do
          let stat = engState eng
              ox = if act == AMotionEventActionDown then x else fromIntegral $ sStateX stat
              oy = if act == AMotionEventActionDown then y else fromIntegral $ sStateY stat
          return (Just $ eng { engAnimating = 1
                             , engState = stat { sStateX  = truncate x
                                               , sStateY  = truncate y
                                               , sStateDx = truncate $ x - ox
                                               , sStateDy = truncate $ y - oy } })
        go _ _ _ = return Nothing
~~~

二人目はeHandleCmd関数じゃなイカ。
この関数のパターンマッチは長いでゲソがほぼ
[元にしたC言語のnative-activityサンプルコード](https://gist.github.com/master-q/8001496#file-main-c-L182)
のままでゲソ。
この関数でAndroidのアクティビティの状態管理をしているでゲソ。

[https://github.com/ajhc/demo-android-ndk/blob/master/cube/hs_src/Main.hs#L53](https://github.com/ajhc/demo-android-ndk/blob/master/cube/hs_src/Main.hs#L53)

~~~ {.haskell}
eHandleCmd :: (AndroidApp, AndroidEngine) -> AAppCmd -> IO (Maybe AndroidApp, Maybe AndroidEngine)
eHandleCmd (app, eng) = go
  where go AAppCmdSaveState = do
          sstat <- malloc
          poke sstat $ engState eng
          return (Just $ app { appSavedState = sstat
                             , appSavedStateSize = toEnum $ sizeOf $ engState eng }, Nothing)
        go AAppCmdInitWindow | appWindow app /= nullPtr = do
          (Just eng') <- initDisplayHs androidActs eng
          engineDrawFrame eng'
          return (Nothing, Just eng')
        go AAppCmdTermWindow = do
          eng' <- engineTermDisplay eng
          return (Nothing, Just eng')
        go AAppCmdGainedFocus | engAccelerometerSensor eng /= nullPtr = do
          c_ASensorEventQueue_enableSensor (engSensorEventQueue eng) (engAccelerometerSensor eng)
          c_ASensorEventQueue_setEventRate (engSensorEventQueue eng) (engAccelerometerSensor eng) ((1000 `div` 60) * 1000)
          return (Nothing, Nothing)
        go AAppCmdLostFocus = do
          when (engAccelerometerSensor eng /= nullPtr) $ void $
            c_ASensorEventQueue_disableSensor (engSensorEventQueue eng) (engAccelerometerSensor eng)
          let eng' = eng { engAnimating = 0 }
          engineDrawFrame eng'
          return (Nothing, Just eng')
        go _ = return (Nothing, Nothing)
~~~

## 全てをつなげる簡易フレームワーク

engineDrawFrame、eHandleInput、eHandleCmdという3つの関数が出てきたでゲソが、
これらは誰が呼び出すんでゲソ？
呼び出す人が誰もいないなら動作するはずないじゃなイカ。
ここらへんの呼び出しはめんどうなのでフレームワークで包んでみたでゲソ。

[https://github.com/ajhc/demo-android-ndk/blob/master/cube/hs_src/Main.hs#L13](https://github.com/ajhc/demo-android-ndk/blob/master/cube/hs_src/Main.hs#L13)

~~~ {.haskell}
androidActs :: AndroidNdkActs
androidActs = AndroidNdkActs { drawFrame = engineDrawFrame
                             , initDisplay = engineInitDisplay
                             , handleInput = eHandleInput
                             , handleCmd = eHandleCmd }

foreign export ccall "engineHandleInput" engineHandleInput :: FuncHandleInput
foreign import ccall "&engineHandleInput" p_engineHandleInput :: FunPtr FuncHandleInput
engineHandleInput :: FuncHandleInput
engineHandleInput = handleInputHs androidActs

foreign export ccall "engineHandleCmd" engineHandleCmd :: FuncHandleCmd
foreign import ccall "&engineHandleCmd" p_engineHandleCmd :: FunPtr FuncHandleCmd
engineHandleCmd :: FuncHandleCmd
engineHandleCmd = handleCmdHs androidAct

--snip--
foreign export ccall "androidMain" androidMain :: Ptr AndroidApp -> IO ()
androidMain :: Ptr AndroidApp -> IO ()
androidMain = androidMainHs androidActs p_engineHandleInput p_engineHandleCmd
~~~

![](/draw/20131217_android-fw.png)

このコード少しわかりにくいので図にしてみたでゲソ。
Androidアプリが起動するとまず最初にandroidMain関数が実行されるんでゲソ。
つまりandroidMain関数はこのアプリでのエントリポイントでゲソ。
この関数はC言語から呼び出せるengineHandleInput、engineHandleCmdという関数と共に4つの関数を内包したAndroidNdkActs型をHaskellで作られたAndroidフレームワークの初期化関数androidMainHsに渡すんじゃなイカ。
このフレームワーク側ではAndroid本体からイベントがあると、
いいかんじな処理をした後にAndroidNdkActs型の中の適切な関数を呼び出してアプリを動作させるんでゲソ。
例えば、タッチパネルが操作されてたらイカのような手順で関数が呼び出されることになるでゲソ。

1. C言語がengineHandleInput関数を呼び出す
2. engineHandleInput関数がフレームワークのhandleCmdHs関数を呼び出す
3. いいかんじの処理が走る
4. フレームワークがAndroidNdkActs型の中からeHandleInput関数を選択して呼び出す
5. eHandleInput関数がAndroidEngine型の中の状態を書き換える

じゃぁ親玉であるandroidMain関数はどこから呼ばれるかというと、
C言語のエントリポイントが呼び出すんでゲソ。

[https://github.com/ajhc/demo-android-ndk/blob/master/cube/jni/main.c#L31](https://github.com/ajhc/demo-android-ndk/blob/master/cube/jni/main.c#L31)

~~~ {.c}
void android_main(struct android_app* state) {
	app_dummy(); // Make sure glue isn't stripped.

	// Init & run Haskell code.
	int hsargc = 1;
	char *hsargv = "q";
	char **hsargvp = &hsargv;

	hs_init(&hsargc, &hsargvp);
	androidMain(state);
	hs_exit();
}
~~~

なんかわかったような気になったじゃなイカ!
