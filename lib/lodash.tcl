
# lodash.tcl - Collection of utility methods
# Forked from: https://github.com/arthurschreiber/underscore-tcl
#
# Inspired by Underscore.js - http://underscorejs.org/ ,
# lodash.js - https://lodash.com/ and
# the Ruby Enumerable module.
#
# This package provides a collection of different utility methods that try to
# bring functional programming aspects known from other programming languages,
# like Ruby or JavaScript, to Tcl.
package provide lodash 0.10

namespace eval ::_ {

  namespace export *

  interp alias {} ::_::collect {} ::_::map
  interp alias {} ::_::every   {} ::_::all
  interp alias {} ::_::filter  {} ::_::select
  interp alias {} ::_::find    {} ::_::detect
  interp alias {} ::_::foldl   {} ::_::reduce
  interp alias {} ::_::foldr   {} ::_::reduceRight
  interp alias {} ::_::inject  {} ::_::reduce
  interp alias {} ::_::head    {} ::_::first
  interp alias {} ::_::include {} ::_::includes
  interp alias {} ::_::some    {} ::_::any
  interp alias {} ::_::tail    {} ::_::rest
  interp alias {} ::_::unique  {} ::_::uniq
}

# Yields a block of code in a specific stack-level.
#
# This function yields the passed block of code in a separate stack frame
# (by wrapping it into an ::apply call), but allows easy access to
# surrounding variables using the tcl-native upvar mechanism.
#
# Yielding the code in an anonymous proc prevents the leakage of variable
# definitions, while still giving the block access to surrounding variables
# using upvar.
#
# @example Calculating the first n Fibonacci numbers
#   proc fib_up_to { max block } {
#       set i1 [set i2 1]
#
#       while { $i1 <= $max } {
#           _::yield $block $i1
#           set tmp [expr { $i + $i2 }]
#           set i1 $i2
#           set i2 $tmp
#       }
#   }
#
#   fib_up_to 50 {{n} { puts $n }}
#   => prints the Fibonacci sequence up to 50
#
# @example Automatic resource cleanup
#   # Guarantees that the file descriptor is closed,
#   # even in case of an error being raised while executing the block.
#   proc file_open { path mode block } {
#       open $fd
#
#       # Catch any exceptions that might happen
#       set error [catch { _::yield $block $fd } value options]]
#
#       catch { close $fd }
#
#       if { $error } {
#           # if an exception happened, rethrow it
#           return {*}$options $value
#       } else {
#           # Do nothing
#           return
#       }
#   }
#
#   file_open "/tmp/test" "w" {{fd} {
#       puts $fd "test"
#   }}
#
# If you want to return from the stack frame where the method that yields a block
# was called from, you can use 'return -code return'.
#
# @example Returning from the stack frame that called the yielding method.
#   proc return_to_calling_frame {} {
#       _::each {1 2 3 4} {{item} {
#           if { $item == 2 } {
#               # Stops the iteration and will return "done" from "return_to_calling_frame"
#               return -code return "done"
#           }
#       }}
#       # This return will not be executed
#       return "fail"
#   }
#
# 'return -code break ?value?' and 'return -code continue ?value?' have special
# meanings inside a block.
#
# @example Passing a block down, by specifying a yield level
#   # Reverse each, like _::each, but in reverse
#   proc reverse_each { list block } {
#       _::each [lreverse $list] {{args} {
#           # Include the passed block
#           upvar block block
#
#           # we have to increase the yield level here, as we want to
#           # execute the block on the same stack level as reverse_each
#           # was called on
#           uplevel 1 [list _::yield $block {*}$args]
#       }}
#   }
#
# @example Passing a block down by upleveling the call to each.
#   # Reverse each, like _::each, but in reverse
#   proc reverse_each { list block } {
#       uplevel [list _::each [lreverse $list] $block]
#   }
#
# @param block_or_proc The block (anonymous function) or proc to be executed
#   with the passed arguments. If it's a block, it can be either in the form
#   of {args block} or {args block namespace} (see the documentation for ::apply).
# @param args The arguments with which the passed block should be called.
#
# @return Return value of the block.
proc _::yield { block_or_proc args } {
  # Stops type shimmering of $block_or_proc when calling llength directly
  # on it, which in turn causes the lambda expression to be recompiled
  # on each call to _::yield
  set block_dup [concat $block_or_proc]

  catch {
    if { [llength $block_dup] == 1 } {

      uplevel 2 [list $block_or_proc {*}$args]
    } else {

      uplevel 2 [list apply $block_or_proc {*}$args]
    }
  } result options

  dict incr options -level 1

  return -options $options $result
}

# Iterates over the passed list, yielding each element in turn to the
# passed iterator
#
#  @example
#   set list [list 1 2 3]
#
#   _::each $list {
#     { element } {
#       puts $element
#     }
#   }
#   => 1
#   => 2
#   => 3
#
# @param [list] list: The list to traverse
# @param [block] iterator: The block to invoke per iteration
# @return [list]  -- the given list
proc _::each { list iterator } {
  foreach item $list {

    _::yield $iterator $item
  }

  return $list
}

# Iterates over the passed list, yielding each element and its index in turn
# to the passed iterator.
#
# @example
#   set list [list 1 2 3]
#   _::eachIndex $list {
#     { element index } {
#       puts $index:$element
#     }
#   }
#   => 0:1
#   => 1:2
#   => 2:3
#
# @param [list] list: The list to traverse
# @param [block] iterator: The block to invoke per iteration
# @return [list] -- The given list.
proc _::eachIndex { list iterator } {
  set length [llength $list]

  for { set index 0 } { $index < $length } { incr index } {

    _::yield $iterator [lindex $list $index] $index
  }

  return $list
}

