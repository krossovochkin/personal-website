+++
title = "Android Room Hidden Costs"
date = "2020-12-18"
author = "Vasya Drobushkov"
authorTwitter = "krossovochkin" #do not include @
cover = ""
tags = ["android", "sqlite"]
keywords = ["android", "room", "sqlite"]
description = ""
showFullContent = false
+++

[![](https://img.shields.io/badge/androidweekly-445-blue#badge)](https://androidweekly.net/issues/issue-445) [![](https://img.shields.io/badge/kotlinweekly-230-purple#badge)](https://mailchi.mp/kotlinweekly/kotlin-weekly-230)

### Introduction

Android Room is an awesome AndroidX library. It is great because it provides a clean way of how to deal with databases without introducing some heavy concepts. Out of the box with Room one gets:
- simplified code comparing with raw SQLite queries
- working via DAO interfaces and models instead of Cursors
- auto-generated "boilerplate" code for queries
- migration support
- Android Studio tooling (compile-time verification of queries and highlight)
- support for reactive streams (RxJava, Kotlin Flow)
- and more

In this article, I'd like to discover some hidden costs Room applies to support reactive streams and how one can try to avoid them.

### Problem

Imagine you create a TODO app. It has two simple screens: a list of TODO items and details of a single TODO item. And for simplicity let's say we have only id and title in our TODO item.
Our app works always offline. We create two simple screens - probably fragments. To get data on the screen we request a Database. Our DAO will be like:

```kotlin
@Dao
interface TodoDao {
    
    @Query("SELECT * FROM items")
    fun getItems(): List<TodoItem>
    
    @Query("SELECT * FROM items WHERE id=:id")
    fun getItem(id: Int): TodoItem
    
    @Insert
    fun addItem(item: TodoItem)
}
```

Pretty simple. Our app works well. We open the list, navigate from it to the details screen, and after modification, we re-query our list to show updated list UI. Everything is cool.  
But we see here an option to use reactive streams. Why re-query something manually if we can just subscribe to our Database on the list screen and if something changed immediately update our UI. So we modify our DAO to reflect this:

```kotlin
@Dao
interface TodoDao {
    
    @Query("SELECT * FROM items")
    fun getItems(): Observable<TodoItem>
    
    @Query("SELECT * FROM items WHERE id=:id")
    fun getItem(id: Int): TodoItem
    
    @Insert
    fun addItem(item: TodoItem)
}
```

Let's look at how it works under the hood.  
The core thing that supports reactiveness is `InvalidationTracker`. It works the following way:
- `InvalidationTracker` has its own internal table `room_table_modification_log`, where it keeps track of invalidated tables.
- when we subscribe to our Observable, SQLite trigger is created. That trigger keeps track of the changes to our table (`items`) and after each insert/update/delete it adds to `InvalidationTracker` table `1` for our `items` table
- after each transaction ended (and all the queries are done in the transaction in Room) `InvalidationTracker` queries its internal table and if there are changes spotted - it triggers a callback in the code, our reactive stream receives that callback and re-queries automatically.

That means that when we insert a new item in the Database the following happens:
- SQLite trigger writes 1 to `InvalidationTracker` internal table
- `InvalidationTracker` queries its internal table and triggers a callback
- our `getItems` query is executed
- new values are propagated via Observable

So far so good. For our case it works well, but what if we have something more complicated. For example, we have a location tracking app. We subscribe for location changes and write them to a Database, so we can draw the actual path on the map. To draw the path we observe location changes in our database. We might have many location changes to be inserted in the database for a small-time. Having an Observable here might become an issue as not only we'll have to re-query each time but also `InvalidationTracker` will query its internal table on each transaction end. It might affect performance.

### Re-query optimization

As we control writes to the database (only our app, and probably some particular class writes to the database) we can create some proxy controller, which will keep track of the latest changes being made and keep relevant information in memory. This allows us to have a Database as a backup for our in-memory solution. And instead of having Observable in DAO we instead might have it in the proxy controller:

```kotlin
class ProxyController(private val dao: LocationDao) {

    private val locations: MutableList<LocationData> = dao.getLocations().toMutableList()

    private val changesSubject = PublishSubject.create<Unit>()
    
    val locationsObservable: Observable<LocationData>
        get() = changesSubject.map { locations }
        
    fun addLocation(location: LocationData) {
        locations += location
        dao.addLocation(location)
        changesSubject.onNext(Unit)
    }
}
```

And our DAO will be:
```kotlin
@Dao
interface LocationDao {

    @Query("SELECT * FROM locations")
    fun getLocations(): List<LocationData>
    
    @Insert
    fun addLocation(location: LocationData)
}
```

This way we removed the necessity in re-querying the Database on each write improving performance. Also, we can remove the dependency on the Room RxJava artifact.

To verify that we can debug SQLite queries to our Database by:
```bash
adb shell setprop log.tag.SQLiteLog V
adb shell setprop log.tag.SQLiteStatements V
```

But even after doing that we still can see that `InvalidationTracker` queries its internal table:
```bash
V/SQLiteStatements: /data/user/0/com.krossovochkin.test/databases/locations.db: "BEGIN EXCLUSIVE;"
V/SQLiteStatements: /data/user/0/com.krossovochkin.test/databases/locations.db: "SELECT * FROM room_table_modification_log WHERE invalidated = 1;"
V/SQLiteStatements: /data/user/0/com.krossovochkin.test/databases/locations.db: "COMMIT;"
```

But we don't use reactive streams and don't use `InvalidationTracker`. That means that we are not interested in `InvalidationTracker` to query the internal table as well. How can we remove that overhead as well?

### Disable `InvalidationTracker`

In Room, there is no way to effectively disable `InvalidationTracker`. At least I don't know whether such a possibility exists. There seems no public API for this. Let's try to disable it on our own.

The code which queries the internal table is located in `mRefreshRunnable` which is triggered e.g. at the end of each transaction. `InvalidationTracker` is an abstract class and is created in the code generated for our Database by kapt.  
The solution would be to disable kapt, copy-paste generated code to our sources, and update creating `InvalidationTracker` stubbing refresh methods:

```java
@Override
@NonNull
protected InvalidationTracker createInvalidationTracker() {
    return new InvalidationTracker(this, "locations") {
        public void refreshVersionsAsync() {
        }
        public void refreshVersionsSync() {
        }
    };
}
```

By doing that we can verify in SqlLiteStatements that `InvalidationTracker` queries its internal table no more.

> **UPDATE**  
Thanks to [Yigit Boyar](https://twitter.com/yigitboyar) for pointing out that internal table Room uses is in-memory. Indeed, that table is temp. So, the most of the performance impact is related to SQLite triggers, not querying internal temp table. And triggers are not created unless you subscribe to some Observable declared.  
Though the last is still not free, as querying uses android Cursor, which allocates memory when populating its CursorWindow.

### Conclusion

Android Room is a great library, but it still might impact performance. And if your app is critical to performance one should be very careful. Still, it is possible to remove some overhead in the cases where you need that.  
And don't forget to profile your app, identify problems, and try to find a way to solve them.

Happy coding