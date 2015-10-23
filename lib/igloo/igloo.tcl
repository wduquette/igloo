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

namespace eval ::igloo {}


#-------------------------------------------------------------------------
# oo::object modifications

# FIRST, Define _staticInit on oo::object so that we can always chain to it.
#
# TBD: Consider putting this on an igloo::object baseclass, and making
# every igloo::class inherit igloo::object.

oo::define oo::object method _staticInit {} {
    my variable _igloo
    set _igloo(init) 1
}

#-------------------------------------------------------------------------
# igloo::define



namespace eval ::igloo::define {
    variable thisClass ""
}

proc ::igloo::define {class args} {
    set ::igloo::define::thisClass $class

    if {[llength $args] == 1} {
        set script [lindex $args 0]
    } else {
        set script $args
    }

    try {
        namespace eval ::igloo::define $script
    } finally {
        set ::igloo::define::thisClass ""
    }
}

# NEXT, define the helper commands.

proc ::igloo::define::constructor {arglist body} {
    ::variable thisClass

    set prefix {
        my variable _igloo
        if {![info exists _igloo(init)]} {
            my _staticInit
        }
    }

    oo::define $thisClass constructor $arglist "$prefix\n$body"
}

proc ::igloo::define::method {name arglist body} {
    ::variable thisClass
    oo::define $thisClass method $name $arglist $body
}

proc ::igloo::define::superclass {args} {
    ::variable thisClass
    oo::define $thisClass superclass {*}$args
}

proc ::igloo::define::variable {name args} {
    ::variable thisClass

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
    set ns [info object namespace $thisClass]

    # NEXT, save the initialization data.
    set ${ns}::_iglooVars($name) [list $aflag $value]

    # NEXT, define the _staticInit method, if it hasn't already been defined.
    ::igloo::InstallInit $thisClass $ns

    # NEXT, declare it as an instance variable.
    oo::define $thisClass variable $name
}

#-------------------------------------------------------------------------
# igloo::class

# FIRST, define the igloo::class metaclass.  For now, it's a fake
# metaclass; we'll grow it later.

oo::object create igloo::class
oo::objdefine igloo::class {
    method create {class {defscript ""}} {
        oo::class create $class
        igloo::define $class $defscript
    }
}

#-------------------------------------------------------------------------
# Helpers

# InstallInit class ns
#
# class    - A class name
# ns     - The class's namespace
#
# Installs the _staticInit command in the class if it hasn't already
# been defined.

proc ::igloo::InstallInit {class ns} {
    # FIRST, don't redefine the method if it's already defined.
    if {"_staticInit" ni [info class methods $class -private]} {
        # NEXT, define the method.
        oo::define $class method _staticInit {} [format {
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
    # This uses the igloo version, which calls _staticInit.
    if {[llength [info class constructor $class]] == 0} {
        igloo::define::constructor {} {}
    }

}