# Iterates over the passed list in slices of +number+ elements
# returning the original list
#
# @param [list] list: The list to slice
# @param [integer] number: The size grouping
# @param [block] iterator: The block to invoke per iteration
# @return [list] -- The original list
proc _::eachSlice { list size iterator } {
  if { $size < 1 } {

    return -code error "slice size must be equal to or greater than 1"

  }

  set length [llength $list]

  for { set index 0 } { $index < $length } { incr index $size } {

    _::yield $iterator [lrange $list $index [expr { $index + $size - 1 }]]
  }
  return $list
}

# Creates a list of elements split into groups the length of size.
# If collection can’t be split evenly, the final chunk will be the remaining elements.
#
# @example
#   _::chunk [list 1 2 3 4 5 56 6 7 8 9] 2
#   => {1 2} {3 4} {5 56} {6 7} {8 9}
#
# @param [list] list: the list to chunk up
# @size [integer] size: the group size of each chunk
# @return [list] -- the newly chunked list
proc _::chunk { list { size 1 } } {
  set result [list]

  _::eachSlice $list $size {
    { slice } {
      upvar result result
      _::push result $slice
    }
  }

  return $result
}

# Pushes an element onto the end of a list
#
# @note
#   This method mutates list
#
# @example
#   set li [list 1 2 3 4 5]
#   _::push li 6
#   set li
#   => 1 2 3 4 5 6
# @param [list] list: the list to add an element
# @param [any] element: the element to add
# @return [list]
proc _::push { list element } {
  upvar 1 $list l

  lappend l $element
}

# remove an element from the end of a list and return it
#
# @note
#   This method mutates list
#
# @example
#   set li [list 1 2 3 4 5]
#   _::pop li
#   => 5
# @param [list] list: the list to remove an element
# @param [integer] count: optional number of arguments to remove
# @return [any]  -- the removed element
proc _::pop { list { count 1 } } {
  upvar 1 $list array

  set result [lrange $array end-[incr count -1] end]
  set array [lreplace $array end-$count [set array end]]

  return $result
}

# remove an element from the beginning of a list
#
# @note
#   This method mutates list
#
# @example
#   set li [list 1 2 3 4 5]
#   _::shift li
#   => 1
#   set li
#   => 2 3 4 5
# @param [list] list: the list to remove an element
# @param [integer] count: optional number of arguments to remove
# @return [any]  -- the removed element
proc _::shift { list { count 1 } } {
  upvar 1 $list array

  set result [lrange $array 0 [incr count -1]]
  set array [lreplace $array [set array 0] $count]

  return $result
}

# add an element to the beginning of a list
#
# @note
#   This method mutates list
#
# @example
#   set li [list 1 2 3 4 5]
#   _::unshift li 0
#   set li
#   => 0 1 2 3 4 5
#
# @param [list] list: the list in which to add
# @param [any] element: the element to add
# @return [list]
proc _::unshift { list element } {
  upvar 1 $list array

  return [set array [linsert $array [set array 0] $element]]
}

# Returns a new list of values by applying the given block to each
# value of the given list.
#
# @example
#   set index -1
#   _::map [list 2 4 6 8] {{ n }
#     {
#     upvar index index
#     expr { $n * [incr index] }
#   }}
#   => 0 4 12 24
#
# @param [list] list: The list of elements to transform
# @param [block] iterator: The block to invoke per iteration
# @return [list]  -- The list of mapped elements
proc _::map { list iterator } {
  set result [list]

  foreach item $list {
    set status [catch { _::yield $iterator $item } return_value options]

    switch -exact -- $status {
      0 - 4 {
        # 'normal' return and errors
        _::push result $return_value
      }
      3 {
        # 'break' should return immediately
        return $return_value
      }
      default {
        # Just pass through everything else
        return -options $options $return_value
      }
    }
  }

  return $result
}

# randomly shuffles the contents of a list, returns the newly shuffled list
#
# @example
#   set li [list 1 2 3 4 5]
#   _::shuffle $li
#   => 5 2 3 4 1
#
# @param [list] list: The list to shuffle
# @return [list] -- the shuffled list
proc _::shuffle { list } {
  set length [llength $list]

  for { set index 0 } { $index < $length } { incr index } {
    set random_index [expr { int(rand() * [expr { $index + 1 }] ) } ]

    if { $index == $random_index } { continue }

    set item [lindex $list $index]
    set list [lreplace $list $index $index [lindex $list $random_index]]
    set list [lreplace $list $random_index $random_index $item]
  }

  return $list
}

# Determines if the passed value is empty and alone
#
# @example
#   _::empty [list 0 2 4]
#   => false
#
#   _::empty ""
#   => true
#
# @param [any] value: The value to check for emptiness
# @return [boolean]
proc _::empty { value } {
  expr { [llength [string trim $value]] ? false : true }
}

# Reduces list to a value which is the accumulated result of running
# each element in list through iteratee, where each successive invocation
# is supplied the return value of the previous. If accumulator is not provided
# the first element of collection is used as the initial value.
#
# @example
#   set li [list 2 4 6 8 10]
#   _::reduce $li {
#     { total n } {
#       expr { $total + $n }
#     }
#   }
#   => 30
#
# @param [list] list: the list of values to reduce
# @param [proc] iterator: the means of reduction
# @param [any] memo: initial starting value
# @return [any] -- reduced value
proc _::reduce { list iterator { memo undefined } } {
  if { $memo eq "undefined" } {

    if { [_::empty $list] } {

      return -code error "Reduce of empty list with no initial value"
    }

    set list [lassign $list memo]
  }

  foreach item $list {

    set memo [_::yield $iterator $memo $item]
  }

  return $memo
}

