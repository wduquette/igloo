# test2.tcl
package require igloo

igloo::class create ::dog {
    option -name Spot
    option -breed mutt
}

dog create fido
