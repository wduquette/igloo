#-------------------------------------------------------------------------
# TITLE: 
#    igloo.tcl
#
# PROJECT:
#    igloo: TclOO Helper Library
#
# DESCRIPTION:
#    igloo(n): Implementation File
#
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
# oo::object modifications

# FIRST, Define _init on oo::object so that we can always chain to it.
#
# TBD: Consider putting this on an igloo::object baseclass, and making
# every igloo::class inherit igloo::object.

oo::define oo::object method _init {} {
    my variable _igloo
    set _igloo(init) 1
}

#-------------------------------------------------------------------------
# igloo::define

# FIRST, define the namespace ensemble for the igloo::define command.
#
# TBD: Another way to do this:
#
# * Put all definers in the igloo::define:: namespace.
# * The definers implicitly act on $igloo::define::thisClass
# * ::igloo::define works by setting igloo::define::thisClass,
#   and evaluating the script or single command in that namespace.

namespace eval ::igloo {
    # TBD: If the method name is unknown, treat it as a defScript!
    namespace ensemble create \
        -command ::igloo::define \
        -parameters class        \
        -unknown ::igloo::Define.Unknown \
        -map {
            constructor ::igloo::Define.Constructor
            method      ::igloo::Define.Method
            variable    ::igloo::Define.Variable
        }

    # TBD
}

# NEXT, define the helper commands.

proc ::igloo::Define.Constructor {class arglist body} {
    oo::define $class constructor $arglist $body
}

proc ::igloo::Define.Method {class name arglist body} {
    oo::define $class method $name $arglist $body
}

proc ::igloo::Define.Variable {class name {value ""}} {
    oo::define $class variable $name
}

proc ::igloo::Define.Unknown {ensemble class {defScript ""}} {
    if {$defScript eq ""} {
        puts "No defScript"
        return
    }

    return [list ::igloo::Define.DefScript $defScript]
}

proc ::igloo::Define.DefScript {defScript class} {
    puts "Pretending to process defScript $class <$defScript>"

}

#-------------------------------------------------------------------------
# igloo::class

# FIRST, define the igloo::class metaclass.  For now, it's a fake
# metaclass; we'll grow it later.

oo::object create igloo::class {
    method create {class {defscript ""}} {
        oo::class create $class
        igloo::define $class $defscript
    }
}

#-------------------------------------------------------------------------
# FIRST, Call the _init method on construction


# Save the oo::define::constructor commmand so we call it later.
if {[info commands oo::define::_constructor] eq ""} {
    rename oo::define::constructor oo::define::_constructor
}

# Define the new constructor command to call _init as its first step;
# because everything done by _init should be done before any construction
# is done.
proc oo::define::constructor {arglist body} {
    set prefix {
        my variable _igloo
        if {![info exists _igloo(init)]} {
            my _init
        }
    }
    tailcall _constructor $arglist "$prefix\n$body"
}


#-------------------------------------------------------------------------
# NEXT, define the "var" define command.  It declares the variable, and
# arranges for it to be given an initial value *on construction only!*

# oo::define::var name ?-array? ?value?
#
# name    - The variable name
# value   - The initial value
#
# Defines an instance variable with an initial value.
#
# TBD: better argument checking

proc ::oo::define::var {name args} {
    # FIRST, get the value and whether it's an array initializer
    # or not.
    if {[lindex $args 0] eq "-array"} {
        set value [lindex $args 1]
        set aflag 1
    } else {
        set value [lindex $args 0]
        set aflag 0
    }

    # NEXT, get the class name and namespace.
    set cls [namespace which [lindex [info level -1] 1]]
    set ns [info object namespace $cls]

    # NEXT, save the initialization data.
    set ${ns}::_iglooVars($name) [list $aflag $value]

    # NEXT, define the _init method, if it hasn't already been defined.
    ::igloo::InstallInit $cls $ns

    # NEXT, declare the variable so it's available.
    tailcall variable $name
}


#-------------------------------------------------------------------------
# Helpers

# InstallInit cls ns
#
# cls    - A class name
# ns     - The class's namespace
#
# Installs the _init command in the class if it hasn't already
# been defined.

proc ::igloo::InstallInit {cls ns} {
    # FIRST, don't redefine the method if it's already defined.
    if {"_init" ni [info class methods $cls -private]} {
        # NEXT, define the method.
        oo::define $cls method _init {} [format {
            # FIRST, chain to parent first, because we want to do this
            # initialization from the top of the inheritance hierarchy on
            # down.
            next

            # NEXT, initialize each variable.
            foreach {var spec} [array get %s::_iglooVars] {
                lassign $spec aflag value

                if {$aflag} {
                    array set $var $value
                } else {
                    set $var $value
                }
            }

        } $ns]
    }

    # NEXT, define the constructor if it isn't already defined.
    # This uses the igloo version, which calls _init.
    if {[llength [info class constructor $cls]] == 0} {
        oo::define $cls constructor {} {}
    }

}