# This method is like _::reduce except that it iterates over
# elements of list from right to left.
#
# @example
#   set li [list 2 5 10 200]
  # _::reduceRight $li {
  #   { total n } {
  #     expr { $total / $n }
  #   }
  # }
#   => 2
#
# @param [list] list: the list of values to reduce
# @param [proc] iterator: the means of reduction
# @param [any] memo: initial starting value
# @return [any] -- reduced value
proc _::reduceRight { list iterator { memo undefined } } {
  if { $memo eq "undefined" } {

    if { [_::empty $list] } {

      return -code error "Reduce of empty list with no initial value"
    }

    set memo [_::pop list]
  }

  for { set index [expr { [llength $list] - 1 }] } { $index >= 0 } { incr index -1 } {
    set memo [_::yield $iterator $memo [lindex $list $index]]
  }

  return $memo
}

# Accepts a list and returns a new list with all 'falsey' values removed
# If the 'strict' option is true all normal Tcl boolean values are considered,
# which include 'f' and 'of' as false, else only "", 0 and false will be removed.
#
# @example
#   set l [list the {} 0 1 of [list] " " false true "string"]
#   _::compact $l true
#   => the 1 true string
# @param [list]: The list in which to remove falsey values
# @param [boolean] strict: Optionally enable strict boolean checking
# @return [list]
proc _::compact { list { strict false } } {
  set result [list]

  foreach item $list {
    if { ![_::empty $item] && ( ![_::isBoolean $item $strict] || $item ) } {

      _::push result $item
    }
  }

  return $result
}

# Checks if the value passed is a boolean value
# Optionally enable strict mode. If strict mode is false
# only true, false, 1 and 0 are considered boolean values (case insensitive)
#
# @example
#   _::isBoolean true
#   => 1
#   _::isBoolean f
#   => 0
#   _::isBoolean f true
#   => 1
#
# @note
#   This method only determines if a value is boolean and has no knowledge of its particular leanings
#
# @param [any] value: The value to check for booleanness
# @param [boolean] strict: Optionally enable strict mode
# @return [boolean]
proc _::isBoolean { value { strict false } } {
  if { $strict } {

    return [expr { [string is boolean -strict $value] ? true : false } ]
  }

  expr { [regexp -nocase -- (^true|false|0|1$) $value] ? true : false }
}

# Fills elements of list with value from start, up to, but not including, stop.
#
# @example
#   set l [list 4 6 8]
#   _::fill $l * 1 2
#   => [4 * 8]
#
# @param [list] list : The list to fill
# @param [any] value: The value to fill in the list
# @param [integer] start: The starting point of insertion
# @param [integer] stop: The stopping point of insertion
# @return [list]
proc _::fill { list value { start 0 } { stop 0 } } {
  if { $stop < 1 } {
    set stop [expr { [llength $list] + $stop }]
  }

  set start [_::max [list $start 0]]
  set length [llength $list]

  for { set index $start } { $index < $stop } { incr index } {
    if { $index < $length } {
      set list [lreplace $list [set list $index] $index $value]
    } else {
      lappend list $value
    }
  }

  return $list
}

# Creates a list of elements split into two groups,
# the first of which contains elements iterator returns truthy for,
# while the second of which contains elements iterator returns falsey for.
#
# @example
#   set li [list 1 2 3 4 5 6]
#   _::partition $li {
#     { element } {
#       expr { $element % 2 == 0 }
#     }
#   }
#   => {2 4 6} {1 3 5}
#
# @param [list] list: the list to split
# @param [proc] iterator: determines list splitting
# @return [[list][list]]
proc _::partition { list iterator } {
  set first [set second [list]]

  foreach value $list {
    if { [_::yield $iterator $value] } {

      _::push first $value
    } else {

      _::push second $value
    }
  }

  list $first $second
}

# Executes the passed iterator with each element of the passed list.
# Returns true if the passed block never returns a 'falsey' value.
#
# @example
#   set li [list 2 4 6 8 10]
#   _::all $li {
#     { element } {
#       expr { $element % 2 == 0 }
#     }
#   }
#   => true
#
# When no explicit iterator is passed, 'all' will return true
# if none of the list elements is a falsey value.
#
# @param [list] list: The list to check for truthy items
# @param [proc] iterator: the iteratee to determine truthiness
# @return [boolean]
proc _::all { list { iterator { { item } { return $item } } } } {
  foreach item $list {
    if { [string is false [_::yield $iterator $item]] } {

      return false
    }
  }

  return true
}

# Executes the passed iterator with each element of the passed list.
# Returns true if the passed block returns at least one value that
# is not 'falsey'.
#
# @example
#   set li [list 6 7 8 9 10]
#   _::any $li {
#     { element } {
#       expr { $element < 5 }
#     }
#   }
#   => false
#
# When no explicit iterator is passed, `_::any` will return true
# if at least one of the list elements is not a falsey value.
#
# @param [list] list: the list to check for a truthy item
# @param [proc] iterator: the iteratee to determine truthiness
# @return [boolean]
proc _::any { list {iterator { { item } { return $item } } } } {
  foreach item $list {
    if { ![string is false [_::yield $iterator $item]] } {

      return true
    }
  }

  return false
}

# Executes code if conditional is false. If the conditional is true,
# code specified in the else clause is executed.
#
# @example
#   _::unless { 5 < 3 } {
#     puts "5 is not less than 3"
#   }
#   => "5 is not less than 3"
#
# @param [expression] condition: The condition to determine truth, or lack thereof
# @param [any] args: the body to execute and any else(if)s and their corresponding bodies
# @return [void]
proc _::unless { condition args } {
  return -code [catch { uplevel [list if !($condition)] $args } res] $res
}

