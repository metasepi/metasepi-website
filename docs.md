# Documents

## Publications

### In English

#### Experience Report: Writing NetBSD Sound Drivers in Haskell - A Reentrant Haskell Compiler for Operating Systems Programming

* Author: Kiwamu Okabe, Takayuki Muranushi
* Abstract: Most strongly typed, functional programming languages are not equipped with a reentrant garbage collector.  This is the reason why such languages are not used for operating systems programming, where the virtues of types are most desired.  We propose use of Context-Local Heaps (CLHs) to achieve reentrancy, also increasing the speed of garbage collection.  We have implemented CLHs in Ajhc, a Haskell compiler derived from jhc, rewrote some NetBSD sound drivers using Ajhc, and benchmarked them.  The reentrant, faster garbage collection that CLHs provide opens the path to type-assisted operating systems programming.
* PDF: [metasepi-icfp2014.pdf](doc/metasepi-icfp2014.pdf)


### In Japanese

#### 強い型によるOSの開発手法の提案

* Author: Kiwamu Okabe, Hiroki MIZUNO, Hidekazu SEGAWA
* Abstract: 現在でもOSはC言語によって設計されている．一方アプリケーションは強い型付けの言語を用いた安全な設計手法が確立されている．本稿ではOSの安全な設計手法として，C言語によって設計されたOSのソースコードを元に少しずつ型推論をそなえた言語による実装に置き換えるスナッチ設計という手法を提案する．また当該手法を小規模OSに対して適用し，その結果を考察する．
* PDF: [20140110_prosym55.pdf](doc/20140110_prosym55.pdf)
