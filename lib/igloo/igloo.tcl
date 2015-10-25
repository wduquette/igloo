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

oo::define oo::object method _staticInit {} {}

#-------------------------------------------------------------------------
# igloo::define



namespace eval ::igloo::define {
    variable thisClass ""
}

proc ::igloo::define {class args} {
    set ::igloo::define::thisClass $class
    set ns [info object namespace $class]
    set ::igloo::define::thisNS $ns

    if {![info exists ${ns}::_igloo(igloo)]} {
        error "igloo::define on non-igloo class: \"$class\""
    }

    if {[llength $args] == 1} {
        set script [lindex $args 0]
    } else {
        set script $args
    }

    try {
        namespace eval ::igloo::define $script
    } finally {
        set ::igloo::define::thisClass ""
        set ::igloo::define::thisNS ""
    }
}

# NEXT, define the helper commands.

proc ::igloo::define::constructor {arglist body} {
    ::variable thisClass

    set prefix {
        my variable _igloo
        if {![info exists _igloo(init)]} {
            set _igloo(init) 1
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

proc ::igloo::define::option {name {defvalue ""}} {
    ::variable thisClass
    ::variable thisNS

    puts "Defining option $name $defvalue"

    # FIRST, validate the option name
    # TODO

    # NEXT, save the option data and make options an instance variable.
    set ${thisNS}::_iglooOptions($name) $defvalue
    oo::define $thisClass variable options

    # NEXT, mix in the options class.
    if {"::igloo::optionMixin" ni [info class mixins $thisClass]} {
        puts "Mixing in ::igloo::optionMixin"
        oo::define $thisClass mixin ::igloo::optionMixin
    }
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

    # NEXT, declare it as an instance variable.
    oo::define $thisClass variable $name
}

#-------------------------------------------------------------------------
# igloo::class

# FIRST, define the igloo::class metaclass.  For now, it's a fake
# metaclass; we'll grow it later.

oo::object create igloo::class
oo::objdefine igloo::class {

    # create class ?defscript?
    #
    # class      - A class name
    # defscript  - Optionally, an igloo::define script
    #
    # Creates an igloo::class, optionally configuring it.

    method create {class {defscript ""}} {
        # FIRST, Create the class
        oo::class create $class

        # NEXT, get the namespace and mark it as an igloo::class
        set ns [info object namespace $class]
        set ${ns}::_igloo(igloo) 1

        # NEXT, Give it a default constructor that calls _staticInit as
        # needed.
        igloo::define $class constructor {} {}

        # NEXT, Define _staticInit.
        oo::define $class method _staticInit {} [string map [list %ns $ns] {
            # FIRST, chain to parent first, because we want to do this
            # initialization from the top of the inheritance hierarchy on
            # down.
            next

            # NEXT, initialize options
            if {[info exists %ns::_iglooOptions]} {
                puts "Initializing options"
                foreach {option value} [array get %ns::_iglooOptions] {
                    set options($option) $value
                }
            }

            # NEXT, initialize each variable.
            foreach {var spec} [array get %ns::_iglooVars] {
                lassign $spec aflag value

                if {$aflag} {
                    array set $var $value
                } else {
                    set $var $value
                }
            }
        }]


        igloo::define $class $defscript
    }
}


#-------------------------------------------------------------------------
# Option Handling Mix-in

# igloo::optionMixin
#
# This class is mixed into classes that have options.
#
# TODO: Flesh this out to give complete Snit-like behavior:
#
# * Option options (e.g., -defvalue, -readonly, -configuremethod)
#
# TODO: Add error handling.

oo::class create igloo::optionMixin {
    variable options

    method configure {args} {
        # TODO: validate option names
        foreach {option value} $args {
            set options($option) $value
        }
    }

    method cget {option} {
        return $options($option)
    }
}