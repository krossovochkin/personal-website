+++
title = "Java after Kotlin"
date = "2025-02-04"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["kotlin", "java"]
keywords = ["kotlin", "java"]
description = ""
showFullContent = false
+++

I am usually pretty slow with new technologies and software updates. That happened with Kotlin a while ago. While version 1.0 was released in early 2016, and many companies were early adopters since the alpha versions, I really started using it only around the end of 2017.

I should say that I do find it a very concise and easy-to-write-and-read language. Its focus on developer experience makes it very pleasant to use (except coroutines, lol).

Right now, this is the primary language that I use. Here and there, I might touch something else like Python, Go, JavaScript, etc.

A few days ago, I needed to write some code in Java, and I immediately noticed a number of things that Kotlin does better, in my opinion.

## Semicolon  
I remember how I used to defend this in Java back in the day. Like, how can you be sure there are no issues with how the code is run when it doesn't fit on one line without a semicolon?  
Over time, I had no issues with that, and being required to type one on each line is truly annoying. Especially when you don't have that habit anymore and forget to type it here and there.

## Equality  
`==` instead of `equals` is truly a game-changer. Between instance and content equality, 99% of the time we want to compare content, so having a shortcut exactly for that is absolutely logical.  
The comparison in Java hit me hard when I used `==` on Strings. These are not primitive types, and while in certain cases this would work as expected, if the instances are different, one can get into a very tricky-to-find bug.

## Naming  
Some of the classes in Kotlin have a shorter name: `Int` vs `Integer`, `Char` vs `Character`.  
Again, feels like not a very big deal, but it adds some points to Kotlin for conciseness.

## Get data  
This one is my favorite—whenever you want to get something, you just use `[]`. Simple as that.  
In Java, you would use `[]` on arrays, `.get()` on collections, and `.charAt()` on Strings. Having different ways of doing practically the same thing increases cognitive load. Instead of thinking about what you want to do, you have to keep in mind what you are working with.  

There is a downside in Kotlin, though: if you get something outside the bounds from a collection, you will get `null`, but from an array, you'll get an exception. So, you still have to think at least about that.

## Switching discomfort  
There are also things that are mostly whatever but make it difficult to switch between languages. Like in Java, you first declare a type and then the name, while in Kotlin, it is the opposite. I'm okay with both approaches, but it brings some discomfort.

## Java improvements  
There are also things that Java now does pretty well. Like the ability to use `var`—a very nice addition.

## Final thoughts  
Overall, I haven't felt doomed for having to write something in Java. It is still a great language with tons of new features that make it better every year. It has some legacy that is difficult to change.  
But Kotlin, feeling more modern and developer-friendly, is a great language to use on a daily basis.

**Happy coding!**