# returns the first element of a list
#
# @example
#   _::first [list 99 98 97 96]
#   => 99
#
# @param [list] list: The list to query
# @return [any]  -- The first element of the list
proc _::first { list } {
  return [baseSlice $list 0 1]
}

# Creates a slice of list with n elements dropped from the beginning.
#
# @example
#   set li [list 1 2 3 4 5]
#   _::drop $li
#   => 2 3 4 5
#
#   _::drop $li 3
#   => 4 5
#
# @param [list] list: the list to slice
# @param [integer] n: the number to drop from the beginning
# @return [list]
proc _::drop { list { n 1 } } {
  return [baseSlice $list [expr { $n < 0 ? 0 : $n }]]
}

# Creates a slice of list with n elements dropped from the end.
#
# @example
#   set li [list 1 2 3 4 5]
#   _::dropRight $li
#
#   => 1 2 3 4
#   _::dropRight $li 2
#   => 1 2 3
#
# @param [list] list: the list to slice
# @param [integer] n: the number to drop from the end
# @return [list]
proc _::dropRight { list { n 1 } } {
  set n [expr { [llength $list] -$n }]

  return [baseSlice $list 0 [expr { $n < 0 ? 0 : $n }]]
}

# Creates a slice of list from start up to, but not including, stop.
#
# @example
#   _::slice [list 1 2 3 4 5] 1 3
#   => { 2 3 }
#
# @param [list] list: The list to carve up
# @param [integer] start: The integer at which to start cutting
# @param [integer] stop: The integer at which the cutting stops before
# @param [list]  -- the sliced elements
proc _::slice { list { start 0 } { stop 0 } } {
  return [baseSlice $list $start $stop]
}


# The splice method changes the content of a list by removing existing
# elements and/or adding new elements.
#
# @note
#   This method mutates the list
#
# @example
#   set l { 1 2 3 4 5 6 7 8 9 10 }
#   _::splice l 1 2
#   => 2 3
#   set l
#   => 1 4 5 6 7 8 9 10
#   _::splice l 2 3 { 87 78 87 78 }
#   => 5 6 7
#   set l
#   => 1 4 { 87 78 87 78 } 8 9 10
#   _::splice l
#
# @param [list] list: The list to carve
# @param [integer] start: The index at which to begin
# @param [integer] count: Optionally pass the number of elements to slice
# @param [any] args: Optional arguments to replace removed elements
# @return [list]  -- The list of removed elements
proc _::splice { list start { count -1 } args } {
  upvar 1 $list array

  if { $start >= [llength $array] || ![llength $array] } {
    set array $args

    return [list]
  }

  if { ![string is integer $count] } {

    _::unshift args $count
    set count [expr { [llength $array] - 1 } ]
  } elseif { ![_::inRange $count 0 [llength $array]] } {

    set count [expr { [llength $array] - 1 } ]

  } else {

    set count [expr { $start + $count - 1 } ]
  }

  set result [lrange $array $start $count]
  set array [lreplace $array $start $count {*}$args]

  return $result
}

# This internal method provides the functionality for slice, drop(Right), first, rest, last, initial, etc...
proc baseSlice { list { start 0 } { stop 0 } } {
  set length [llength $list]

  if { $start < 0 } {

    set start [expr { -$start > $length ? 0 : [expr { $length + $start }] }]
  }

  if { $stop <= 0 } {

    set stop [expr { $stop + $length }]
  }

  lrange $list $start [expr { $stop - 1 }]
}

# Creates a slice of list with all elements except the first
#
# @example
#   _::rest [list 2 4 6 8 10]
#   => 4 6 8 10
#
# @param [list] list: the list to slice
# @return [list]
proc _::rest { list } {
  return [_::drop $list]
}

# Gets the last element of the list
#
# @example
#   _::last [list 99 98 97 96]
#   => 96
#
# @param [list] list: The list in which to fetch the last element
# @return [any]  -- the last element
proc _::last { list } {
  return [baseSlice $list [expr { [llength $list] - 1 }] [llength $list]]
}

# returns all but the last element of the passed list
#
# @example
#   _::initial [list 2 4 6 8 10]
#   => 2 4 6 8
#
# @param [list] list: the list to slice
# @return [list]
proc _::initial { list } {
  return [baseSlice $list 0 [expr { [llength $list] - 1 } ]]
}

# Retrieve the list index of value if it exists, else return negative one (-1)
#
# @example
#   _::indexOf [list 5 1 4 2 3] 3
#   => 4
#
# @param [list] list: The list to search
# @param [any] value: The element to search for
# @param [integer] index: Optional starting index
# @return [integer]  -- the found index, or -1
proc _::indexOf { list value { index 0 } } {
  if { $index < 0 } {

    set index [expr { [llength $list] + $index } ]
  }

  for { set length [llength $list] } { $index <  $length } { incr index } {

    if { [lindex $list $index] == $value } {

      return $index
    }
  }

  return -1
}

# Creates a list of elements corresponding to the given indexes of collection.
#
# @example
#   set li [list 10 20 30 40 50]
#   _::at $li [list 1 4]
#   => 20 50
#
# @param [list] collection: The collection to pluck from
# @param [list] values: A list of indexes from that correspond to desired elements in collection
# @return [list] -- A list of elements plucked at value indexes
proc _::at { collection values } {
  set result [list]

  _::each $values {
    { index } {
      upvar 1 result result collection collection
      _::push result [lindex $collection $index]
    }
  }

  return $result
}

