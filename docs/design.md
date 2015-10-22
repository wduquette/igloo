# Igloo Design Notes

## Special Variables

Igloo relies on certain special class and instance variables.

### Class Variables

Igloo defines the following class variables.

`_iglooVars()`: An array of instance variable initialization specs, by
instance variable name.  Each spec is a list _aflag value_, where
_aflag_ is 1 if the variable is an array and 0 otherwise, and 
_value_ is the initialization value, which must be a valid dictionary
string when _aflag_ is 1.

### Instance Variables

Igloo defines the following instance variables.

`igloo()`: An array of Igloo-related data.  It has the following keys:

* `init`: A flag, 1 if the `_init` method has been called and 0 otherwise.

