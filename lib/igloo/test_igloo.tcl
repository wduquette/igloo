source igloo.tcl

oo::class create dog {
    var name spot
    var data -array {
        this 1
        that 2
    }

    method dump {} {
        return "Dog: $name, this=$data(this), that=$data(that)"
    }
}

dog create mydog
puts [mydog dump]