# Returns a sorted copy of list. Sorting is based on the return
# values of the execution of the iterator for each item.
#
# @example
#   _::sortBy [list testings len of strings sort] {
#     { item } {
#       return [string length $item]
#     }
#   }
#   => { of len sort strings testings }
#
# @param [list] list: The list to sort
# @param [block] iterator: The sorting mechanism
# @param [boolean] reverse: Optionally reverse the order of the returned list
# @return [list] -- The sorted list
proc _::sortBy { list iterator { reverse false } } {
  set list_to_sort [ _::map $list {
    { item } {
      upvar iterator iterator
      list [uplevel [list yield $iterator $item]] $item
    }
  }]

  set sorted_list [lsort $list_to_sort]

  if { $reverse } {

    set sorted_list [lreverse $sorted_list]
  }

  _::map $sorted_list {
    { pair } {
      lindex $pair 1
    }
  }
}

# Executes the passed block n times.
#
# @example
#   _::times 10 puts
#   => prints 0-9
#
# @param [integer] n: The number of times to execute the passed block
# @param [block] iterator: The block to execute
# @return [void]
proc _::times { n iterator } {
  for { set index 0 } { $index < $n } { incr index } {

    _::yield $iterator $index
  }
}

# Creates a slice of list with n elements taken from the beginning.
#
# @example
#   set li [list 1 2 3 4 5]
#   _::take $li
#   => 1
#
#   _::take $li 3
#   => 1 2 3
#
# @param [list] list: The list to slice
# @param [integer] n: The number of elements to take
# @return [list]  -- the sliced elements
proc _::take { list { n 1 } } {
  if { !$n } {

    return [list]
  }

  return [baseSlice $list 0 $n]
}

# Creates a slice of list with n elements taken from the end.
#
# @example
#   set li [list 1 2 3 4 5]
#   _::takeRight $li
#   => 5
#
#   _::takeRight $li 3
#   => 3 4 5
#
# @param [list] list: The list to slice
# @param [integer] n: The number of elements to take
# @return [list]  -- the sliced elements
proc _::takeRight { list { n 1 } } {
  if { !$n || [_::empty $list] } {

    return [list]
  } elseif { $n > [llength $list] } {

    return $list
  }

  set n [expr [expr { $n < 0 ? abs($n) : [llength $list] - $n }]]

  return [baseSlice $list $n]
}

# Creates a slice of list with elements taken from the beginning.
# Elements are taken until predicate returns falsey,
# or until the list runs out of elements
#
# @example
#   _::takeWhile [list 1 2 3 4 5] {{ n } { expr { $n < 3 } }}
#   => 1 2
#
# @param [list] list: The list to take from
# @param [block] iterator: The block invoked per iteration
# @param [boolean] reverse: Optionally reverse the order in which the list is iterated
# @return [list]  -- the sliced list
proc _::takeWhile { list iterator { reverse false } } {
  set result [list]

  if { $reverse } {

    set list [lreverse $list]
  }

  foreach item $list {
    if { ![_::yield $iterator $item] } {

      break
    }

    expr { $reverse ? [_::unshift result $item] : [_::push result $item] }
  }

  return $result
}

# Splits a list into sets, grouping by the result of running each value through
# the iterator.
#
# The result is returned as a Tcl dictionary object, with each key corresponding
# to each distinct value assumed by the iterator over the provided list.
#
# @example
#   _::groupBy [list 1.3 2.1 2.4] {
#     { num } {
#       expr { floor($num) }
#     }
#   }
#   => 1.0 1.3 2.0 {2.1 2.4}
#
# @params [list] list: the list to group
# @params [block] iterator: the block invoked per iteration
# @return [list] -- the newly grouped list
proc _::groupBy { list iterator } {
  set result [dict create]

  foreach item $list {

    dict lappend result [_::yield $iterator $item] $item
  }

  return $result
}

# Calls the given block for each element in the list,
# returning a new list without the elements for which the block returned
# a truthy value.
#
# @example
#   set large [_::reject {1 2 3 4 5} {
#     {n} {
#       expr { $n < 3 }
#     }
#   }]
#   set large
#   => {3 4 5}
#
# @param list [list]
# @param block [lambda]
# @return [list]
proc _::reject { list block } {
  set result [list]

  foreach item $list {

    if { ![_::yield $block $item] } {

      _::push result $item
    }
  }

  return $result
}

# Calls the given block for each element in the list,
# returning a new list with the elements for which the block returned
# a truthy value.
#
# @example
#   set small [_::select {1 2 3 4 5} {
#     {n} {
#       expr { $n < 3 }
#     }
#   }]
#   set small
#   => {1 2}
#
# @param list [list]
# @param block [lambda]
# @return [list]
proc _::select { list block } {
  set result [list]

  foreach item $list {

    if { [_::yield $block $item] } {

      _::push result $item
    }
  }

  return $result
}

# Removes all elements from list that predicate returns
# truthy for and returns an list of the removed elements.
#
# @note
#   This method mutates list
#
# @example
#   set list [list 1 2 3 4 5]
#   _::remove list {
#     { n } {
#       expr { $n <= 3 }
#     }
#   }
#   => 1 2 3
#   set list
#   => 4 5
#
# @param [list] list: The list to remove items
# @param [block] block: The block to invoke each iteration
# @return [list]  -- a list of removed elements
proc _::remove { list block } {
  upvar 1 $list array

  set original $array

  _::difference $original [set array [_::reject $array $block]]
}

# Checks if target is in list
#
# @example
#   _::includes [list 10 20 30 40 50] 20
#   => true
#
#   _::includes [list 10 20 30 40 50] 20 2
#   => false
#
# @param [list] list: The list to search
# @param [any] item: The item to search for within the list
# @return [boolean]
proc _::includes { list item { index 0 } } {
  expr { ~[_::indexOf $list $item $index] ? true : false }
}

