+++
title = "Bad Kotlin Extensions"
date = "2021-01-25"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["kotlin"]
keywords = ["kotlin", "extension"]
description = "Kotlin extensions is a cool feature. Though trying to write 'idiomatic' Kotlin code some developers tend to overuse that feature making code worse that it could be without extensions. In this article we'll go through some examples of how not to write Kotlin extensions"
showFullContent = false
+++

![](https://images.unsplash.com/photo-1598518619776-eae3f8a34eac?ixid=MXwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHw%3D&ixlib=rb-1.2.1&auto=format&fit=crop&w=1351&q=80)

[![](https://img.shields.io/badge/androidweekly-451-blue#badge)](https://androidweekly.net/issues/issue-451) [![](https://img.shields.io/badge/kotlinweekly-236-purple#badge)](https://mailchi.mp/kotlinweekly/kotlin-weekly-236) [![](https://img.shields.io/badge/oncreate-41-ff69b4#badge)](https://www.oncreatedigest.com/issues/oncreate-digest-issue-41-309824)

### Introduction

Kotlin extensions are a cool feature. Though trying to write 'idiomatic' Kotlin code some developers tend to overuse that feature making code worse than it could be without extensions. In this article, we'll go through some examples of how not to write Kotlin extensions.

First of all, we need to try to define what a good extension is.  
It is simple though vague: good extension solves some problems. When we talk about code the main feature extensions have is to improve readability. Extension methods are static methods with the first parameter being a receiver of the extension. For example, these are equivalents:
```kotlin
CollectionUtils.first(collection)

collection.first()
```

The second looks better because we don't overwhelm our code with details about `CollectionUtils`. It feels better because we extend the functionality of some classes without changing their internals, and we don't need to look for some Utils class to find the corresponding method - so IDE can help us with auto-complete to find the required method.

It is important to understand that the new API that you write with extensions apply additional cognitive load to the reader of your code, as everyone now needs to know that project-specific API.

So, what extensions can be considered bad? Let's find out.

> As a side note, in this article we'll go over public extensions that one might have in the project. I find almost no issues with any kind of extensions if they are private, as it is much easier to look at what they do exactly.

### Too smart

In the first group of bad extensions, we put too smart extensions. These are typically relied on the operator overloading trying to make code as short as possible. It is too smart because making code too short might instead make readability worse.  
A classic example is an extension for a factorial.

Say, we have a factorial method:
```kotlin
fun factorial(num: Int): Long {
    var result = 1L
    for (i in 2..num) result *= i
    return result
}
```
This is just an [example](https://stackoverflow.com/a/45194538/1533933) (don't use in production, as it might not suit best for your needs - for example, if you need to call this method many times).  

To calculate factorial we'll call it like:
```kotlin
factorial(5)
```

"Meh, too verbose, let's create an extension to make it shorter":
```kotlin
operator fun Int.not(): Int {
    return factorial(this)
}
```
This is our smart extension, and now we can call the method like this:
```kotlin
!5
```

See, it is like `5!` which is a mathematical expression for factorial. Yes, we have an exclamation mark at the beginning, as we can't put it to the end, but still, it is shorter!

The reality is that it is very difficult to understand for someone who doesn't know that trick what the method is doing.  
From the perspective of such a person that expression looks like a negation of the `Int`. What it should do? Maybe it is a bitwise negation? Or maybe it converts the number to 1 or 0? Or something else. One can't say without looking at the source of the method. And here is the issue.

> If to understand what method does one has to look at sources, then readability is not good.

Another example of a smart expression is building file paths. Instead of:
```kotlin
File(folder, file)
```
What if we do:
```kotlin
operator File.div(fileName: String): File = File(this, fileName)
```
And use it like:
```kotlin
val file = File("src") / "main" / "java" / "com"
```
Cool, it is almost like writing path directly!

But is it better? Is the code shorter? Has less overhead?  
Or it is just some smart trick? I think the last, therefore such extension is not that good.

### Doing more than name says

While trying to make your code shorter one can try to move as much as possible to separate method and hide it inside the extension.  
For example, to replace fragment we might need to write:
```kotlin
supportFragmentManager
    .beginTransaction()
	.replace(R.id.container, fragment)
	.addToBackStack(null)
	.commit()
```
Why not create an extension:
```kotlin
fun FragmentManager.replaceFragment(@IdRes id: Int, fragment: Fragment) {
    this.beginTransaction()
	    .replace(R.id.container, fragment)
		.addToBackStack(null)
		.commit()
}
```
And then just write:
```kotlin
supportFragmentManager.replaceFragment(R.id.container, fragment)
```
We reduced the boilerplate and everything is cooler now!  
But not really. The issue with such an extension is that it does more than it says.  
It is not only replacing a fragment but also adds to the back stack. And someone who is not aware of that feature (didn't look at sources) might misuse that method if adding to the back stack wasn't something that actually should've been done.  
We can try to fix that with additional params like:
```kotlin
fun FragmentManager.replaceFragment(
    @IdRes id: Int,
	fragment: Fragment,
	shouldAddToBackStack: Boolean = true
) { ... }
```
It is a bit better as now at least the method signature says what it does under the hood.

### Too specific

With the previous example, there is still an issue - the method is too specific. It is intended to be used only to replace fragments. What if we need to add fragments as well? We'll have to create some extension like:
```kotlin
fun FragmentManager.addFragment(
    @IdRes id: Int,
	fragment: Fragment,
	shouldAddToBackStack: Boolean = true
) { ... }
```
With almost the same internals as replace method. Did we improve readability or created some separate API that has to be extended all the time when we need more features in dealing with fragments? Say, we need to `commitAllowingStateLoss` - will we add another flag to all the API methods?  
That is why this extension doesn't look good.

So, we shouldn't write an extension to work with `FragmentManager`? But it is too verbose!  
Let's look at some better extension by first looking at the issue. Probably the most "boilerplate" part of the code is the necessity to write `beginTransaction` and then `commit` in the end. What if we try to simplify that exact small problem by writing:
```kotlin
inline fun FragmentManager.inTransaction(
	allowStateLoss: Boolean = false,
    block: (FragmentManager) -> Unit
) {
    val transaction = this.beginTransaction()
	transaction.setReorderingAllowed(true)
	block(transaction)
	if (allowStateLoss) {
		transaction.commitAllowingStateLoss()
	} else {
		transaction.commit()
	}
}
```
And use it like:
```kotlin
supportFragmentManager.inTransaction {
    replace(R.id.container, fragment)
	addToBackStack(null)
}
```
The code becomes shorter and we still have all the flexibility we might ever need.  

But the extension is doing more than it says, one can say. As it calls `setReorderingAllowed`.  
True, but this is a method one should always call, and by using our `inTransaction` method we won't forget that and won't have that verbose solution.

### Saving few characters

Let's imagine that we have a `ViewModelFactory` which creates `ViewModel` based on the requested class.  
```kotlin
return when(clazz) {
    SomeViewModel::class.java -> createSomeViewModel()
	else -> throw NotImplementedError()
}
```
It is so ugly to write `::class.java`, why not write extension with reified type to make the code shorter:
```kotlin
inline fun <reified T> resolveClass(): Class<T> {
    return T::class.java
}
```
**NOTE**: strictly speaking it is not an extension, but I hope you got the idea.

So, we'll have:
```kotlin
return when(clazz) {
    resolveClass<SomeViewModel> -> createSomeViewModel()
	else -> throw NotImplementedError()
}
```
Cool, we now don't have any ugly colons!  
But did we make the code better?  
With our extension, we've just saved few characters and made more work for the compiler to inline our pretty extension.  
And we again introduced some API everyone should know about.  

The extension is cool and might look like an idiomatic Kotlin code, but it doesn't improve a codebase. Therefore such an extension is not good.

### Extension on common classes

It might be tedious to write a smart extension on the common class such as `String`, `Int`, etc.  
For example, we have a string containing the formatted date and we want to convert it to a `Date` instance.  
Let's do something like:
```kotlin
fun String.parseDate(): Date {
    return SimpleDateFormat(pattern).parse(this)
}
```
We now can do:
```kotlin
"2021/01/01".parseDate()
```
The issue with such a code is that it doesn't show you what exactly is done under the hood. But it is not the biggest problem.  
By writing some project-specific extensions for common classes you "pollute" the namespace for that type.  
So, whenever you try to use auto-complete for a `String` you'll see all the useless extensions one created in the project.  
The solution is simple - avoid writing some extension methods on common classes if they are not related to the class itself.

For example, the following extension is totally fine:
```kotlin
fun String.reversed(): String {...}
```
As it works with the class itself.  

### Conclusion

As with many other topics, while writing extensions there is no silver bullet. Some extensions while being questionable, might be good in some particular situation. What is important is to think, when writing an extension, what problem you're trying to solve and what alternatives you have. How bad you can evaluate code without extension and how much value extension might bring to you and your team if written.

Happy coding.
