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
        } else {
            set class $name
        }
        # Create class if it doesn’t exist
        if {[info commands $class] eq {}} {
            if {$class eq "::igloo::object"} {
                oo::class create ::igloo::object {}
            } else {
                oo::class create $class { superclass ::igloo::object }
            }
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
    oo::define $class [string map [list %class% $class %ns% $ns] {
    method ancestors {{reverse 0}} {
        set result {}
        if {$reverse} {
           lappend result "%class%"
        }
        if {"%class%" eq "::igloo::object"} {
            lappend result ::oo::class
        } else {
            lappend result {*}[next $reverse]
        }
        if {!$reverse} {
            lappend result "%class%"
        }
        return $result
    }

    # Define _staticInit
    # NEXT, Define _staticInit.
    method _staticInit {} {
        # FIRST, chain to parent first, because we want to do this
        # initialization from the top of the inheritance hierarchy on
        # down.
        if {"%class%" ne "::igloo::object"} {
           next
        }
        # NEXT, initialize options
        # TBD: This builds up a collection of metadata for this 
        # specific object from the _iglooOptions of all parent classes.
        # It seems wasteful to duplicate it.  What would be preferable
        # would be to keep it all in the class or in some central
        # location, rather than duplicate it in each object.  But
        # that requires something that tracks changes to the 
        # object's class hierarchy.
        #
        # (Or... you could always listen to Sean and use the Metadata registry that
        # was designed for this purpose AND handles changes to class hierarchy already...)

        my variable options option_info
        set option_info {}
        if {[info exists %ns%::_iglooOptions]} {
            foreach {option value} [array get %ns%::_iglooOptions] {
                foreach {f v} $value {
                    dict set option_info $option $f $v
                }
                if {[dict exists $option_info -default]} {
                    set options($option) [dict get $option_info $option -default]
                }
            }
        }
        if {[info exists option_info]} {
            # Mix in the options class.
            if {"::igloo::optionMixin" ni [info class mixins %class%]} {
                oo::define %class% mixin ::igloo::optionMixin
            }
        }
        # NEXT, initialize each variable.
        if {[info exists %ns%::_iglooVars]} {
            foreach {var spec} [array get %ns%::_iglooVars] {
                my variable $var
                lassign $spec aflag value
                if {$aflag} {
                    array set $var $value
                } else {
                    set $var $value
                }
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

# option name ?defvalue?
# option name ?option value...?
#
# name      - The option name
# defvalue  - The option's default value, which defaults to ""
#
# Declares an option called "name".  The name must begin with a
# hyphen.  At present, it must consist of lower case letters and
# underscores, though this is open for discussion.
#
# In Snit, one could specify the option, resource, and class names;
# I don't imagine that this is required here.

proc ::igloo::define::option {name args} {
    ::variable thisClass
    ::variable thisNS

    set errRoot "Error in \"option $name...\""

    # FIRST, validate the option name
    if {![regexp {^-[a-z][a-z_]*$} $name]} {
        error "$errRoot, badly named option \"$name\"" 
    }

    # NEXT, save the option data and make options an instance variable.
    set ${thisNS}::_iglooOptions($name) $optInfo
    oo::define $thisClass variable options
    # TBD: Verify that it hasn't been delegated.

    # NEXT, save the option data
    namespace upvar $thisNS _iglooOptions _iglooOptions

    set _iglooOptions($name) [dict create \
        -default          "" \
        -validatemethod   "" \
        -configuremethod  "" \
        -cgetmethod       "" \
        -readonly         "" ]

    if {[llength $args] == 1} {
        dict set _iglooOptions($name) -default [lindex $args 0]
    } else {
        foreach {optopt val} $args {
            switch -exact -- $optopt {
                -default         -
                -validatemethod  -
                -configuremethod -
                -cgetmethod      {
                    dict set _iglooOptions($name) $optopt $val
                }
                -readonly        {
                    if {![string is boolean -strict $val]} {
                        error "$errRoot, -readonly requires a boolean, got \"$val\""
                    }
                    dict set _iglooOptions($name) $optopt $val
                }
                default {
                    error "$errRoot, unknown option definition option \"$optopt\""
                }
            }
        }
    }

    # NEXT, if this is the first option we need to mixin the 
    # option handling code, and declare the options variable.
    if {"::igloo::optionMixin" ni [info class mixins $thisClass]} {
        oo::define $thisClass variable options
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

# igloo::object
#
# This class is inherited by all classes that have options.
#
::igloo::class ::igloo::object {
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
                if {[catch [string map [list %self% [self] %field% $field %value% $value] [dict get $option_info $field validate-command]] res opts]} {
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
               set options($field) [eval [string map [list %self% [self] %field% $field %value% $value] [dict get $option_info $field map-command]]]
            } else {
               set options($field) $value
            }
            if {[dict exists $option_info $field set-command]} {
               eval [string map [list %self% [self] %field% $field %value% $value] [dict get $option_info $field set-command]]
            }
        }
    }
}