# Returns the elements that are only present in all lists
#
# @example
#   _::intersection [list 1 2 1] [list 7 4 2 9] [list 2 1 15 3 8 6 7]
#   => 2
#
# @param [lists] args: any number of lists
# @return [list]  -- The list of elements available in all passed lists
proc _::intersection { args } {
  set result [_::uniq {*}[_::shift args]]

  foreach list $args {
    set list [_::uniq $list]

    for { set index [expr [llength $result]-1] } { ~$index } { incr index -1 } {

      if { ![_::includes $list [lindex $result $index]] } {

        _::splice result $index 1
      }
    }
  }

  return $result
}

# Returns the elements that are unique to all lists
#
# @example
#   _::difference [list 1 2] [list 4 2] [list 2 1]
#   => 4
#
#   _::difference [list 1 7 2] [list 4 4 2] [list 2 3 1]
#   => 7 3
#
# @param [lists] args: any number of lists
# @return [list]  -- the list of unique elements
proc _::difference { args } {
  set lists [_::merge {*}$args]
  set result [list]

  while { [llength $lists] } {
    set element [lindex $lists 0]

    # determine if element is included more than once
    if { [_::includes $lists $element 1] } {

      # remove all items of value 'element'
      while { ~[set idx [_::indexOf $lists $element]] } {

        _::splice lists $idx 1
      }

    } else {

      _::push result [_::shift lists]
    }
  }

  return $result
}

# Creates a duplicate-free version of a list
#
# @example
#   _::uniq [list 2 1 4 4 2 5]
#   => 2 1 4 5
#
# @param [list] list: The list to inspect
# @return [list]  -- the new duplicate value free list
proc _::uniq { list } {
  set result [list]

  foreach item $list {

    if { ![_::includes $result $item] } {

      _::push result $item
    }
  }

  return $result
}

# Merge two or more lists into a single list,
# duplicate values will remain, if no duplicates are desired use _::union
#
# @example
#   _::merge { 1 2 3 } { 2 3 4 } { 3 4 5 } { 5 { 6 } 7 }
#   => 1 2 3 2 3 4 3 4 5 5 { 6 } 7
#
# @param [lists] args: Any number of lists
# @return [list]  -- The merged list of possible duplicate values
proc _::merge { args } {
  set index 0
  set length [llength $args]
  set result {}

  _::do {

    set result [list {*}$result {*}[lindex $args $index]]

  } while { [incr index] < $length }

  return $result
}

# an implementation of a do while/until loop for tcl
# taken from tcl wiki: http://wiki.tcl.tk/3603
#
# @example
#   set index -1
#   set list [list 1 2 3 4 5]
#   _::do {
#     puts [lindex $list [incr index]]
#   } while { $index < [expr { [llength $list]-1 } ] }
#
# @param [block] body: Block to execute every iteration
# @param [string] keyword: Must be while or until
# @param [block] expression: The condition to check, determines loop continuation
# @return [void]
proc _::do { body keyword expression } {
  if { $keyword eq "while" } {

    set expression "!($expression)"

  } elseif { $keyword ne "until" } {

    return -code error "unknown keyword \"$keyword\": must be until or while"
  }

  set condition [list expr $expression]

  while { true } {
    uplevel 1 $body

    if { [uplevel 1 $condition] } {

      break
    }
  }
}

# Looks through each value in the given list, returning the first one for
# which the block returned a truthy value.
#
# @example
#   set even [_::detect {1 2 3 4 5} {
#     { n } {
#       expr { $n < 3 }
#     }
#   }]
#   set even
#   => 2
#
# @param list [list]
# @param block [lambda]
# @return [list]
proc _::detect { list block } {
  foreach item $list {

    if { [_::yield $block $item] } {

      return $item
    }
  }
}

# This method is like _::find except that it returns the index of the first
# element block returns truthy for instead of the element itself.
#
# @example
# _::findIndex [list 98 34 67 23] {
#   { n } {
#     expr { $n < 50 }
#   }
# }
# => 1
#
# @param [list] list: The list to search
# @param [block] block: Invoked each iteration
# @param [integer] index: Index to start search
# @paran [boolean] all: Boolean to indicate finding all indexes
# @return [integer]  -- The discovered index or -1
proc _::findIndex { list block { index 0 } { all false } } {
  if { $index < 0 } {

    set index [expr [llength $list] + $index]
  }

  set length [llength $list]
  set result [list]

  for {} { $index < $length } { incr index } {

    if { [_::yield $block [lindex $list $index]] } {
      if { !$all } {

        return $index
      }

      _::push result $index
    }
  }

  expr { $all ? $result : -1 }
}

# Find all indexes matching block criteria and return in new list
#
# @example
#   _::findIndexes [list 1 9 2 8 3 7 4 6 5 10] {
#     { n } {
#       expr { $n < 5 }
#     }
#   }
#   => 0 2 4 6
#
# @param [list] list: The list to search
# @param [block] block: Executed each iteration
# @return [list]  -- The, possibly empty, list of found indexes
proc _::findIndexes { list block { index 0 } } {
  _::findIndex $list $block $index true
}

