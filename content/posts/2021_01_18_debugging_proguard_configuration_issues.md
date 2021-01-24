+++
title = "Debugging Proguard configuration issues"
date = "2021-01-18"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["android", "proguard"]
keywords = ["android", "proguard", "r8", "shrinker", "obfuscation", "oprimization"]
description = "Proguard configuration was never an easy task. Especially it strikes when some issue leaks to the production. In the article I try to provide simple algorithm on how to track down what exactly might be an issue in proguard configuration"
showFullContent = false
+++

![](https://images.unsplash.com/photo-1590249002987-c3d0e38db7a4?ixid=MXwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHw%3D&ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80)

![](https://img.shields.io/badge/androidweekly-450-blue#badge)](https://androidweekly.net/issues/issue-450)

# Introduction

It might happen so that there is a bug in your release build while in debug everything works fine. In many cases, it might be an issue with Proguard/R8 configuration. Of course, it is better to test your code thoroughly, properly configure Proguard if you, let's say, load some classes only via reflection and so on. But reality sometimes strikes and bugs might go to production.  
In this case, the first thing that is needed is to find a bug and fix it. And only then have some retrospective to mitigate such situations in the future.
When the bug is in production already every minute counts, therefore it is important to have some plan. Proguard configuration seems complex to someone who didn't work with it, so I recommend to take a look at its main features.  
Most of the time I'd say that issue is easy can be found and fixed by analyzing crash report logs. But sometimes the log is not that clear.  
In this article I'd like to introduce the plan to find what part of "Proguard" causing an issue, so you can debug more effectively.

# Proguard Basics

Just a quick overview of what we have with Proguard/R8 and what might cause issues in release builds.  
The basic setup for release build is:  

```groovy
buildTypes { 
    release { 
        minifyEnabled true 
        shrinkResources true 
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'  
    } 
}
```

Flag `minifyEnabled` controls whether obfuscation and code optimization is enabled when `shrinkResources` controls the optimization of resources (and can be set true only if minify enabled). Therefore there are at least three parts of "Proguard" that might cause issues when used incorrectly (or not correctly configured):
- code obfuscation - replacing names with shorter variants. Makes it more difficult to reverse engineer the app and makes bytecode smaller.
- code optimization - including but not limited to inlining code blocks, removing unused classes, methods, and so on
- resources optimization - removing unused resources, etc.

One of the most advanced ways of investigating issues in release builds is analyzing the content of the APK file. This can be done via `Build > Analyze APK ...`.
There one can see `classes.dex` containing all the bytecode, `resources.arsc` which contains the mapping between original resources IDs and obfuscated and all resources under `/res` folder.  
This method is advanced because for example bytecode will be shown to you as:

```java
.class public final Lcom/krossovochkin/proguardtest/MainActivity; 
.super La/b/c/e; 
.source "" 
 
 
# direct methods 
.method public constructor <init>()V 
    .registers 1 
 
    invoke-direct {p0}, La/b/c/e;-><init>()V 
 
    return-void 
.end method 
 
 
# virtual methods 
.method public onCreate(Landroid/os/Bundle;)V 
    .registers 2 
 
    invoke-super {p0, p1}, La/b/c/e;->onCreate(Landroid/os/Bundle;)V 
 
    const p1, 0x7f0b001c 
 
    invoke-virtual {p0, p1}, La/b/c/e;->setContentView(I)V 
 
    return-void 
.end method
```

Which while not being much readable still might provide you some hints.

To debug Proguard/R8 configuration one can assemble release build and navigate to `app\build\outputs\mapping\release`. There you'll see the following files:

- `configuration.txt` – merged file with all configurations – from your app, default Android, AAPT, all the libraries, etc. Here you can find what rules might cause an issue.
- `mapping.txt` – file with mappings of original names to obfuscated ones. This might help you analyzing logs and the content of the APK file.
- `seeds.txt` – file with kept files/classes/etc. You can verify here that some particular file not being removed by R8
- `usage.txt` – opposite to seeds – what was removed. Here you can see whether some class you need was removed

# Debugging algorithm

Here we'll see steps of the algorithm to define what part of release optimizations is responsible for the issue, and where you should look deeply to find the root cause.  

### Step 1 - Ensure issue related to release optimizations

First of all, we need to be sure that the issue we have is because of some misconfiguration of the release build. To confirm that we just need to disable release optimizations and check whether we still have a bug or it is disappeared.  

For this one need to disable minification and shrinker:
```groovy
minifyEnabled false
shrinkResources false
```

If the issue still reproduces then the issue is not with proguard. Look for some usages of `BuildConfig.DEBUG` in your codebase. Dive deep into logs.  
Additionally, you can make your release build debuggable by placing in your release config:
```groovy
debuggable true
```
Anyway, there is nothing to do with Proguard here. And that is partially good because you don't have to look at proguard configuration.

If after disabling release optimizations you see that issue doesn't reproduce anymore, then something is wrong with release optimization configurations. Go to the next step.

### Step 2 - Check whether it is a shrinker issue

Next, we'll check whether we have the issue because of shrinker configuration or not. To do that we need to enable minification while keeping the shrinker disabled:
```groovy
minifyEnabled true
shrinkResources false
```

If the issue disappeared then indeed we have some issue with configuring shrinker. Probably it removed something we've relied on. Look at the `resources.txt` file looking for the resources you access dynamically. Check whether these resources are added to `keep.xml`.

If the issue still happens then go to the next step.

### Step 3 - Check whether it is an obfuscation issue

To check whether it is an issue with obfuscation we need to disable it.  
Inside your `proguard-rules.pro` file add the line to direct Proguard to disable obfuscation:
```
-dontobfuscate
```

If the issue doesn't reproduce anymore then there is some issue because of obfuscation.  
Look for classes or methods you use via reflection and looking at `mapping.txt` check that classes you access via reflection are not obfuscated. If they are obfuscated, then you need to add some `keep` rules in the `proguard-rules.pro`.

If the issue doesn't reproduce, then it is most likely related to code optimizations. Probably you access some classes via reflection only and that class was removed during release optimizations. For that check `usage.txt` to ensure. If class or method indeed was removed, then again you probably need to add some `keep` rules to your proguard configuration.

# Examples

Let's look at the examples of various issues that might happen.

### App issue

Suppose we have in our project some code like:
```kotlin
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        if (!BuildConfig.DEBUG) {
            throw RuntimeException()
        }
    }
}
```
Running it in debug has no issue, while in release app crashes:
```
Caused by: java.lang.RuntimeException
        at com.krossovochkin.proguardtest.MainActivity.onCreate(:1)
```

Going with our algorithm:
- disable release optimizations - the issue still reproduces in the release build, therefore it doesn't relate to proguard configuration and we need to check our logs and debug the app itself.

We quickly see that we have incorrect logic for the release build, fix and we're done.

### Shrinker issue

It is a bit tricky. Shrinker is doing its best to not remove resources that even might be accessed dynamically. So if we have in our code something like:
```kotlin
private fun shrinker() {
	val id = resources.getIdentifier("test", "layout", packageName)
	setContentView(id)
}
```
or even:
```kotlin
// ...
shrinker('t')
// ...
private fun shrinker(char: Char) {
	val id = resources.getIdentifier("${char}est", "layout", packageName)
	setContentView(id)
}
```
Shrinker won't remove the `test.xml` layout resource.  

Usually, an issue might happen when we receive ids from outside of the APK (say from the server). For our test example we can do some weird calculation which won't be optimized:
```kotlin
shrinker(Class.forName("com.krossovochkin.proguardtest.MainActivity").simpleName[6])
```

If we launch the release build app will crash. In `resources.xml` we'll see the message:
```
Skipped unused resource res/layout/test.xml: 880 bytes (replaced with small dummy file of size 104 bytes)
```
And if we look inside the APK we'll see that our resource will look like:
```xml
<?xml version="1.0" encoding="utf-8"?>
<x />
```

So, going with our algorithm it will look like this:
- disable release optimizations - the issue still here
- enable minification while keeping shrinker enabled - no crash

Therefore we know that the issue is with shrinker removing unused resource. To fix that we need to add our resource to `/res/raw/keep.xml` like this:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
	tools:keep="@layout/test" />
```

We enable release optimizations, check once again and it works fine. Cool!

### Obfuscation issue

Obfuscation issues usually happen when we rely on some class/methods/etc names. For example:
```kotlin
private fun obfuscate() {
	if (TestClass::class.java.name != "com.krossovochkin.proguardtest.TestClass") {
		throw RuntimeException("obfuscate")
	}
}
```
When running the app in the release, it crashes.  
Going with our algorithm:
- disable release optimizations - app crashes
- enable minification while keeping shrinker disabled - app crashes
- disable obfuscation in `proguard-rules.pro` - no crash.

We check `mapping.txt` and see that our class was obfuscated (which we don't want to happen). So we need to make an exception in our proguard rules. For example, add to `proguard-rules.pro`:
```
-keepnames class com.krossovochkin.proguardtest.TestClass
```
And the issue is gone.

### Optimization issue

Optimization issues usually happen when we rely on some class via reflection only and it was removed during code optimization. For example, if we have in our app:
```kotlin
private fun optimizer() {
	Class.forName("com.krossovochkin.proguardtest.TestClass").newInstance()
}

class TestClass {

	var value: Int = 5
}
```
Then everything is fine. Because code optimization is smart and it doesn't remove as much as it could. It can determine that class is used by analyzing strings we have in our app. So, let's emulate the issue by hiding the exact class we need:
```kotlin
private fun optimizer(char: Char) {
	Class.forName("com.krossovochkin.proguardtest.${char}estClass").newInstance()
}
```
App crashes in release because there is no such a class in the release build.  
We even can see that by looking at logs:
```
Caused by: java.lang.ClassNotFoundException: com.krossovochkin.proguardtest.TestClass
```
But sometimes it might be not so obvious, so we can stick to our algorithm:
- disable release optimizations - app crashes
- enable minification keeping shrinker enabled - app crashes
- disable obfuscation - app crashes

Here we understand that issue is because of code optimizations. We look at `usage.txt` and see that our class was removed as a part of code optimization. So, we need to keep our class explicitly by adding to our `proguard-rules.pro`:
```
-keep class com.krossovochkin.proguardtest.TestClass
```

And the issue is fixed.

# Conclusion

Proguard configuration issues might be annoying and not easily spotted. Therefore it is good to be prepared and know what to do when you face the issue. The algorithm provided in the article not only allows you to concentrate quickly on the part of release optimizations that most likely cause the issue but also gives you a clearer inside on what release optimizations exist and how they can impact your release build.

Also, I recommend to look at [Proguard configuration options](https://www.guardsquare.com/en/products/proguard/manual/usage) to know what can be done and what various configurations mean. And take a look at [Android documentation](https://developer.android.com/studio/build/shrink-code) for release optimizations configuration.

Happy coding
