+++
title = "Java-C-Assembly Matryoshka"
date = "2019-06-04"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["other"]
keywords = ["java", "c", "assembly"]
description = ""
showFullContent = false
+++

![](https://images.unsplash.com/photo-1544885353-f3e1da5bc721?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=1288&q=80)
*[Source](https://unsplash.com/photos/9hhOVsf1lpU)*

[![](https://img.shields.io/badge/original-medium-green#badge)](https://medium.com/hackernoon/java-c-assembly-matryoshka-932193f071d3) [![](https://img.shields.io/badge/original-hackernoon-green#badge)](https://hackernoon.com/java-c-assembly-matryoshka-932193f071d3)

> **Disclaimers**: 
> - I’ll use Windows and more particularly Visual C++ with its Inline Assembler. If you use MacOs or Linux you will have significant differences comparing to what is described in the article.
> - Everything below is shown mostly for demonstration purposes

## Introduction

Java is mature self-sufficient language, though as we all know it is possible to “connect” java to C (via Java-Native-Interface or JNI) to speed up some critical pieces of code.
Also for C/C++ it is possible to delegate some even more critical pieces of code directly to Assembly.

In this article I want to show you how this Java-C-Assembly Matryoshka can look like. But note that example will be pretty simple so in real world there is no advantage of such delegation as it won’t speed up anything.

The example we’ll look at will be:

* given a command line program (written in Java)

* we execute the program with providing 2 integers as arguments (with error handling on the client side)

* main business logic is the “sum” method, which we consider a critical piece of the program we’d like to “speed up” using C and Assembly.

## Java

### Setup

First of all we need to download [JDK](https://www.oracle.com/technetwork/java/javase/downloads/java-archive-javase8-2177648.html).
I have pretty old version installed, but feel free to install newer version.
After installation verify that everything works:

```bash
>java -version
java version "1.8.0_121"
Java(TM) SE Runtime Environment (build 1.8.0_121-b13)
Java HotSpot(TM) Client VM (build 25.121-b13, mixed mode, sharing)
```

### Code

Here is our program: main function, parsing command line arguments and our target method “sum” (with implementation in java):

```java
public class Test {
 
    public static void main(String[] args) {
  
        if (args.length != 2) {
            System.out.println("Error: wrong params count");
            return;
        }
  
        int a;
        try {
            a = Integer.parseInt(args[0]);
        } catch (Throwable throwable) {
            System.out.println("First param is not a number");
            return;
        }
  
        int b;
        try {
            b = Integer.parseInt(args[1]);
        } catch (Throwable throwable) {
            System.out.println("Second param is not a number");
            return;
        }
  
        Test test = new Test();
        System.out.println(test.sum(a, b));
    }
 
    public static int sum(int a, int b) {
        return a + b;
    }
}
```

### Compile

In order to run the program we first need to compile it with java compiler. It will generate Test.class binary file which we’ll later on execute.

```bash
> javac Test.java
```

### Execute

To execute program call java and provide arguments. See that our program works correctly and prints sum of numbers.

```bash
> java Test 3 4
7
```

## C/JNI

### Setup

Install [Chocolatey](https://chocolatey.org/) and using it install Visual C++ build tools:

```bash
choco install visualcpp-build-tools
```

We’ll need these tools to compile C files into library dll file. Specifically for compilation we’ll need cl command, so check that it works:

```bash
>cl
Microsoft (R) C/C++ Optimizing Compiler Version 19.16.27031.1 for x86
Copyright (C) Microsoft Corporation.  All rights reserved.
```

### Code

Java can communicate with C via JNI. In order to setup that communication we need to update our Java program:

```java
public class Test {
 
    public static void main(String[] args) {
  
        if (args.length != 2) {
            System.out.println("Error: wrong params count");
            return;
        }
  
        int a;
        try {
            a = Integer.parseInt(args[0]);
        } catch (Throwable throwable) {
            System.out.println("First param is not a number");
            return;
        }
  
        int b;
        try {
            b = Integer.parseInt(args[1]);
        } catch (Throwable throwable) {
            System.out.println("Second param is not a number");
            return;
        }

        System.loadLibrary("Test");
        Test test = new Test();
        System.out.println(test.sum(a, b));
    }
 
    public native int sum(int a, int b);
}
```

First, instead of static method with implementation we provide so called native method. It doesn’t have any implementation because we expect it to be provided via JNI. Second, we need to load our C library — and we do that with System.loadLibrary method.

After we updated our program we need to generate Test.h header file:

```bash
> javah Test
```

Generated header file will contain all the setup for our C program. We had one native method in our Java program and here we have method declaration for our method generated in header file:

```c
/* DO NOT EDIT THIS FILE - it is machine generated */
#include <jni.h>
/* Header for class Test */

#ifndef _Included_Test
#define _Included_Test
#ifdef __cplusplus
extern "C" {
#endif
/*
 * Class:     Test
 * Method:    sum
 * Signature: (II)I
 */
**JNIEXPORT jint JNICALL Java_Test_sum
  (JNIEnv *, jobject, jint, jint);**

#ifdef __cplusplus
}
#endif
#endif
```

We need to have an implementation of our function, so create Test.c file and implement method:

```c
#include "Test.h"

JNIEXPORT jint JNICALL Java_Test_sum
  (JNIEnv *env, jobject obj, jint a, jint b) {
   return a + b;
  }

void main() {}
```

### Compile

Compile our C library into Test.dll:

```bash
> cl -I"%JAVA_HOME%\include" -I"%JAVA_HOME%\include\win32" -LD Test.c -FeTest.dll
```

### Execute

Recompile our Java program as shown above and execute to see that it still works:

```bash
> java Test 3 4
7
```

## Assembly

### Code

Previously we had C implementation which looked basically as on java: a + b. When we work with Assembly we work on a lower level so such small operations require quite more code.
Let’s update our C program to use Assembly — for this we add __asm block — which is Inline Assembler for Visual C++.
Inside that block we write instructions. You see that we put our variable a into register eax, put our variable b into register ebx. Then we make a sum from contents of registers and store it in the eax register (this is what add command does).
Lastly we store value of the eax register in our result field:

```c
#include "Test.h"
#include <stdio.h>

JNIEXPORT jint JNICALL Java_Test_sum
  (JNIEnv *env, jobject obj, jint a, jint b) {
    int result;
    __asm {
        mov eax, a
        mov ebx, b
        add eax, ebx
        mov result, eax
    }
    return result;
}

void main() {}
```

Recompile C library (no need to recompile Java program) and execute Java program again:

```bash
> java Test 3 4
7
```

So, it works.

Hope you’ve enjoyed and maybe learned something today. If not then I hope at least it was funny.

Happy coding!

**References**:  
[**javac - Java programming language compiler**](https://docs.oracle.com/javase/7/docs/technotes/tools/windows/javac.html)  
[**Guide to JNI (Java Native Interface) | Baeldung**](https://www.baeldung.com/jni)  
[**Inline Assembler**](https://docs.microsoft.com/en-us/cpp/assembler/inline/inline-assembler?view=vs-2019)
