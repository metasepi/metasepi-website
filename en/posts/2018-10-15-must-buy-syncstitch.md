---
title: You must buy SyncStitch with only 64,800 JPY!
description: Dive into CSP (Communicating Sequential Processes) modeling.
tags: csp, modeling
---

![](/img/hatsugai-talking.jpg)

## TL;DR

If you are using Windows or Linux, you must buy [SyncStitch with only 64,800 JPY](https://www.principia-m.com/syncstitch/license.html)!

## About CSP and SyncStitch

We had "SyncStitch hands-on" on [静的コード解析の会](https://metasepi.connpass.com/event/88027/) at [Tokyo](https://en.wikipedia.org/wiki/Tokyo).
This hands-on purpose is to introduce [CSP (Communicating Sequential Processes)](https://en.wikipedia.org/wiki/Communicating_sequential_processes) and use [SyncStitch](https://www.principia-m.com/syncstitch/) to get modeling on [concurrent systems](https://en.wikipedia.org/wiki/Concurrency_(computer_science)).

On CSP, developer can write Specification model and split it into some Implementation models connected by channel.

![](/img/2018-10-15-04_correctness_eng.png)

After getting models, developer can get correctness relation using SyncStitch.

## Install SyncStitch

* Download SyncStitch from [here](https://www.principia-m.com/syncstitch/download.html)
* Buy [License of SyncStitch](https://www.principia-m.com/syncstitch/license.html)
* Unzip SyncStitch:

```shell
$ sudo apt install unar gcc fonts-open-sans fonts-inconsolata
$ mkdir $HOME/bin
$ cd $HOME/bin
$ unar SyncStitch-linux.zip
$ cd SyncStitch-linux/bin
$ chmod +x ssg ssgsvr syncstitch
$ export PATH=$(pwd):$PATH
```

* Edit `$HOME/.syncstitch`:

```shell
$ vi $HOME/.syncstitch
(
; (dpi . 96)
 (system-font-face . "Open Sans")
 (system-font-size . 11)
 (small-font-size . 9)
 (code-font-face . "Inconsolata")
 (code-font-size . 12)
 (handle-size . 3)
 (syncstitch
 (license-key . "___YOUR OWN LICENSE KEY___")
  (node . "127.0.0.1")
;  (node . "::1")
  (service . "50000"))
)
```

## Launch SyncStitch

* Run `ssgsvr`

```shell
$ (cd $HOME/bin/SyncStitch-linux/bin && ./ssgsvr)
num_workers:     1
heap_size (GiB): 1
hashtable size:  4000037
port no:         50000
```

* Launch `syncstitch` on the other terminal

```shell
$ syncstitch
```

* You should show a green window which is the SyncStitch GUI
* Click the right button of your mouse and select "New model"

![](/img/2018-10-15-new-model.png)

* A window for a new model will open.

![](/img/2018-10-15-process-list.png)

## Try to open an existing model

* Open "File" menu, and select "Open"

![](/img/2018-10-15-file-menu.png)

* Open `SyncStitch-linux/models/stack_queue.ss` file

![](/img/2018-10-15-open-ringbuf_sem.png)

* You should show Process list and Assertions

![](/img/2018-10-15-ringbuf_sem-windows.png)

* Click the right button of your mouse and select "checkall"

![](/img/2018-10-15-ringbuf_sem-checkall.png)

* You should show that the ring buffer `SYSTEM` is soundness in CSP!

![](/img/2018-10-15-ringbuf_sem-checked.png)

## More

Please read `SyncStitch-linux/doc/SyncStitch_Users_Guide.pdf`.
You can feel free to tweet with [hastsugai](https://twitter.com/hatsugai), or e-mail isaac@principia-m.com.

## Copyright of this blog post

Copyright (C) 2018 [PRINCIPIA Limited](https://www.principia-m.com/).
