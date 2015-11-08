# Igloo To-Do List

* Option handling
  * Error handling
  * Full Snit behavior (except option database)
    * Including default constructor that handles creation arguments.
  * "from" helper
* Begin to document the API.
* Components and "install"
* Method delegation
* Option delegation
* Better error checking
  * To help the programmer find class definition errors
* Better parameter error messages

## Notes

* We don't ever try to fix up objects if superclasses change after they
  are created.  That's the programmer's problem.
  * A few things (methods, etc) are handled automatically by TclOO.
    Other things are not.
* Options
  * A class and its superclasses all see the full options() array.
  * Each class knows its own option metadata.
  * The configure method handles the options it knows about, and passes
    the remainder to its superclass.
    * This includes option delegation.
  * The igloo::object's configure method will throw an unknown option 
    error if it is reached.
* Variables
  * Redeclaration checking would be nice, but is tricky.
  * In general, variables are visible in their own classes in the chain.
* Components
  * Are variables.
  * Setting a component using igloo::helper::install sets up the forwarding
    for its delegated methods.
  * I.e., always use "install" to set up forwarding.


## Questions

### igloo::define $class variable ...

Current, this declares the variable, making it visible in method bodies
for class $class, but not super or subclasses, and initializes it.

#### Redeclaration in Subclasses

At present, if a subclass redeclares the variable it is made visible in 
the subclass code as well, and given a new initialization value.  If the
`variable` declaration gives no initialization value, it is given the 
initialization value of "".

In this case, what is the correct behavior?

Q: If no new initialization value is given, should we simply make the
variable visible, retaining the superclass's initial value?
A: Probably.

Q: Should we throw an error, requiring the programmer to explicitly 
state that they want to redeclare a superclass variable?
A: Probably.

**Suggested Behavior:** If a subclass redeclares a superclass variable,
we throw an error unless the `-override` option is given.  We retain the
superclass's initial value if no new initial value is given.  Thus, 
suppose a superclass defines the variable `myvar`:

```
# In superclass
variable myvar 5

# In Subclass
variable myvar               ;# Error!
variable myvar 7             ;# Error!
variable myvar -override     ;# OK, retains initial value "5".
variable myvar -override 7   ;# OK, assigns new initial value "7".
```

Naturally, `-override` can coexist with `-array`.

#### Effect on existing objects

With `oo::define`, declaring a variable on a class will make that variable
visible in methods of existing instances of the class (TODO: Check this).

`igloo::define` will do the same thing, and will save the initial value
for new instances; the variable will not be initialized in existing
instances.

Q: Should `igloo::define` initialize the variable in existing instances of
the class, or should initialization **ONLY** take place as part of construction,
as now?

A: I'm leaning toward the latter, only as part of construction.  Other 
drastic dynamic changes, such as changing a superclass, do not call the
constructor, so no new variables will be initialized.  It's a strange 
thing to do, and the programmer has to be firmly in control.  