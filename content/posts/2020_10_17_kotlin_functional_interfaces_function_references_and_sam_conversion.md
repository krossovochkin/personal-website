+++
title = "Kotlin Functional Interfaces: Function reference and SAM conversion"
date = "2020-10-17"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["kotlin"]
keywords = ["kotlin", "sam", "functional interface"]
description = "Overview of Kotlin functional interfaces and how they work with SAM conversions."
showFullContent = false
+++

[![](https://img.shields.io/badge/kotlinweekly-220-purple#badge)](https://mailchi.mp/kotlinweekly/kotlin-weekly-220)


### Introduction

About two years ago I [made a post](https://medium.com/@krossovochkin/kotlin-java-interop-function-references-and-sam-conversions-3d0cd36f7967) about a tricky case in Kotlin-Java interop related to the usage of function references and SAM conversion.
One of the points there was that in Kotlin, if interface is declared instead of a function, one has to explicitly create an object, therefore no caveats as with interop:
```kotlin
val callback = object : ThirdParty.Callback {
    override fun onValueChanged(value: Int) {
        this@App.onValueChanged(value)
    }
}
```

With Kotlin 1.4 there is now a "Functional interface" which supports SAM conversion. And [I've been asked](https://medium.com/@mwolfe38/does-the-new-kotlin-1-4-sam-interfaces-using-fun-interface-declaration-have-similar-issues-1b08fa65a096) on how it works in a similar situation.  
Let's find out.

### Setup

First, let's make our setup with Kotlin. We have our ThirdParty class which manages the callbacks:
```kotlin
class ThirdParty {

    private val callbacks = mutableListOf<Callback>()

    fun addCallback(callback: Callback) {
        println("addCallback: $callback")
        callbacks += callback
    }

    fun removeCallback(callback: Callback) {
        println("removeCallback: $callback")
        callbacks -= callback
    }

    fun printState() {
        println("Callbacks count: ${callbacks.size}")
    }

    fun interface Callback {

        fun onValueChanged(value: Int)
    }
}
```

And our client code in which we'll add and remove our callback:
```kotlin
fun main() {
    val callback: (Int) -> Unit = ::onValueChanged
    println("callback created: $callback")

    val thirdParty = ThirdParty()

    thirdParty.printState()
    thirdParty.addCallback(callback)
    thirdParty.printState()
    thirdParty.removeCallback(callback)
    thirdParty.printState()
}

private fun onValueChanged(value: Int) {

}
```

We create a function (from a private member) with a help of method reference. Then add and remove it printing state of our ThirdParty class (how many callbacks are registered).  
If you look at the original story about Kotlin-Java interop, for add and remove separate Java objects are created therefore after removal there still will be 1 callback registered.

Let's run our program:
```
Callbacks count: 0
addCallback: TestKt$sam$ThirdParty_Callback$0@47ef8be8
Callbacks count: 1
removeCallback: TestKt$sam$ThirdParty_Callback$0@47ef8be8
Callbacks count: 0
```

Here we see that our program worked correctly. Seems callback objects are the same.

### Bytecode

Let's look on how that is achieved in the bytecode. For `addCallback` line we have:
```kotlin
  L7
    LINENUMBER 8 L7
    ALOAD 1
    ALOAD 0
    DUP
    IFNULL L8
    ASTORE 2
    NEW TestKt$sam$ThirdParty_Callback$0
    DUP
    ALOAD 2
    INVOKESPECIAL TestKt$sam$ThirdParty_Callback$0.<init> (Lkotlin/jvm/functions/Function1;)V
   L8
    CHECKCAST ThirdParty$Callback
    INVOKEVIRTUAL ThirdParty.addCallback (LThirdParty$Callback;)V
   L9
```
We create a callback object and pass it to the `addCallback` method.

What about `removeCallback`:
```kotlin
  L10
    LINENUMBER 10 L10
    ALOAD 1
    ALOAD 0
    DUP
    IFNULL L11
    ASTORE 2
    NEW TestKt$sam$ThirdParty_Callback$0
    DUP
    ALOAD 2
    INVOKESPECIAL TestKt$sam$ThirdParty_Callback$0.<init> (Lkotlin/jvm/functions/Function1;)V
   L11
    CHECKCAST ThirdParty$Callback
    INVOKEVIRTUAL ThirdParty.removeCallback (LThirdParty$Callback;)V
   L12
```
Bytecode is the same! We still create a new Callback object.  
So, we create two callback objects. One per each method call. But the program works correctly.

This is because of the inner callback implementation:
```kotlin
final class TestKt$sam$ThirdParty_Callback$0 implements ThirdParty.Callback, FunctionAdapter {
   // $FF: synthetic field
   private final Function1 function;

   TestKt$sam$ThirdParty_Callback$0(Function1 var1) {
      this.function = var1;
   }

   // $FF: synthetic method
   public final void onValueChanged(int value) {
      Intrinsics.checkExpressionValueIsNotNull(this.function.invoke(value), "invoke(...)");
   }

   public Function getFunctionDelegate() {
      return this.function;
   }

   public boolean equals(Object var1) {
      return var1 instanceof ThirdParty.Callback && var1 instanceof FunctionAdapter && Intrinsics.areEqual(this.function, ((FunctionAdapter)var1).getFunctionDelegate());
   }

   public int hashCode() {
      return this.function.hashCode();
   }
}
```
Pay attention to the `equals/hashCode`. It is delegated to our original method reference. So, we have two separate objects, but because they use the same function reference and because of the `equals/hashCode` methods delegated to that method reference - they look the same.

That is why we can even write:
```kotlin
fun main() {
    val thirdParty = ThirdParty()

    thirdParty.printState()
    thirdParty.addCallback(::onValueChanged)
    thirdParty.printState()
    thirdParty.removeCallback(::onValueChanged)
    thirdParty.printState()
}
```

And still, we won't have an issue.

> But pay attention that in this case for each method call new Callback object will be created. To optimize consecutive method calls one might consider creating a callback instance manually and pass it explicitly.

With Kotlin 1.4 one don't have to write `object : Callback {}`, it is possible to do:
```kotlin
val callback = ThirdParty.Callback(::onValueChanged)
```
Because functional interfaces support SAM conversion.

### Conclusion

It seems like with Kotlin functional interfaces there is no such issue as in Kotlin-Java interop. The program will work as it was intended.  
But one should anyway be attentive because the program will work correctly at the price of increased memory allocations.  
So, it is still good practice to convert method references into objects explicitly without relying on the compiler.

Happy coding.