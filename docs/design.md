# Igloo Design Notes

## General Notes

Igloo can be independent of the normal TclOO system yet interoperate with
it.

* Define `igloo::object` class that defines `_iglooInit`.  Then we have no 
  need to modify `oo::object`.
* Define `igloo::define` that works like `oo::define` but with igloo's
  specific commands.
  * constructor that calls `_iglooInit`
  * variable with my desired behavior
  * delegate
  * etc.
* `_iglooInit` does the following:
  * Initializes a new object's variables, etc.
  * Imports the helpers, like "install", as aliases into the class's
    namespace.
* Define `igloo::class` that uses `igloo::define`.  It could be a metaclass,
  but need not be.

Can a non-Igloo class subclass an Igloo class?  Answer: yes, if it calls 
the Igloo class's constructor, which it should.

Hmmm.  Can I subclass a non-Igloo class?  Answer: only if igloo::object is
its ancestor, so that I have a terminal `_init`.  I could check, and 
make the new Igloo class have a terminal `_init`, but superclasses are
dynamic.  I think adding `_iglooInit` as a method to `oo::object` probably
makes sense.  But I can avoid making any modifications to the `oo::define` 
and `oo::helper` syntax, and that's a good thing.





## Special Variables

Igloo relies on certain special class and instance variables.

### Class Variables

Igloo defines the following class variables.

`_iglooComponents`: A list of component names.  Later this might be an
array of component specs by name.  For now it's used for error checking 
on the `delegate` statement.

`_iglooMethods()`: An array of method delegation specs by method name.  
Each spec is a pair, _compName using_, where _compName_ is the 
component's name and _using_ is a delegation "using" string which will 
be string mapped by the `unknown` handler.

`_iglooVars()`: An array of instance variable initialization specs, by
instance variable name.  Each spec is a list _aflag value_, where
_aflag_ is 1 if the variable is an array and 0 otherwise, and 
_value_ is the initialization value, which must be a valid dictionary
string when _aflag_ is 1.  *NOTE:* could be a dict in `_igloo`.

### Instance Variables

Igloo defines the following instance variables.

`igloo()`: An array of Igloo-related data.  It has the following keys:

* `init`: A flag, 1 if the `_init` method has been called and 0 otherwise.

