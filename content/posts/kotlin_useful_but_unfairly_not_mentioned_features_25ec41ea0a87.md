+++
title = "Kotlin useful but unfairly not mentioned features"
date = "2020-05-03"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = []
keywords = []
description = "Exploring some good Kotlin features which are not so widely discussed"
showFullContent = false
+++

![[Source](https://unsplash.com/photos/5EoKAdyStik)](https://images.unsplash.com/photo-1519963759188-0e9264cd7992?ixlib=rb-1.2.1&auto=format&fit=crop&w=1357&q=80)*[Source](https://unsplash.com/photos/5EoKAdyStik)*

## Introduction

Many of us first learned Kotlin after Java. Learning process was fairly simple because Kotlin has many similarities when at the same time improves development experience by fighting common pain points Java developer (especially on Java 6, which is common in Android world) has to encounter every day.

There are a bunch of articles about cool Kotlin features like immutability, handling nullability, smart-cast, data classes, and so forth. Yes, these features are great. Having to add a bunch of nullability annotations, final keywords, override equals/hashCode methods, create additional local variables after type checks — all of this adds unnecessary work that needs to be done all the time.

But also there are some differences between Kotlin and Java, which are not that significant, though useful. In this article, we’ll go through a few of them.

## Mutability of method parameter’s references

### Java

In Java references of parameters of a method are mutable by default.
That means that one can “replace” object on a given reference. To make it immutable one needs to add final keyword. It is a good practice to not replace such references, because it adds complexity to the code. That means that one should consider to always add final keyword to all parameters, which is definitely not that satisfying.

<iframe src="https://medium.com/media/dd85a1c81b81e8681258fc1937ca7306" frameborder=0></iframe>

For example, as shown in a snippet, we get compilation error only if we add final keyword.

### Kotlin

Unlike Java, in Kotlin all the params are by default immutable. And there is no way to make them mutable. This follows general Kotlin idiom of restricting all the access unless explicitly declared (so instead of putting final one usually add open where needed). In this particular case, there is no way to make this parameter neither var nor open. And anyway there is no need for that.

<iframe src="https://medium.com/media/92c53cc085df1c9f86ab78b73eaa8930" frameborder=0></iframe>

## Package private vs protected

Kotlin and Java have different approaches to visibility access. Though they are well documented, there is at least one interesting case, which is worth mentioning. And it is about protected keyword.

### Java

In Java there are four visibility modifiers: public, protected, package-private (default value, has no separate keyword), private.

The rules are straightforward:

* *private *is accessible from within a class

* *package-private* is accessible as private (withing a class) plus within a package

* *protected *is accessible as package-private plus for all child classes

* *public *is accessible from everywhere

Important thing here is to note that protected is accessible from the same package, not only by child classes.

So, if we, for example, we have a class with two methods: one protected and another package-private:

<iframe src="https://medium.com/media/8712b2bb67ab904caa658e0d9cc5b28b" frameborder=0></iframe>

And we had class A in the same package, then that class A will be able to access both methods from class B:

<iframe src="https://medium.com/media/5fcb5d1b1fb3d8d8b870649063e7e0e1" frameborder=0></iframe>

### Kotlin

In Kotlin there are different visibility modifiers: public (default, can be omitted), protected, internal, private.

* *public *is accessible from everywhere

* *protected *is accessible from child classes only

* *internal *is accessible from all the module (not only package, this is effectively “public in a module”)

* *private *is accessible from within a file/class

So, if we had a class similar to the previous example:

<iframe src="https://medium.com/media/58b24b15de561cef063810bb7cc46b87" frameborder=0></iframe>

Then class A, while being in the same package, would not be able to access protected method:

<iframe src="https://medium.com/media/70fb552768b9b2c0b3c94db2cd948ae4" frameborder=0></iframe>

And I personally found that really useful. Package-private thing is clunky and feels somewhat outdated. Having protected to be accessible from the same package feels like encapsulation hole. Glad that Kotlin has a more strict approach for protected keyword.

But what if we would like to have something similar to package-private in Kotlin? In this case, we can consider putting two classes into same file with marking classes we’d like to hide as private. All the methods can remain public as class won’t be accessible from outside anyway:

<iframe src="https://medium.com/media/4c98ee906877f9642c539d2a6d5cec9b" frameborder=0></iframe>

One can read more on visibility modifiers in Kotlin [here](https://kotlinlang.org/docs/reference/visibility-modifiers.html).

## Final words

And that’s it for now. Hope this was interesting and useful. Kotlin is a great language and has a lot of cool features. But we can also look around and find also something else, not that impressive at first. Maybe there are some other features in Kotlin which are not highlighted that often in articles? Some features which save you time, make solutions clearer? Feel free to add your favorite features in comments.

Happy coding!

*Thanks for reading!
If you enjoyed this article you can like it by **clicking on the👏 button** (up to 50 times!), also you can **share **this article to help others.*

*Have you any feedback, feel free to reach me on [twitter](https://twitter.com/krossovochkin), [facebook](https://www.facebook.com/vasya.drobushkov)*
[**Vasya Drobushkov**
*The latest Tweets from Vasya Drobushkov (@krossovochkin). Android developer You want to see a miracle, son? Be the…*twitter.com](https://twitter.com/krossovochkin)
