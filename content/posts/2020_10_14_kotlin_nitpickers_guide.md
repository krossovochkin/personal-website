+++
title = "Kotlin Nitpicker's guide"
date = "2020-10-14"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["kotlin", "programming", "code review"]
keywords = []
description = ""
showFullContent = false
+++


### Introduction

Code review is an essential tool for a development team, which helps ensure high-quality standards of code. While reviewing others' code one might find bugs, design issues, and so on. One another part of reviewing is getting used to the codebase and following team's code style for better maintenance.
Though it is pretty cool in theory, in practice team might face few issues, one of which is nitpicking. When review is bloated with dozens of similar comments related to e.g. how beautifully code looks like.
Common code style is important, but having a lot of similar comments in each review doesn't help. Instead of trying to understand what code is doing, nitpicker writes a lot of similar comments on the style. Back and forth discussions or fixes of such slow down development process and overall make team's morale worse.

Kotlin is a great language, saves a lot of time on some common tasks.
But with ["idiomatic" code](https://kotlinlang.org/docs/reference/idioms.html) introduced the language becomes the dream of the nitpicker.
"Concise" often is misused with "Short", which ends with "can be shorter" comments. But while it is possible to write something shorter, doesn't mean that it is automatically better.

In this article, I'd like to go through some features of Kotlin, which you can point at the code review to make your reviews useless. In the beginning of each section there will be some anti-suggestion.

### !!

> If you see !! in the code - immediately say that it has to be removed.  
This is a code smell, we might have a crash!

Yes, !! in code should warn you, because the operation is unsafe.
But in some situations, you might be fine with that. Sometimes Kotlin compiler can't infer that the value is not null in some given moment.
And you are 100% sure that it is safe. For example let's take a look at the [reverse list function](https://krossovochkin.github.io/posts/2019_09_27_random_interview_coding_task_retrospective/):

```kotlin
fun <T> Node<T>.reverse(): Node<T> {
    if (this.next == null) {
        return this
    }

    var previousNode: Node<T>? = null
    var currentNode: Node<T>? = this
    var nextNode: Node<T>?

    while (currentNode != null) {
        nextNode = currentNode.next
        currentNode.next = previousNode

        previousNode = currentNode
        currentNode = nextNode

    }

    return previousNode!!
}
```

As variable is nullable, I get nullable result. It is possible to see that if I got to the last return, then `previousNode` can't be null.
Compiler can't infer that, but I, as a developer, can.

This is the case when I think !! is totally legit.

What are other options:
- add comment that !! were added intentionally. Though comments might become outdated in the future.
- use `requireNotNull` - also an option, though it is almost the same.  
Some people vote for that option because it is more explicit.
- add some assertion before to capture impossible case, like:
```kotlin
val prev = previousNode
if (prev == null) {
    throw IllegalStateException()
}
```
Yes, we now even more explicit in our intentions, but we have more bytecode for our solution now.
- variation of previous option with default exception:
```kotlin
return previousNode ?: throw IllegalStateException()
```
- return some default value (like empty Node) would be definitely a mistake.

And probably there are also a lot of many other ways on how to solve that.
Imagine how much time could be spent on discussing various options, especially if all these would be discussed in written form in the review.

Personally, I was also felt pretty negative about !!.  
I think main issue was that a few years ago while we were converting projects from Java to Kotlin, converter automatically added many !! in various places.  
So, if one saw !! in code the first thought was that some compiler "errors" were missed and need to be addressed.  
Currently, I see no issues with !! while writing code. But one should be careful with usages.  

### =

> If you can remove curly braces with = then do that.  
Less lines, less code, better!

In Kotlin it is allowed to omit function body and write `=`.   
For example these are equivalents:  
```kotlin
fun hello(): String {
    return "hello"
}

fun hello(): String = "hello"
```

Using the second option saves you two lines! Let's use it everywhere!  
But there are some caveats.  
First is that it is not required to use `=` only for one-liners:
```kotlin
fun hello(): String =
    "hello"
```
And this variant might look not that awesome.

Second is that we're reading code from top to bottom, right to left. And if we need to "scan" code to find something we usually go top to bottom first and then when we need details we go to the right.
Having return might allow you to see relevant information while going in the "scanning mode", which is not available if you used one-liner with `=`.

I think that it is a matter of taste and agreement in the team. At the same time, I think that there is nothing bad or wrong in using explicit returns.

One good usage of not-one-liner `=` I see in maintaining exhaustive `when`:
```kotlin
fun resolve(orientation: Orientation): Int = when (orientation) {
    HORIZONTAL -> 0
    VERTICAL -> 1
}
```
Here we save some space and at the same time support our "scanning mode" because the right part with `when` here is not that important.

### Implicit return types

> If you can omit return type then do that.  
Less code is better.

Also in Kotlin it is possible to omit return type if we used `=`. If we consider previous example we could write:
```kotlin
fun hello() = "hello"
```
It is clear that return result will be String, so why type it?  
In such simple cases, it might be good, but there are also caveats here. If we have non-"primitive" return type we might face a situation like:
```kotlin
fun getFactory() = FactoryImpl()
```
Return type will be inferred as `FactoryImpl` while we might want to have `Factory` interface instead. It becomes even worse if this method is part of our public API and we exposed implementation instead of an interface, which might lead to issues with later maintenance.

Again, I see nothing bad in using explicit return types everywhere.  
It is fine to omit return type for private or internal functions, but for public API explicit return types are a must.

### Implicit variable types

> If you can omit variable type, then do.  
Less code is better.

Kotlin compiler can infer types. So when in java we have to write:
```java
final Object object = new Object();
```
in Kotlin it is just:
```kotlin
val object = Object()
```

First note on this is similar to previous note on implicit return type: if you create implementation on the right side, then it might be a good move to declare variable type explicitly. Especially, if that variable is part of public API.

Second note is about primitive numbers initialization.  
Unlike Java in Kotlin there is no auto-convert between primitive numbers. When in Java it is possible to write:
```java
float a = 0.4;
int b = a;
```
in Kotlin explicit conversion is required:
```kotlin
val a: Float = 0.4f
val b: Int = a.toInt()
```

And here we get to the caveat: it is so tempting to omit variable type here, because value is `0.4f` - it is float. If it was `0.0` then it would be double, if `0L` then long and if just 0 then Int. It is clear and idiomatic!  
But there is nothing wrong with using explicit variable types:
```kotlin
val long1 = 1_000_000L
val long2: Long = 1_000_000

val float1 = 0.004304939340f
val float2: Float = 0.004304939340f
```
If the number is big and you use implicit types then reader have to look at the whole line till the very end to infer type instead of looking at the declaration.  
Remember, we write code not for compiler.

### forEach vs for

> If you need a for-loop then use forEach.  
We're doing functional programming, not imperative!

For collections, arrays, and basically, all objects which implement Iterable interface (or even Strings) it is possible to use `forEach` method instead of explicit `for` loop. In many cases, it has a decisive advantage. Compare:
```kotlin
for (i in 0 until list.size) {
    println(list[i])
}

list.forEach { println(it) }
```

Though at the same time it is possible to use:
```kotlin
for (item in list) {
    println(item)
}
```
Where the difference is not that significant.
But we write functional code, right? Functions should be our primary option?

I see no issues in using `for` loops instead of `forEach`.  
In some cases using `forEach` would be bad:
```kotlin
(1..10).forEach { ... }
```
will create additional object for `IntRange`, which we won't have if we use just `for` loop.

Another important thing is that lambda declares scope. And in such a case Kotlin compiler might not be able to infer types.
Let's look at the example of finding max value in an array:
```kotlin
var max: Int? = null
val array = intArrayOf(1, 2, 3, 4)

for (i in array) {
    if (max == null || i > max) {
        max = i
    }
}

array.forEach { i ->
    if (max == null || i > max) { // <- Smart cast to 'Int' is impossible, because 'max' is a local variable that is captured by a changing closure
        max = i
    }
}
```
Version with `for` works well because compiler was able to smart cast from `Int?` to `Int`. In case of `forEach` smart cast was impossible.

### it vs method reference

> If you can use method reference, then do.  
Remember, functional programming.

When we use function which accepts lambda as a parameter (inside which we call some function) it might look better to use method reference:
```kotlin
list.forEach { println(it) }

list.forEach(::println)
```

Second example is shorter and generally looks better.  
But there is nothing wrong with using lambda with it.

### with/apply

> If you can use with/apply, then do. You can group everything so that it might become a one-liner.  
Then you can remove curly braces and return type. Cool!

Using with/apply and other similar methods allow grouping code into logically coupled statements:
```kotlin
recyclerView.apply {
    adapter = ItemAdapter()
    layoutManager = LinearLayoutManager(context)
    addItemDecoration(DividerItemDecoration())
}
```

And while it is a good option, and I use it almost all the time, there is nothing wrong with:
```kotlin
recyclerView.adapter = ItemAdapter()
recyclerView.layoutManager = LinearLayoutManager(context)
recyclerView.addItemDecoration(DividerItemDecoration())
```

It seems bloated, but at the same time, it is shorter ;)

Usage of apply/with/etc. also might lead to some issues with declaring what is `this` in given scope, in case where we use some nesting:
```kotlin
object1.apply {
    object2.apply {
        value = 0
        this@object1.value = this.value
    }
}
```
If you use labeled `this` you should point yourself that code could look better without `apply`:
```kotlin
object2.value = 0
objet1.value = object2.value
```

### Conclusion

Code style is important. Code review is important.  
Discuss among the team what you expect to get from code review: find code style issues or bugs, architectural decisions, and so on.  
It is generally better to discuss code style topics in the team and set up some code style checking tool and do not spend a lot of time in review fixing nitpicks.  
Don't try to use in your review arguments like "this is not a kotlin idiomatic code", "can be shorter" and so.  
Your code should solve problems, your code should be in one style among team.  
Work in a team.

Happy coding.