# Find the first instance of an element and inject an element
# before or after discovered element. Before is default.
#
# @example
#   _::findMap { 1 2 3 4 } 4 5 true
#   => { 1 2 3 4 5 }
#   _::findMap { 1 2 3 4 } 4 5
#   => { 1 2 3 5 4 }
#
# @param [list] list: The list to search
# @param [any] locate: The element to locate within the list
# @param [any] injection: The item to inject into the list
# @param [integer] start: Optional starting index
# @param [boolean] after: Determines injection before or after found element
# @return [list]
proc _::findMap { list locate injection { start 0 } { after false }} {
  if { ![string is integer $start] } {
    if { [_::isBoolean $start] } {

      set after $start
    }

    set start 0
  }

  if { ~[set index [_::findIndex $list {
    { element } {
      upvar 1 locate locate
      expr { $element == $locate }
    }
  } $start] ] } {

    if { $after } {

      incr index
    }

    set list [linsert $list $index $injection]
  }

  return $list
}

# Returns the largest value in the given list
# If an iterator function is provided, the result will be used for comparisons
#
# @example
#   set cats [list [dict create name "Buffy" age 16] [dict create name "Jessie" age 17] [dict create name "Fluffy" age 8]]
#   set oldest [_::max $cats {
#     { cat } {
#       dict get $cat age
#     }
#   }]
#   set oldest
#   => name Jessie age 17
#
# @param [list] list
# @param [lambda] iterator
# @return [any]  -- The maximum computed from iterator

proc _::max { list { iterator {{ item } { return $item }}} } {
  if { [_::empty $list] } {

    return -code error "cannot get the max of an empty list"
  }

  set last_computed {}
  set result {}

  foreach item $list {
    set computed [_::yield $iterator $item]

    if { [_::empty $last_computed] || $computed > $last_computed} {

      set last_computed $computed
      set result $item
    }
  }

  return $result
}

# Returns the smallest value in the given list
# If an iterator function is provided, the result will be used for comparisons
#
# @example
#   set numbers {10 5 100 2 1000}
#   set smallest [_::min $numbers]
#   set smallest; # => 2
#
# @param [list] list
# @param [lambda] iterator
# @return [any]  -- The minimium computed from iterator
proc _::min { list { iterator {{ item } { return $item }}} } {
  if { [_::empty $list] } {

    return -code error "cannot get the min of an empty list"
  }

  set last_computed {}
  set result {}

  foreach item $list {

    set computed [_::yield $iterator $item]

    if { [_::empty $last_computed] || $computed < $last_computed} {

      set last_computed $computed
      set result $item
    }
  }

  return $result
}

# Zip together multiple lists into a single list,
# with elements sharing an index joined together
#
# @example
#   set zipped [_::zip {Llama Cat Camel} {wool fur hair} {1 2 3}]
#   set zipped; # -> {{Llama wool 1} {Cat fur 2} {Camel hair 3}}
#
# @param ?args? One or more lists
# @return list
proc _::zip { args } {
  if { [_::empty $args] } {

    return -code error "Wrong # args: should be _::zip ?args?"
  }

  _::unzip $args
}

# Reverse the action of Zip, turning a list of lists into
# a list of lists for each index
#
# @example
#   set unzipped [_::unzip {{Llama wool 1} {Cat fur 2} {Camel hair 3}}]
#   set unzipped
#   -> {{Llama Cat Camel} {wool fur hair} {1 2 3}}
#
# @param [list] list: The list to zip
# @return [list]  -- A list of unzipped lists
proc _::unzip { list } {
  if { [_::empty $list] } {
    return [list]
  }

  set length [llength [_::max $list {
    { sublist } {
      llength $sublist
    }
  }]]

  set output [list]

  for { set index 0 } { $index < $length } { incr index } {

    set mapping [_::map $list {
      { sublist } {
        upvar index index
        lindex $sublist $index
      }
    }]

    _::push output $mapping
  }

  return $output
}

# Takes a list of Tcl dictionary objects and a key common to the keysets
# of all the dictionaries. Returns a list of the values of the dictionaries
# at the specified key.
#
# If the key is not actually present in any of the dictionaries, the empty list
# will be returned. Note that this works with arrays as well, if the arrays are
# placed into the list using 'array get'.
#
# @example
#   set stooges [list [dict create name moe age 40] [dict create name larry age 50] [dict create name curly age 60]]
#   _::pluck $stooges name
#   => moe larry curly
#
# @param [dict] collection: The collection from whence to pluck
# @param [any] key: The key to find pluckable items
# @return [list]  -- The found key elements
proc _::pluck { collection key } {
  set result [list]

  foreach dictionary $collection {
    if { [dict exists $dictionary $key] } {

      _::push result [dict get $dictionary $key]
    }
  }

  return $result
}

# Removes all provided arguments from list.
# returns the list of removed items
#
# @note
#   This method mutates list
#
# @example
#   set li [list 1 2 3 4 5]
#   _::pull li 1 3 5 88 34
#   => 1 3 5
#   set li
#   => 2 4
#
# @param [list] list: The list which to remove values
# @param [args] args: The arguments to remove from list
# @return [list] - the found and removed items
proc _::pull { list args } {
  upvar 1 $list array
  _::pullAll array $args
}

# Removes all provided values from list.
# returns the list of removed items
#
# @note
#   This method mutates list
#
# @example
#   set li [list 1 2 3 4 5]
#   _::pullAll li [list 1 3 5 88 34]
#   => 1 3 5
#   set li
#   => 2 4
#
# @param [list] list: The list which to remove values
# @param [list] values: The values to remove from list
# @return [list] - the found and removed items
proc _::pullAll { list values } {
  upvar 1 $list array

  set result [list]

  foreach item $values {
    if { [_::include $array $item] } {
      while { ~[set index [_::indexOf $array $item]] } {
        _::push result [_::splice array $index 1]
      }
    }
  }

  return $result
}

# Creates a list of unique values from any number of lists
# duplicate values are removed
#
# @example
#   _::union { 1 2 } { 4 7 } { 7 1 }
#   => 1 2 4 7
#
# @param [lists] args: Any number of lists
# @return [list]  -- the list of unique values
proc _::union { args } {
  return [_::uniq [_::merge {*}$args]]
}

