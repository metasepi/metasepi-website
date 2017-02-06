---
title: Hands-on VeriFast with STM32 microcontroller
description: Verify ChibiOS/RT sample application using VeriFast
tags: c, verifast, stm32, arm, chibios
---

![](/img/NUCLEO-F091RC.jpg)

We had "Hands-on VeriFast with STM32 microcontroller" on [静的コード解析の会](https://metasepi.connpass.com/event/45594/) at [Tokyo](https://en.wikipedia.org/wiki/Tokyo).

This hands-on purpose is that non-professional person for embedded programming understands the development method and verification using [VeriFast](https://people.cs.kuleuven.be/~bart.jacobs/verifast/). The VeriFast is a verifier for single-threaded and multithreaded C language programs annotated with preconditions and postconditions written in separation logic. And VeriFast is easy to use with the graphical IDE.

The hands-on was going as following steps:

* Introduce [ChibiOS/RT](http://www.chibios.org/) which is a RTOS
* Get development environment for ChibiOS/RT
* Build sample application on ChibiOS/RT
* Introduce [STM32](http://www.st.com/content/st_com/en/products/microcontrollers/stm32-32-bit-arm-cortex-mcus.html) microcontroller
* Run the application on STM32 board
* Introduce VeriFast
* Verify the application using VeriFast

All of participants have had VeriFast verification platform, and feel the verification way of VeriFast for ChibiOS/RT on STM32 microcontroller. STMicroelectronics kindly gives me their MCU board [NUCLEO-F091RC](https://developer.mbed.org/platforms/ST-Nucleo-F091RC/), for free. Thanks a lot!

We are planning same hands-on on [OSC2017](https://www.ospn.jp/osc2017-do/) at [Hokkaido](https://en.wikipedia.org/wiki/Hokkaido). Let's propagandize verification method by VeriFast for embedded application!

## Source code

* [https://github.com/fpiot/chibios-verifast](https://github.com/fpiot/chibios-verifast)

## Slide

<iframe src="//www.slideshare.net/slideshow/embed_code/key/ECKlZ2g2hdkFlF" width="595" height="485" frameborder="0" marginwidth="0" marginheight="0" scrolling="no" style="border:1px solid #CCC; border-width:1px; margin-bottom:5px; max-width: 100%;" allowfullscreen> </iframe> <div style="margin-bottom:5px"> <strong> <a href="//www.slideshare.net/master_q/handson-verifast-with-stm32-microcontroller" title="Hands-on VeriFast with STM32 microcontroller" target="_blank">Hands-on VeriFast with STM32 microcontroller</a> </strong> from <strong><a target="_blank" href="//www.slideshare.net/master_q">Kiwamu Okabe</a></strong> </div>

## Participants

![](/img/2017-02-05-verifast-hands-on-participants.jpg)
