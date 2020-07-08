+++
title = "Diving deep into Android Dex bytecode"
date = "2020-02-02"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["android", "dex", "bytecode"]
keywords = []
description = "Analyzing memory and performance of our code at the low-level."
showFullContent = false
+++

![[Source](https://unsplash.com/photos/5MvL55-rSvI)](https://images.unsplash.com/photo-1501721709601-744e5bf3440d?ixlib=rb-1.2.1&auto=format&fit=crop&w=1357&q=80)*[Source](https://unsplash.com/photos/5MvL55-rSvI)*

> [![](https://img.shields.io/badge/original-proandroiddev-green)](https://proandroiddev.com/diving-deep-into-android-dex-bytecode-48db82b170c8)
[![](https://img.shields.io/badge/proandroiddevdigest-15-green)](https://proandroiddev.com/proandroiddev-digest-15-b467005869ce)

## Introduction

Modern Android development is based on Kotlin, which is interoperable with Java. Whenever we use some cool feature from Kotlin (say High-order functions) under the hood (when running on JVM) the feature is implemented in terms of Java bytecode. This might lead to some overheads in memory and performance if used without caution (for example excessive usage of lambdas with parameters without inlining might produce a lot of anonymous classes and put additional pressure on GC).

In order to get some insight on the performance and memory we can look at Java bytecode (or decompile from it to .java files). This way we might see some additional classes instantiated, or variables etc.
But one thing about analyzing such bytecode is that actually it won’t be run on the device. Before running on Android all the compiled code (.class files) are compiled into .dex files. This is so called [Dalvik bytecode](https://source.android.com/devices/tech/dalvik/dalvik-bytecode).

Dalvik Virtual Machine is where Android apps were run prior to Lollipop. After that we have new [Android Runtime (ART)](https://source.android.com/devices/tech/dalvik) with a lot of different optimizations. And that new runtime is compatible with dex.

But that’s not all — between compiling our code to .class and creating .dex files from it there are additional things to note:

* previously for creating .dex file dex tool was used, now it is replaced with d8 [tool](https://developer.android.com/studio/command-line/d8).

* also now we have r8 [tool ](https://r8.googlesource.com/r8/+/master/README.md)which adds additional optimizations to d8.

So, as you can see from the compilation start till the time when we have our dex file there are quite a lot of tools which can work: kotlinc, javac, r8.

In this article we’ll try to look at some examples on how to investigate what will be the result of compiling our code.
> This article was inspired by [series of posts about d8 and r8](https://jakewharton.com/blog/) by Jake Wharton. And I highly recommend anyone who is interested to read them. Also I encourage you to read content of the links in this article as they will be useful for broader understanding.
Here we’ll go through some practical guide on how to get used to new tools and see the resulting bytecode.

## Setup

### Kotlinc

First of all we’ll need to download kotlinc — Kotlin compiler for command line. And add it to your system paths.
[**Working with the Command Line Compiler**
*Every release ships with a standalone version of the compiler. We can download the latest version (…*kotlinlang.org](https://kotlinlang.org/docs/tutorials/command-line.html)

### Java

In order to run our dex-tools we’ll need to have Java setup. Choose any you’ll get comfortable with and add it to your system paths.

### D8/R8

Next we download D8/R8 sources from its repository (see instructions following the [link](https://r8.googlesource.com/r8/+/master/README.md)) and build.
> **NOTE**: do not forget that R8 depends on the [depot_tools](https://www.chromium.org/developers/how-tos/install-depot-tools), which you should download and add to your system paths before proceed.
Also to build D8/R8 you’ll need then to execute: “tools/gradle.py d8 r8".
Jar files which we’ll use will be under /build/libs folder.

### Commands

These are the commands which we’ll use throughout the article.

Compile all the kotlin files in the current directory:

    kotlinc *.kt

Package all the .class files into dex file (with r8 optimizations):

    java -jar r8.jar --lib $ANDROID_HOME/platforms/android-29/android.jar --release --output . --pg-conf rules.txt *.class

Provided --pg-conf is a proguard rules file, in which we’ll add to keep main function and skip obfuscation (for our readability):

    -keepclasseswithmembers class * {
        public static void main(java.lang.String[]);
    }
    -dontobfuscate

Dump content of .dex file to see its contents.

    $ANDROID_HOME/build-tools/29.0.2/dexdump -d classes.dex

## Verify setup

In order to verify your setup works, you can go through [this article](https://jakewharton.com/r8-optimization-staticization/) and see whether you get similar results. Or try to follow examples below.

## Example 1 (where no class is instantiated)

In first our example let’s look at following program:

    fun main() {
        print(Runner().run(5))
    }
    
    private class Runner {
    
        fun run(x: Int): Int {
            return x + 1
        }
    }

Here we basically provide input and print incremented value of it.
> **NOTE**: this is a template which we’ll use. We’ll have main function and some Runner class in which there will be some logic we’ll try to test.

We then run our kotlin compiler, run r8 over compiled .class files and then run dexdump and get following result:

    Processing 'classes.dex'...
    Opened 'classes.dex', DEX version '035'
    Class #0            -
      Class descriptor  : 'LMainKt;'
      Access flags      : 0x0011 (PUBLIC FINAL)
      Superclass        : 'Ljava/lang/Object;'
      Interfaces        -
      Static fields     -
      Instance fields   -
      Direct methods    -
        #0              : (in LMainKt;)
          name          : 'main'
          type          : '([Ljava/lang/String;)V'
          access        : 0x1009 (PUBLIC STATIC SYNTHETIC)
          code          -
          registers     : 2
          ins           : 1
          outs          : 2
          insns size    : 7 16-bit code units
    000114:                                        |[000114] MainKt.main:([Ljava/lang/String;)V
    000124: 1261                                   |0000: const/4 v1, #int 6 // #6
    000126: 6200 0000                              |0001: sget-object v0, Ljava/lang/System;.out:Ljava/io/PrintStream; // field@0000
    00012a: 6e20 0100 1000                         |0003: invoke-virtual {v0, v1}, Ljava/io/PrintStream;.print:(I)V // method@0001
    000130: 0e00                                   |0006: return-void
          catches       : (none)
          positions     : 
            0x0001 line=1
          locals        :

    Virtual methods   -
      source_file_idx   : 0 ()

It is not very long file (later we won’t paste whole listing as it might be too long).
Here we have two interesting things:

* there is no Runner class instantiated at all

* there is no increment operation in code

While first is pretty easy to see (we just don’t have Runner mentioned), second we’ll try to investigate deeper.
For this let’s look at the content of the main function:

    [000114] MainKt.main:([Ljava/lang/String;)V
    0000: const/4 v1, #int 6 // #6
    0001: sget-object v0, Ljava/lang/System;.out:Ljava/io/PrintStream; // field@0000
    0003: invoke-virtual {v0, v1}, Ljava/io/PrintStream;.print:(I)V // method@0001
    0006: return-void

Looking at bytecode one by one:

* [000114] — declaring our main function

* 0000 — loading integer constant 6 into v1 register (so here there is no increment at runtime, during compile time value was calculated and it loaded as constant)

* 0001 — we get Java PrintStream reference and store it in v0 reference

* 0003 — we invoke print method on the v0 (which is PrintStream) providing v1 as param (which is our constant 6)

* 0006 — return from function with void

Not that difficult right? Next let’s look at some other examples.

## Example 2 (where extension function is not called… almost)

Next example looks the following way:

    fun main() {
        println("Hello world".calculate())
    }
    
    fun String.calculate(): Int {
        return this.length * 2
    }

We have extension function on String, which we call on some “Hello World” and print result.

During r8 work we’ll see the warning:

    Warning in MainKt.class:

    Type `kotlin.jvm.internal.Intrinsics` was not found, it is required for default or static interface methods desugaring of `int MainKt.calculate(java.lang.String)`

And in resulting dex file we’ll see that our extension function is still in the bytecode:

    ...
    [00017c] MainKt.calculate:(Ljava/lang/String;)I
    0000: const-string v0, "$this$calculate" // string@0001
    0002: invoke-static {v1, v0}, Lkotlin/jvm/internal/Intrinsics;.checkParameterIsNotNull:(Ljava/lang/Object;Ljava/lang/String;)V // method@0004
    0005: invoke-virtual {v1}, Ljava/lang/String;.length:()I // method@0003
    0008: move-result v1
    0009: mul-int/lit8 v1, v1, #int 2 // #02
    000b: return v1
    ...
    [0001a4] MainKt.main:([Ljava/lang/String;)V
    0000: const-string v1, "Hello world" // string@0002
    0002: invoke-static {v1}, LMainKt;.calculate:(Ljava/lang/String;)I // method@0000
    0005: move-result v1
    0006: sget-object v0, Ljava/lang/System;.out:Ljava/io/PrintStream; // field@0000
    0008: invoke-virtual {v0, v1}, Ljava/io/PrintStream;.println:(I)V // method@0002
    000b: return-void
    ...

First we see that there is our calculate method and inside main function that method is called with invoke-static.
That happens because kotlin adds Intrinsics checks (to verify that params are not null) and because implementation of Intrinsics wasn’t found by r8 it won’t be able to optimize this code.

If we provided Intrinsics implementation, then there will be some optimization. But instead of doing that (as it will require some additional mangling of our setup) we’ll ask kotlin to not generate Intrinsics code by running:

    kotlinc *.kt -Xno-param-assertions
> **NOTE**: think carefully before doing same in production

After that we’ll see the following bytecode:

    [000114] MainKt.main:([Ljava/lang/String;)V
    0000: const/16 v1, #int 22 // #16
    0002: sget-object v0, Ljava/lang/System;.out:Ljava/io/PrintStream; // field@0000
    0004: invoke-virtual {v0, v1}, Ljava/io/PrintStream;.println:(I)V // method@0001
    0007: return-void

Again we have everything optimized and final value is calculated at compile time.

## Example 3 (where we encounter overhead)

Next program is the following:

    fun main() {
        println(Runner().run(5))
    }
    
    private class Runner {
        fun run(x: Int): Int {
            return (0..x).sum()
        }
    }

Basically we’d like to calculate sum of arithmetic progression from 0 and step 1.

When we run R8 we’ll see the following warning:

    Warning in Runner.class:

    Type `kotlin.collections.CollectionsKt` was not found, it is required for default or static interface methods desugaring of `int Runner.run(int)`

This time as we’ve used sum function which is part of kotlin stdlib in order to have r8 work correctly we’ll need to add kotlin stdlib to classpath.

Download latest kotlin stdlib jar version from [maven](https://mvnrepository.com/artifact/org.jetbrains.kotlin/kotlin-stdlib/1.3.61).
And add it to classpath when r8 works:

    $ java -jar r8/build/libs/r8.jar --lib $ANDROID_HOME/platforms/android-29/android.jar **--lib kotlin-stdlib-1.3.61.jar** --release --output . --pg-conf rules.txt *.class

Then after compilation we’ll see no warnings. Let’s find our what will be inside our bytecode. Unfortunately the result won’t be that great:

    ...
    [0001c4] MainKt.main:([Ljava/lang/String;)V
    0000: new-instance v1, LRunner; // type@0002
    0002: invoke-direct {v1}, LRunner;.<init>:()V // method@0001
    0005: const/4 v0, #int 5 // #5
    0006: invoke-virtual {v1, v0}, LRunner;.run:(I)I // method@0002
    0009: move-result v1
    000a: sget-object v0, Ljava/lang/System;.out:Ljava/io/PrintStream; // field@0000
    000c: invoke-virtual {v0, v1}, Ljava/io/PrintStream;.println:(I)V // method@0003
    000f: return-void
    ...
    [0001f4] Runner.run:(I)I
    0000: new-instance v0, Lkotlin/ranges/IntRange; // type@0008
    0002: const/4 v1, #int 0 // #0
    0003: invoke-direct {v0, v1, v3}, Lkotlin/ranges/IntRange;.<init>:(II)V // method@0006
    0006: invoke-static {v0}, Lkotlin/collections/CollectionsKt;.sumOfInt:(Ljava/lang/Iterable;)I // method@0005
    0009: move-result v3
    000a: return v3
    ...

We see that we still have our Runner instantiated, inside we create separate IntRange instance, on which we invoke static method CollectionsKt.sumOfInt.
So in this example we didn’t get precalculated result inlined.
> If anyone knows why exactly that happened or what can be added during compilation or r8 to make it work feel free to leave a comment.

## Example 4 (where we fix overhead from Example 3)

As we’ve analyzed particular use case in Example 3 and see that there is some room for improvements, let’s try to utilize this:

    fun main() {
        println(Runner().run(5))
    }
    
    private class Runner {
        fun run(x: Int): Int {
            var result = 0
            for (i in 0..x) {
                result += i
            }
            return result
        }
    }

This is equivalent code to calculate arithmetic sum as in Example 3. Note, that here we also use range inside for-loop.

And here is the result:

    [000114] MainKt.main:([Ljava/lang/String;)V
    0000: const/4 v2, #int 0 // #0
    0001: const/4 v0, #int 0 // #0
    0002: add-int/2addr v2, v0
    0003: const/4 v1, #int 5 // #5
    0004: if-eq v0, v1, 0009 // +0005
    0006: add-int/lit8 v0, v0, #int 1 // #01
    0008: goto 0002 // -0006
    0009: sget-object v0, Ljava/lang/System;.out:Ljava/io/PrintStream; // field@0000
    000b: invoke-virtual {v0, v2}, Ljava/io/PrintStream;.println:(I)V // method@0001
    000e: return-void

What we see is that:

* there is no Runner class instantiated

* there is no IntRange instantiated

* instead we have general for-loop inside bytecode to calculate result

Let’s look one by one what is happening here (to check what particular bytecode operation means you can refer to [docs](https://source.android.com/devices/tech/dalvik/dalvik-bytecode)):

* 0000 — we move constant value (0) into register v2 (our result)

* 0001 — same we move constant value (0) into register v0 (our current index)

* 0002 — performs sum of two variables (v2 and v0) storing result in first one (v2) — the result will be 0

* 0003 — move value of constant (5) into register v1 (this is our upper-bound)

* 0004 — we make a comparison of v0 and v1 and if they are equal then we exit loop. This time v0 == 0 and v1 == 5 therefore we still inside loop.

* 0006 — we add value of int 1 to our register v0 storing result in v0 (incrementing index)

* 0008 — we go to the next iteration of the loop (at index 0002) where we again will add current index to result, perform check to exit the loop and repeat.

* After all we print result

So, we did better that before and should be probably a bit happy :)

## Conclusion

Here in this article we saw in practice how we can analyze dex bytecode and with help of r8 in some cases have it optimized (despite Java bytecode is not).
The key takeaways should be the following: even when you try to optimize your code written in Kotlin to make it faster or consume less memory, and even when you look at Java bytecode after your code is compiled, you should also pay attention to dex bytecode and look at the tools such as r8 to make them do their job while keeping your codebase clean.

This article is not about telling you that you should not optimize your code in the first place (but actually you shouldn’t, write correct first and then optimize where needed), it is mostly about knowledge that current development ecosystems are quite complex and it is difficult to know what is actually happening at the lower levels. Therefore it might be useful to know the tools which might help you to identify places for performance or memory improvements where you need them.

Think about optimizations, write fast code which consumes less memory but don’t forget to profile first.

Happy coding!