# Flattens a nested list. If 'deep' is true the list is recursively flattened,
# otherwise it’s only flattened a single level.
#
# @example
#   _::flatten {1 2 { 2 3 { 4 5 { 6 7 }}}}
#   => 1 2 2 3 { 4 5 { 6 7 }}
#
# @param [list] list: The list to flatten
# @param [boolean] deep: Optionally flatten all nested lists
# @return [list]  -- the newly flattened list
proc _::flatten { list { deep false } } {
  return [baseFlatten $list $deep]
}

# Recursively flattens a nested list.
#
# @example
#   _::flattenDeep { 1 2 3 { 3 4 5 { 43 2 { 2 { 32 4 }}}}}
#   => 1 2 3 3 4 5 43 2 2 32 4
#
# @param [list] list: The list to flatten recursively
# @return [list]  -- the newly flattened list
proc _::flattenDeep { list } {
  return [baseFlatten $list true]
}

# Flattens a list depth times. Default is 1.
#
# @example
#   _::flattenDepth [list 1 2 3 { 3 4 5 { 43 2 { 2 { 32 4 }}}}]
#   => 1 2 3 3 4 5 { 43 2 { 2 { 32 4 }}}
#
#   _::flattenDepth [list 1 2 { 2 3 { 4 5 { 6 7 }}}] 2
#   => 1 2 2 3 4 5 { 6 7 }
#
# @param [list] list: The list to flatten
# @param [integer] depth: The number of times to flatten said list
# @return [list]  -- The newly flattened list
proc _::flattenDepth { list { depth 1 } } {
  set depth [_::max [list [expr { $depth + 1 }] 1]]

  while { [incr depth -1] && [_::hasDepth $list] } {
    set list [baseFlatten $list false]
  }

  return $list
}

# This internal method provides the functionality for flatten, flattenDeep,
# flattenDepth, depth and hasDepth
proc baseFlatten { list { deep false } { result {} } } {
  set index -1
  set length [llength $list]

  while { [incr index] < $length } {

    set value [lindex $list $index]

    if { $deep && [_::hasDepth $value] } {

      set result [baseFlatten $value true $result]
    } else {

      set result [_::merge $result $value]
    }
  }

  return $result
}

# Determine if passed value has any nested lists
#
# @example
#   _::hasDepth 3
#   => false
#   _::hasDepth { 1 2 3 }
#   => false
#   _::hasDepth { 1 { 2 { 3 } } }
#   => true
#
# @param [any] value: The value to check for nested lists
# @return [boolean]
proc _::hasDepth { value } {
  expr { [string trim $value] == [baseFlatten [string trim $value] false] ? false : true }
}

# Determine the depth of a list
#
# @example
#   _::depth 10
#   => 0
#   _::depth { 0 1 2 }
#   => 0
#   _::depth { 0 0 { 1 1 { 2 2 { 3 3 { 4 4 { 5 5 } } } } } }
#   => 5
#
# @note
#   be aware that a single list is considered to have NO depth
#
# @param [list] list: the depth discoveree
# @return [integer]
proc _::depth { list } {
  set depth 0

  while { [_::hasDepth [set list [expr { !$depth ? $list : [baseFlatten $list false] } ] ] ] } {

    incr depth
  }

  return $depth
}

# Determine if number is within range, up to, but not including stop
# Default range is 0 <= number < 1
#
# @example
#   _::inRange 7 5 10
#   => true
#   _::inRange 0.4 -1 -4.3
#   => false
#
# @param [integer] number: The number to check
# @param [integer] start: starting range
# @param [integer] stop: stopping range
# @return [boolean]
proc _::inRange { number { start 0 } { stop 1 } } {
  expr { $number >= [_::min [list $start $stop]] && $number < [_::max [list $start $stop]] ? true : false }
}

# Determine if the string starts with chars
#
# @example
#   _::startsWith "testing testing" "cat"
#   => false
#
#   _::startsWith "testing testing" "te"
#   => true
#
# @param [string] string: The string to match
# @param [string] chars: The characters for matching
# @return [boolean]
proc _::startsWith { string chars } {
  expr { [string match ${chars}* $string] ? true : false }
}

# Determine if the string ends with chars
#
# @example
#   _::endsWith "testing testcat" "cat"
#   => true
#
#   _::endsWith "catesting testing" "cat"
#   => false
#
# @param [string] string: The string to match
# @param [string] chars: The characters for matching
# @return [boolean]
proc _::endsWith { string chars } {
  expr { [string match *${chars} $string] ? true : false }
}

# Determine if the string contains chars
#
# @example
#   _::contains "test cat test" "cat"
#   => true
#
#   _::contains "test tac test" "cat"
#   => false
#
# @param [string] string: The string to search
# @param [string] chars: The characters for matching
# @return [boolean]
proc _::contains { string chars } {
  expr { [string match *${chars}* $string] ? true : false }
}

# Easily coerce any value into its boolean opposite
# This can take the place of '!' operator and allows
# for a more natural language feel to your code
#
# @example
#   _::not [_::empty "some string"]
#   => true
#
#   _::not [_::contains "the string to search" "match"]
#   => true
#
#   _::not [_::inRange 7 0 10]
#   => false
#
#   _::not [list]
#   => true
#
# @param [any] value: the value to coerce into boolean opposite
# @return [boolean]
proc _::not { value } {
  if {[catch {set result [expr { !$value ? true : false }]} ] } {
    set result [expr {[llength $value] ? false : true}]
  }

  return $result
}
