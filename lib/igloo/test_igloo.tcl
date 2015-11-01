oo::class create living {
    method howdy {} { return "Living!"}
}

source igloo.tcl

igloo::class animal {
    superclass living

    variable name   fred
    variable family mammalia

    method family {} {
        return $family
    }
}

igloo::class dog {
    superclass animal

    variable name spot
    variable data -array {
        this 1
        that 2
    }

    method dump {} {
        return "Dog: $name, [my howdy], this=$data(this), that=$data(that), [my family]"
    }
    export _staticInit
}

dog create mydog
puts [mydog ancestors]
puts [mydog dump]
puts <[info class call dog _staticInit]>

