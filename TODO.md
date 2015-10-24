# Igloo To-Do List

* Ensure that igloo::define is only used with igloo::classes
  * On igloo::class create, add _igloo() to class
  * On igloo::define, verify that _igloo() is there.
* Begin to document the API.
* Option handling
* Components and "install"
* Method delegation
* Option delegation
* Handle unqualified class names properly
  * E.g., replace unqualified class names with fully-qualified class 
    names internally.
* Better error checking
  * To help the programmer find class definition errors
* Better parameter error messages
