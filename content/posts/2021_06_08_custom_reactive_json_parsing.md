+++
title = "Custom Reactive JSON parsing"
date = "2021-06-08"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["kotlin", "json"]
keywords = ["kotlin", "json"]
description = "Sometimes there are situations when simple parsing JSON-string into objects doesn't work well. Here is a story not about writing custom type adapter for a JSON-parsing library, but a story about some particular tricky use-case for JSON-parsing that I had and how I've managed to solve it."
showFullContent = false
+++

[![](https://img.shields.io/badge/kotlinweekly-254-purple#badge)](https://mailchi.mp/kotlinweekly/kotlin-weekly-254)

### Introduction

Parsing JSON strings is a must-have on most Android projects that have server-client communication (of course there are some other formats like XML or [Protobuf](https://developers.google.com/protocol-buffers), but I guess JSON is the most common one at least at the moment). Setting up this communication is relatively straightforward: choose a library, add it to a project, describe models, create mappers, and so on. There are a bunch of various libraries to parse JSON: good old [Gson](https://github.com/google/gson), [Jackson](https://github.com/FasterXML/jackson), or more modern [Moshi](https://github.com/square/moshi), [kotlinx-serialization](https://github.com/Kotlin/kotlinx.serialization) and there are more. Set up of these libraries is different, there are differences in the internal implementation, but the general idea is the same for most of them: you can convert JSON-string into a set of objects and vice versa.

I have a few pet projects where I test various things to be up-to-date with current approaches, have my own opinion on solutions, and better understand pros and cons. One of such pet-projects is a [KWeather](https://github.com/krossovochkin/KWeather) - weather app. It is a minimalistic app (with terrible design) that has many things that usually are in many apps: list, details screen, image loading, basic navigation, server-client communication, DB.  
The stack is: multiplatform, jetpack compose UI, sqldelight, ktor, kotlinx-serialization. Many of the libs were added because of multiplatforminess.  
As a source of data I use [OpenWeatherMap](https://openweathermap.org/api). It has a good API and it is free - that is cool for a pet project.  
To make the app minimally useful I decided not to hard-code city during compile-time, but instead allow end-user to select a city from the list. To get the weather for a given city one should add `cityId` to the API call. Unfortunately, I didn't find a separate API call to get the list of cities to get the `cityId`. Instead, I found [zip-archive](http://bulk.openweathermap.org/sample/) with a JSON file containing all the cities supported by the OpenWeatherMap. Therefore I decided to bundle that JSON file as an asset inside APK so that all the city selection could be done completely offline.  

> Of course, the ideal way to implement this functionality would be to either have a server endpoint with pagination that would return a list of supported cities. That would solve issues with updating bundled zip-archive. Another way would be to use OpenWeatherMap API that accepts raw text city name as query param - in this case, the user would just type something into a TextField and voila.  
Having a solution based on a bundled JSON and backed by a Database leads to multiple hacks and workarounds, so I would not do anything like that in production as it is far less efficient than setting up an endpoint. But at least it is challenging and fun!

It is very inefficient to keep the whole JSON in memory (to filter/query it). It has just about 200k of entries that don't sound too much (but we'll see later that it might be too much). Would be better to query the Database instead as it would be faster and more efficient. So the simplest idea is to use a pre-populated database. But it didn't work out.  
I used sqldelight and unfortunately it [doesn't support pre-populating database](https://stackoverflow.com/a/57363143/1533933) at the moment (unlike [Room](https://medium.com/androiddevelopers/packing-the-room-pre-populate-your-database-with-this-one-method-333ae190e680#:~:text=Starting%20with%20Room%202.2%20(currently,of%20your%20pre-packaged%20database))). The best option is to copy-paste externally pre-populated database from assets to internal folder. This is possible to do, though doesn't work out of the box and requires some additional tweaks. So, I decided to go another way. 

What I decided to do is to introduce setup on the first app launch. We'll parse JSON from assets and populate the database manually showing the user fancy circular progress bar. Yes, the user experience is terrible in such a case (just like the design!), but it is just a one-time setup.
The first implementation was pretty straightforward: just read the JSON file from assets, parse it and then write each city into the database. 

```kotlin
override suspend fun setup() {
	if (outputCityListDatasource.getCityList("", 1).isNotEmpty()) {
		return
	}

	val cityList = inputCityListDatasource.getCityList("")
	outputCityListDatasource.setCityList(cityList)
}
```

First, we check whether our database (`outputCityListDatasource`) is initialized already, and if not - read data from the JSON file (`inputCityListDatasource`) and write it into the database.  
It worked like a charm.  

Or did it?

### The issue

After some time I got an [issue report](https://github.com/krossovochkin/KWeather/issues/1) that the app fails on that setup step with OutOfMemoryError! Turned out that on some devices with such an approach there is not enough memory to make it work! Shame on me.  
The JSON file is about 30MB. Reading the whole file into memory as a String, parsing it into a list of objects (keeping them in memory) is at least twice as much. This is of course unacceptable and should be improved.

### Stream parsing

The first idea on how to improve the situation was to take advantage of parsing JSON from `InputStream` instead of a string. Yes, JSON allows you to parse on the fly, so there is no need to load JSON file into memory as a string to parse it. You can take bytes from a stream and parse JSON continuously so that only a list of objects would be kept in memory.  
Here I was hit by the fact that the kotlinx-serialization library [doesn't support parsing from stream](https://github.com/Kotlin/kotlinx.serialization/issues/204). This is because in a multiplatform world streams API is still under development. Keep in mind that if you decide to take that lib into your project and you have big JSONs that you need to parse.  
I was a bit upset, but then I realized that even keeping a list of objects in memory is still not a very good solution.

### Reactive parsing

Let's step back and think about requirements. We'd like to transfer data from a JSON file into a database. That means that actually, we don't care about the intermediate representation of objects during that process. We don't need a list of objects - we won't work with it. What we need is to take an item from JSON and write it into the database, then take the second item and write it into the database and do that for each item till the JSON end.  
In a pseudocode it could look like:
```kotlin
val parser = JsonParser(file.inputStream())
while (parser.hasNext()) {
    database.insert(parser.next())
}
```

Again, unfortunately, it is difficult to have something like this with kotlinx-serialization because all the parsers are implementation details - all classes are internal and are not accessible for direct usage or for extending. Luckily for me, I had my own kotlin (JVM) JSON parser implementation: [json.kt](https://github.com/krossovochkin/json.kt). So, I decided to take sources, modify them a bit and use them in the project.  
The idea was to create a separate implementation of a parsing JsonArray method to, instead of adding values into a list, being able to take them on demand.  

I went one step further and made the parsing code reactive using kotlin `Flow` API. The parser would parse JSON and instead of adding it to a list, it would emit items to stream instead. In this case, we also handle cancellation during parsing, handle back-pressure by suspending parsing if writing into the database doesn't catch up with parsing.

```diff
-val array = JsonArray()

var nextToken = this.next()
while (nextToken.type != JsonToken.Type.END_ARRAY) {
	if (array.children.isNotEmpty()) {
		nextToken.checkType(JsonToken.Type.COMMA)
		nextToken = this.next()
	}

-	array.add(this.parseJsonElement(startToken = nextToken))
+   emit(this.parseJsonElement(startToken = nextToken))

	nextToken = this.next()
}

-return array
```

And the code that transfers data from JSON file into database becomes:

```kotlin
if (cityListInitializer.isInitialized) {
	return
}

cityListProvider.observe()
	.onStart { cityListInitializer.startSetup() }
	.onEach { cityDto -> cityListInitializer.insertCity(cityDto) }
	.onCompletion { cause: Throwable? ->
		if (cause != null) {
			cityListInitializer.rollbackSetup()
		} else {
			cityListInitializer.endSetup()
		}
	}
	.collect()
```

This solves the issue with memory, but we face another issue: time. Setup becomes much longer. It is a usual trade-off in programming: you can write a solution that either consumes more memory or more CPU. Crashing the app because of OOM is anyway worse than making the user wait longer, so I'm happy with the result.  

But why it takes a long time and how it is possible to further improve the situation? Partially that is because my implementation of JSON parser is not that performant. So by optimizing the JSON parser it is possible to make the setup work faster. Also, we can save some time by reducing object creation. Still, we create an intermediate `cityDto` object - we can get a bit more low-level if we just parse required fields and pass them right away (though it makes code less maintainable). Also, we can skip parsing fields in JSON that we don't care about - it would save us some time as well. Maybe will do that somewhere later.

### Conclusion

There might be situations where taking the default behavior of libraries is not what you need. Look at your use case and choose the appropriate solution. Keep in mind memory/CPU trade-offs to help you find the best you can do. And always profile your app to find issues.

Happy coding.
