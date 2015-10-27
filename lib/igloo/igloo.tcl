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

proc ::igloo::class {name args} {
    set new 0
    if {$name eq "new"} {
        set class [uplevel 1 {oo::class new { superclass ::igloo::object }}]
        set new 1
    } else {
        # FIRST, make sure the class is fully qualified
        if {![string match "::*" $name]} {
            set class ::[string trimleft [uplevel 1 {namespace current}]::$name :]
        }
        # Create class if it doesn’t exist
        if {[info commands $class] eq {}} {
            oo::class create $class { superclass ::igloo::object }
            set new 1
        }
    }

    set ns [info object namespace $class]
    if {!$new} {
        if {![info exists ${ns}::_igloo(igloo)]} {
            error "igloo::define on non-igloo class: \"$class\""
        }
    } else {
        set ${ns}::_igloo(constructor) 0
        set ${ns}::_igloo(superclass) 0
        set ${ns}::_igloo(igloo) 1
    }

    if {[llength $args] == 1} {
        set script [lindex $args 0]
    } else {
        set script $args
    }
    define $class $script
    return $class
}

proc ::igloo::define {name script} {
    # FIRST, make sure the class is fully qualified
    if {![string match "::*" $name]} {
        set class ::[string trimleft [uplevel 1 {namespace current}]::$name :]
    } else {
        set class $name
    }
    set ::igloo::define::thisClass $class
    set ns [info object namespace $class]
    set ::igloo::define::thisNS $ns

    try {
        namespace eval ::igloo::define $script
        if {![set ${ns}::_igloo(superclass)]} {
            # Define an empty superclass to trigger our magic
            ::igloo::define::superclass
        }
        if {![set ${ns}::_igloo(constructor)]} {
            # Define an empty constructor to trigger our magic
            ::igloo::define::constructor {} {}
        }
        ::igloo::dynamic_methods $class $ns
    } finally {
        set ::igloo::define::thisClass ""
        set ::igloo::define::thisNS ""
    }
}
#
proc ::igloo::dynamic_methods {class ns} {
    # Define ancestors
    oo::define $class method ancestors {{reverse 0}} {
       set result {}
       if {$reverse} {
         lappend result "%class"
       }
       if {"%class" ne "::igloo::object"} {
          lappend result {*}[next $reverse]
       }
       if {!$reverse} {
         lappend result "%class"
       }
       return $result
    }

    # Define _staticInit
    # NEXT, Define _staticInit.
    oo::define $class method _staticInit {} [string map [list %class $class %ns $ns] {
        puts "RUNNING _staticInit for [self]"
        # FIRST, chain to parent first, because we want to do this
        # initialization from the top of the inheritance hierarchy on
        # down.
        if {"%class" ne "::igloo::object"} {
           next
        }
        # NEXT, initialize options
        if {[info exists %ns::_iglooOptions]} {
            puts "Initializing options"
            my variable options option_info
            foreach {option value} [array get %ns::_iglooOptions] {
                foreach {f v} $value {
                    dict set option_info $option $f $v
                }
                set options($option) [dict getnull $option_info $option default]
            }
        }
        # NEXT, initialize each variable.
        if {[info exists %ns::_iglooVars]} {
            puts "Initializing variables"
            foreach {var spec} [array get %ns::_iglooVars] {
                my variable $var
                lassign $spec aflag value
                if {$aflag} {
                    array set $var $value
                } else {
                    set $var $value
                }
            }
        }
    }]
}


# NEXT, define the helper commands.

# Begin with a wrapper around all things oo::define
foreach proc [info commands ::oo::define::*] {
    set procname [namespace tail $proc]
    proc ::igloo::define::$procname args "
::variable thisClass
oo::define \$thisClass $procname {*}\$args
"
}

proc ::igloo::define::constructor {arglist body} {
    ::variable thisClass
    ::variable thisNS
    set ${thisNS}::_igloo(constructor) 1
    set prefix {
        my variable _igloo
        if {![info exists _igloo(init)]} {
            set _igloo(init) 1
            my _staticInit
        }
    }

    oo::define $thisClass constructor $arglist "$prefix\n$body"
}

proc ::igloo::define::superclass {args} {
  ::variable thisClass
  ::variable thisNS
  set ${thisNS}::_igloo(superclass) 1
    
  if {$thisClass ne "::igloo::object" && "::igloo::object" ni $args} {
    lappend args ::igloo::object
  }
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
# Option Handling Mother of all Classes

# igloo::object
#
# This class is inherited by all classes that have options.
#

oo::class create ::igloo::object {
    # Put MOACish stuff in here
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
oo::class create ::igloo::optionMixin {
    method configure {args} {
        my variable options option_info
        switch [llength $args] {
            0 {
                return [array get options]
            }
            1 {
                set field [lindex $args 0]
                if {![info exists options($field)]} {
                    error "Invalid option $field. Valid: [dict keys $option_info]"
                }
                return $options($field)
            }
            default {
                my configurelist $args
            }
        }
    }
    method cget {option} {
        my variable options option_info
        if {![info exists options($option)]} {
            error "Invalid option $field. Valid: [dict keys $option_info]"
        }
        return $options($option)
    }
  
    method option_info args {
        my variable options_info
        switch [llength $args] {
            0 { return $option_info }
            1 {
                set field [lindex $args 0]
                if {$field eq "list" } { 
                    return [dict keys $option_info]
                }
                if {![dict exists $option_info $field]} {
                    error "Invalid option $field. Valid [dict keys $option_info]"
                }
                return [dict get $option_info $field]
            }
            default {
                return [dict get $option_info {*}$args]
            }
        }
    }

    method configurelist values {
        my variable option_info options
        # Run all validation checks
        foreach {field value} $values {
            if {[dict exists $option_info $field validate-command]} {
                if {[catch [dict get $field validate-command [string map [list %self% [self] %field% $field %value% $value]] res opts]} {
                    return {*}$opts $res
                }
            }
        }
        # Ensure all options are valid
        foreach {field value} $values {
            if {![dict exists $option_info $field]} {
              error "Bad option $field. Valid: [dict keys $option_info]"
            }
        }
        # Set the values and apply them
        foreach {field value} $values {
            if {[dict exists $option_info $field map-command]} {
               set options($field) [eval [dict get $field map-command [string map [list %self% [self] %field% $field %value% $value]]]
            } else {
               set options($field) $value
            }
            if {[dict exists $option_info $field set-command]} {
               eval [dict get $field set-command [string map [list %self% [self] %field% $field %value% $value]]]
            }
        }
    }
}
