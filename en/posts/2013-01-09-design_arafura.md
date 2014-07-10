---
title: Arafura Design
description: Get first design for Metasepi kernel.
tags: haskell, design, specification, bootloader
---

Can't get design, even repeating the research. It might be a good idea to
make something at first step? Let's decide a rough sketch before writing the
code. This blog entry will be rewritten some times.

## First design

We discuss "[Are there OS designed with
Haskell/OCaml?](2012-08-18-haskell-or-ocaml-os.html)" already.
The person living in real world has no time to get clean design of
Functional OS,
that be eaten as dog food.
^[[Eating your own dog food -
Wikipedia](http://en.wikipedia.org/wiki/Eating_your_own_dog_food)]
It may be better than it to rewrite a just monolithic kernel with functional
language.

We selected the NetBSD as a monolithic kernel for rewriting. There is my
hobby simply reasons, such as easy-to-read source code.

The rewrite from scratch in typed language suddenly the NetBSD kernel
written in the C language also is still severe. I want a little more
comfortable? So but not all suddenly, and re-implement the same
functionality in the typed language a little bit at a time while keeping a
compilable / executable state. If you go with the type little by little, all
the code I might be to work with typed language one day?

![](/draw/2012-12-27-arafura_design.png)

I think it tries to call the Arafura this design of "snatch little by little
in the typed language NetBSD kernel". That's good to sail the name of the
sea starting from "A", the first! (Also, small squid to change the color is
a type of cuttlefish, Metasepia pfefferi is lived, Arafura of the
Portuguese, which means "free man" But. is the origin so the archaic word
"shallow consisting of a coral reef in many cases, where a failure of
navigation also have a large number" when you fail to sail in this sea if
...) Yes, the sea that begins with "B" this time it's okay if you choose
(design). I'm "Never give up" the watchword!

## Just do it!

We have known jhc may be useful to develop Metasepi kernel.
If snatch NetBSD kernel, we should write interrupt handler with Haskell
language.
It's so difficult for us, today.
Then, let's snatch bootloader that has more easy design than NetBSD kernel.
Everything starts at training.

![](/draw/2012-12-27-loader.png)

Structure of the module of NetBSD bootloader is as shown in the above
figure.
Following code is the boot2.c command line loop rewrited with jhc and
Haskell language.
^[[Source
code](https://gitorious.org/metasepi/netbsd-arafura/blobs/52c9e9c31425bdf983d0850b4e503c899a511edc/metasepi-arafura/sys/arch/i386/stand/boot/Boot2Ara.hs)]

~~~ {.haskell}
import Control.Monad
import Data.Maybe
import Data.Map (Map)
import qualified Data.Map as Map
import Foreign.C.Types
import Foreign.Ptr

foreign import ccall "glue_netbsdstand.h command_boot" c_command_boot :: Ptr
a -> IO ()

commands :: Map String (IO ())
commands = Map.fromList [("help", command_help),
                         ("?", command_help),
                         ("boot", c_command_boot nullPtr)]

command_help :: IO ()
command_help = putStr $ "\
\commands are:\n\
\boot [xdNx:][filename] [-12acdqsvxz]\n\
\     (ex. \"hd0a:netbsd.old -s\"\n\
--snip--
\help|?\n\
\quit\n"

main :: IO ()
main = do
  putStrLn "Haskell bootmenu"
  forever $ do
    putStr "> "
    s <- getLine
    fromMaybe (putStr s) $ Map.lookup s commands
~~~

Display of help is as good Well, I'm throwing circle at FFI to existing code
reads + boot kernel. Let's compiled in such a way of utilizing these source
code.

![](/draw/2012-12-27-compile.png)

Let's run Metasepi arafura version of bootloader on qemu (2:15 at following
video)!

<iframe width="420" height="315" src="//www.youtube.com/embed/0DPA7GC0_-0"
frameborder="0" allowfullscreen></iframe>

Starting the kernel and display of help seems to be. First I do not want to
misunderstand earnestly by the way!'s Successful experiment, 99% of the
bootloader that I made this time but that it's still made ​​by C
language. It is as shown in the figure below and try to draw a sequence
diagram the movement of this bootloader.

![](/draw/2013-01-09-sequence_diagram.png)

Part sorry! Bottom line remains the C language source code of existing
what. But by repeating snatch little by little from now, be described in
typed language like Haskell many parts of the sequence shown above and not
something a dream?

## Known problems

Snatch of bootloader has just begun.
Not yet snatch kernel, we can find many problems with snatching the small
module such as bootloader.

a. Be able to handle command-line arguments.
b. Should be able to debug custom RTS in user space. We have found problems
at custom RTS side frequently.
c. Use the fixed memory area for GC heap allocator. ^[We can use extended
memory (more than 1 MB) on Intel arch. But it's useful running in
conventional memory (less than 1 MB) for the other use case]
d. Isolate malloc's heap and Haskell's heap. Haskell's heap press malloc's
heap with the RTS implementation in this article.

Next action item is surveying more detail of jhc internel.
But, more snatching this bootloader may be also good idea to understand more
problems.
