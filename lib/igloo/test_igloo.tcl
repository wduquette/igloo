oo::class create living {
    method howdy {} { return "Living!"}
}

source igloo.tcl

oo::class create animal {
    superclass living

    var name   fred
    var family mammalia

    method family {} {
        return $family
    }
}

oo::class create dog {
    superclass animal

    var name spot
    var data -array {
        this 1
        that 2
    }

    method dump {} {
        return "Dog: $name, [my howdy], this=$data(this), that=$data(that), [my family]"
    }
    export _init
}

dog create mydog
puts [mydog dump]
puts <[info class call dog _init]>

