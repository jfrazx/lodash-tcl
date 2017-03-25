
# lodash-tcl

lodash-tcl provides a collection of different utility methods that try to
bring functional programming aspects known from other programming languages,
such as Ruby or JavaScript, to Tcl.


## USAGE  

#### yield
`_::yield block args`

Yields a block of code in a specific stack-level.  

This function yields the passed block of code in a separate stack frame  
(by wrapping it into an ::apply call), but allows easy access to  
surrounding variables using the tcl-native upvar mechanism.  

Yielding the code in an anonymous proc prevents the leakage of variable  
definitions, while still giving the block access to surrounding variables  
using upvar.  

Calculating the first n Fibonacci numbers

 ```tcl
 proc fib_up_to { max block } {
   set i1 [set i2 1]

   while { $i1 <= $max } {
     _::yield $block $i1
     set tmp [expr { $i + $i2 }]
     set i1 $i2
     set i2 $tmp
   }
 }

 fib_up_to 50 {{n} { puts $n }}
 => prints the Fibonacci sequence up to 50  
```

#### each
`_::each list iterator`

Iterates over the passed list, yielding each element in turn to the  
passed iterator. Returns the passed list.

```tcl
set list [list 1 2 3]

_::each $list {
  { element } {
    puts $element
  }
}
=> 1
=> 2
=> 3
```

#### eachIndex
`_::eachIndex list iterator`

Iterates over the passed list, yielding each element and its index in turn  
to the passed iterator. Returns the passed list.

```tcl
set list [list 1 2 3]
_::eachIndex $list {
  { element index } {
    puts $index:$element
  }
}
=> 0:1
=> 1:2
=> 2:3
```

#### map
`_::map list block`  

Returns a new list of values by applying the given block to each
value of the given list.

Alias: `_::collect`

```tcl
set index -1
_::map [list 2 4 6 8] {
  { n } {
    upvar 1 index index
    expr { $n * [incr index] }
  }
}
=> 0 4 12 24
```

#### chunk
`_::chunk list ?size`

Creates a list of elements split into groups the length of size.  
If collection can’t be split evenly, the final chunk will be the remaining elements.  

```tcl
_::chunk [list 1 2 3 4 5 56 6 7 8 9] 2
=> {1 2} {3 4} {5 56} {6 7} {8 9}
```

#### push
`_::push list element`

Pushes an element onto the end of a list, returning the list.   
Mutates list.

```tcl
set li [list 1 2 3 4 5]
_::push li 6
set li
=> 1 2 3 4 5 6
```

#### pop
`_::pop list ?count`

Remove 'count' elements from the end of a list, returning them.  
Mutates list.  

```tcl
set li [list 1 2 3 4 5]
_::pop li
=> 5
```

#### shift
`_::shift list ?count`

Remove 'count' elements from the beginning of a list, returning them.   
Mutates list.   

``` tcl
set li [list 1 2 3 4 5]
_::shift li
=> 1
set li
=> 2 3 4 5
```

#### unshift
`_::unshift list element`

Add an element to the beginning of a list, returning the list.  
Mutates list.  

``` tcl
set li [list 1 2 3 4 5]
_::unshift li 0
set li
=> 0 1 2 3 4 5
```

#### empty
`_::empty list`  

Determines if the passed value is empty and alone. Returns a boolean.  

```tcl
_::empty [list 0 2 4]
=> false

_::empty ""
=> true
```

#### shuffle
`_::shuffle list`  

Randomly shuffles the contents of a list, returns the newly shuffled list.  

```tcl
set li [list 1 2 3 4 5]
_::shuffle $li  
=> 5 2 3 4 1
```

#### reduce
`_::reduce list iterator memo`  

Reduces list to a value which is the accumulated result of running   
each element in list through iterator, where each successive invocation   
is supplied the return value of the previous. If memo is not provided   
the first element of collection is used as the initial value.   

Alias: `_::foldl`, `_::inject`

```tcl
set li [list 2 4 6 8 10]
_::reduce $li {
  { total n } {
    expr { $total + $n }
  }
}
=> 30
```

#### reduceRight
`_::reduceRight list iterator memo`  

This method is like `_::reduce` except that it iterates over  
elements of list from right to left.  

Alias: `_::foldr`  

```tcl
set li [list 2 5 10 200]
_::reduceRight $li {
  { total n } {
    expr { $total / $n }
  }
}
=> 2
```

#### compact
`_::compact list ?strict`

Accepts a list and returns a new list with all 'falsey' values removed.  
If the 'strict' option is true all normal Tcl boolean values are considered,  
which include 'f' and 'of' as false, among others, else only "", 0 and false will be removed.

```tcl
set li [list the {} 0 1 of [list] " " false true "string"]
_::compact $li true
=> the 1 true string
```

#### isBoolean
`_::isBoolean value ?strict`  

Checks if the value passed is a boolean value   
Optionally enable strict mode. If strict mode is false (default)    
only true, false, 1 and 0 are considered boolean values (case insensitive)   

```tcl
_::isBoolean true
=> true

_::isBoolean f
=> false

_::isBoolean f true
=> true
```

#### fill
`_::fill list value ?start ?stop`

Fills elements of list with value from start, up to, but not including, stop.   

```tcl
set li [list 4 6 8]
_::fill $li * 1 2
=> [4 * 8]

_::fill $li * 2 6
=> 4 6 * * * *
```

#### partition
`_::partition list iterator`

Creates a list of elements split into two groups,   
the first of which contains elements iterator returns truthy for,   
while the second of which contains elements iterator returns falsey for.   

```tcl
set li [list 1 2 3 4 5 6]
_::partition $li {
  { element } {
    expr { $element % 2 == 0 }
  }
}
=> {2 4 6} {1 3 5}
```

#### all
`_::all list iterator`  

Executes the passed iterator with each element of the passed list.  
Returns true if the passed block never returns a 'falsey' value.  

When no explicit iterator is passed, `_::all` will return true  
if none of the list elements is a falsey value.  

Alias: `_::every`  

```tcl
set li [list 2 4 6 8 10]
_::all $li {
  { element } {
    expr { $element % 2 == 0 }
  }
}
=> true
```

#### any
`_::any list iterator`  

Executes the passed iterator with each element of the passed list.  
Returns true if the passed block returns at least one value that  
is not 'falsey'.  

When no explicit iterator is passed, `_::any` will return true  
if at least one of the list elements is not a falsey value.  

Alias: `_::some`  

```tcl
set li [list 6 7 8 9 10]
_::any $li {
  { element } {
    expr { $element < 5 }
  }
}
=> false
```

#### first
`_::first list`

Returns the first element of a list.  

Alias: `_::head`

```tcl
_::first [list 99 98 97 96]
=> 99
```

#### last
`_::last list`  

Returns the last element of a list.   

```tcl
_::last [list 99 98 97 96]
=> 96
```

#### initial
`_::initial list`

Returns all but the last element of the passed list.  

```tcl
_::initial [list 2 4 6 8 10]
=> 2 4 6 8
```

#### rest
`_::rest list`

Creates a slice of list with all elements except the first.  

Alias: `_::tail`

```tcl
_::rest [list 2 4 6 8 10]
=> 4 6 8 10
```

#### drop
`_::drop list ?n`  

Creates a slice of list with n elements dropped from the beginning.   

```tcl
set li [list 1 2 3 4 5]  
_::drop $li
=> 2 3 4 5

_::drop $li 3
=> 4 5
```

#### dropRight
`_::dropRight ?n`

Creates a slice of list with n elements dropped from the end.   

```tcl
set li [list 1 2 3 4 5]  
_::dropRight $li

=> 1 2 3 4
_::dropRight $li 2
=> 1 2 3
```

#### slice
`_::slice list ?start ?stop`  

Creates a slice of list from start up to, but not including, stop.  

```tcl
set li [list 1 2 3 4 5]
_::slice $li 1 3
=> 2 3
```

#### splice
`_::splice list start ?count args`

The splice method changes the content of a list by removing existing  
elements and/or adding new elements. Returns the removed elements.  
Mutates list.  

```tcl
set li { 1 2 3 4 5 6 7 8 9 10 }
_::splice li 1 2
=> 2 3
set li
=> 1 4 5 6 7 8 9 10

_::splice li 2 3 { 87 78 87 78 }
=> 5 6 7
set li
=> 1 4 { 87 78 87 78 } 8 9 10
```

#### indexOf
`_::indexOf list value ?startIndex`

Retrieve the list index of value if it exists, else return negative one (-1).   
Optionally set a starting index.   

```tcl
_::indexOf [list 5 1 4 2 3] 3
=> 4
```

#### includes
`_::includes list value ?startIndex`

Checks if value is in list, optionally include a starting index

Alias: `_::include`  

```tcl
_::includes [list 10 20 30 40 50] 20
=> true

_::includes [list 10 20 30 40 50] 20 2
=> false
```

#### at
`_::at list indexes`

Creates a list of elements corresponding to the given indexes of list.  

```tcl
set li [list 10 20 30 40 50]
_::at $li [list 1 4]
=> 20 50
```

#### sortBy
`_::sortBy list iterator ?reverse`

Returns a sorted copy of list. Sorting is based on the return  
values of the execution of the iterator for each item.  
Optionally reverse the order of the returned list   

```tcl
_::sortBy [list testings len of strings sort] {
  { item } {
    string length $item
  }
}
=> of len sort strings testings
```

#### times
`_::times n iterator`  

Executes the passed block n times.   

```tcl
_::times 10 puts
=> prints 0-9
```

#### take
`_::take list ?n`

Creates a slice of list with n elements taken from the beginning.   

```tcl
set li [list 1 2 3 4 5]
_::take $li
=> 1

_::take $li 3
=> 1 2 3
```

#### takeRight
`_::takeRight list ?n`  

Creates a slice of list with n elements taken from the end.  

```tcl
set li [list 1 2 3 4 5]
_::takeRight $li
=> 5

_::takeRight $li 3
=> 3 4 5
```

#### takeWhile
`_::takeWhile list iterator ?reverse`  

Creates a slice of list with elements taken from the beginning.  
Elements are taken until iterator returns falsey,
or until the list runs out of elements.  
Optionally reverse the traversal of the list.  

```tcl
_::takeWhile [list 1 3 10 2 5] {
  { n } {
    expr { $n < 3 }
  }
}
=> 1

_::takeWhile [list 1 3 10 2 5] {
  { n } {
    expr { $n < 10 }
  }
} true
=> 2 5
```

#### groupBy
`_::groupBy list iterator`

Splits a list into sets, grouping by the result of running each value through  
the iterator.  

The result is returned as a Tcl dictionary object, with each key corresponding  
to each distinct value assumed by the iterator over the provided list.   

```tcl
_::groupBy [list 1.3 2.1 2.4] {
  { num } {
    expr { floor($num) }
  }
}
=> 1.0
      1.3
   2.0 {
     2.1
     2.4
   }
```

#### reject
`_::reject list iterator`

Calls the given iterator for each element in the list,  
returning a new list without the elements for which the iterator returned  
a truthy value.  

```tcl
_::reject [list 1 5 3 4 2] {
  { n } {
    expr { $n < 3 }
  }
}
=> 5 3 4
```

#### select
`_::select list iterator`

Calls the given iterator for each element in the list,  
returning a new list with the elements for which the iterator returned  
a truthy value.  

Alias: `_::filter`  

```tcl
_::select [list 1 2 3 4 5] {
  { n } {
    expr { $n < 3 }
  }
}
=> 1 2
```

#### remove
`_::remove list iterator`  

Removes all elements from list that iterator returns  
truthy for and returns an list of the removed elements.  
Mutates list.

```tcl
set li [list 1 2 3 4 5]
_::remove li {
  { n } {
    expr { $n <= 3 }
  }
}
=> 1 2 3
set li
=> 4 5
```

#### intersection
`_::intersection args`  

Creates a list of unique values that are included in all of the provided lists.  

```tcl
_::intersection [list 1 2] [list 4 2] [list 2 1]
=> 2
```

#### difference
`_::difference args`

Creates a list of unique values not included in the other provided lists.    

```tcl
_::difference [list 1 2] [list 4 2] [list 2 1] [list 7 7]
=> 4

_::difference [list 1 7 2] [list 4 4 2] [list 2 3 1]
=> 7 3
```

#### uniq
`_::uniq list`  

Creates a duplicate-free version of a list.  

Alias: `_::unique`  

```tcl
_::uniq [list 2 1 4 4 2 5]  
=> 2 1 4 5
```

#### merge
`_::merge args`  

Merge two or more lists into a single list,  
duplicate values will remain, if no duplicates are desired use `_::union`  

```tcl
_::merge { 1 2 3 } { 2 3 4 } { 3 4 5 } { 5 { 6 } 7 }  
=> 1 2 3 2 3 4 3 4 5 5 { 6 } 7
```

#### union
`_::union args`  

Creates a list of unique values from any number of lists  
duplicate values are removed  

```tcl
_::union { 1 2 } { 4 7 } { 7 1 }  
=> 1 2 4 7
```

#### do
`_::do body keyword condition`  

An implementation of a do while/until loop for Tcl.  
Repeats body while condition is true or until the condition becomes true.  
Keyword must be 'while' or 'until'.  

```tcl
set index -1
set list [list 1 2 3 4 5]
_::do {
  puts [lindex $list [incr index]]
} while { $index < [expr { [llength $list]-1 } ] }
=> prints 1-5
```

#### unless
`_::unless condition body`

Executes body if the condition tests false.

```tcl
_::unless { 5 < 3 } {
  puts "5 is not less than 3"
}
=> 5 is not less than 3
```

#### detect
`_::detect list iterator`

Looks through each value in the given list, returning the first one for  
which the iterator returned a truthy value.  

Alias: `_::find`  

```tcl
_::detect [list 1 2 3 4 5] {
  { n } {
    expr { $n < 3 }
  }
}
=> 1
```

#### findIndex
`_::findIndex list iterator ?startIndex`  

This method is like `_::find` except that it returns the index of the first  
element block returns truthy for instead of the element itself.  

```tcl
_::findIndex [list 98 34 67 23] {
  { n } {
    expr { $n < 50 }
  }
}
=> 1  
```

#### findIndexes
`_::findIndexes list iterator`   

Find all indexes matching iterator criteria and return in new list.  

```tcl
_::findIndexes [list 1 9 2 8 3 7 4 6 5 10] {
  { n } {
    expr { $n < 5 }
  }
}
=> 0 2 4 6
```

#### findMap
`_::findMap list value injector ?startIndex ?after`

Find the first instance of value and inject injector
before or after discovered element.  
Optionally indicate a starting index.  

```tcl
_::findMap [list 1 2 3 4] 4 5 true
=> 1 2 3 4 5

_::findMap [list 1 2 3 4] 4 5
=> 1 2 3 5 4

_::findMap [list 1 4 3 4 7 9 4 2] 4 addme 4 true
=> 1 4 3 4 7 9 4 addme 2

_::findMap [list 1 4 3 4 7 9 4 2] 4 addme 10
=> 1 4 3 4 7 9 4 2
```

#### max
`_::max list ?iterator`

Returns the largest value in the given list  
If an iterator function is provided, the result will be used for comparisons  

```tcl
set cats [list [dict create name "Buffy" age 16] [dict create name "Jessie" age 17] [dict create name "Fluffy" age 8]]
_::max $cats {
  { cat } {
    dict get $cat age
  }
}
=> name Jessie age 17

_::max [list 15 32 87 24]
=> 87
```

#### min
`_::min list ?iterator`

Returns the smallest value in the given list   
If an iterator function is provided, the result will be used for comparisons   

```tcl
_::min [list 5 10 39 4 77]
=> 4
```

#### zip
`_::zip args`

Zip together multiple lists into a single list,   
with elements sharing an index joined together.   

```tcl
_::zip {Llama Cat Camel} {wool fur hair} {1 2 3}
=> {Llama wool 1} {Cat fur 2} {Camel hair 3}
```

#### unzip
`_::unzip list`

Reverse the action of `_::zip`, turning a list of lists into   
a list of lists for each index.

```tcl
_::unzip {{Llama wool 1} {Cat fur 2} {Camel hair 3}}
=> {Llama Cat Camel} {wool fur hair} {1 2 3}
```

#### pluck
`_::pluck collection key`

Takes a list of Tcl dictionary objects and a key common to the keysets  
of all the dictionaries. Returns a list of the values of the dictionaries  
at the specified key.  

If the key is not actually present in any of the dictionaries, the empty list  
will be returned. Note that this works with arrays as well, if the arrays are  
placed into the list using 'array get'.  

```tcl
set stooges [list [dict create name moe age 40] [dict create name larry age 50] [dict create name curly age 60]]
_::pluck $stooges name
=> moe larry curly
```

#### pull
`_::pull list args`

Removes all provided arguments from list and returns a list of found and removed items.  
Mutates list.  

```tcl
set li [list 1 2 3 4 5]
_::pull li 1 3 5 88 34
=> 1 3 5
set li
=> 2 4
```

#### pullAll
`_::pullAll list values`

Removes all provided values from list and returns a list of found and removed items.    
Mutates list.  

```tcl
set li [list 1 2 3 4 5]
_::pullAll li [list 1 3 5 88 34]
=> 1 3 5
set li
=> 2 4
```

#### flatten
`_::flatten list ?deep`

Flattens a nested list. If 'deep' is true the list is recursively flattened,  
otherwise it’s only flattened a single level.  

```tcl
_::flatten [list 1 2 { 2 3 { 4 5 { 6 7 }}}]
=> 1 2 2 3 { 4 5 { 6 7 }}

_::flatten [list 1 2 { 2 3 { 4 5 { 6 7 }}}] true
=> 1 2 2 3 4 5 6 7
```

#### flattenDeep
`_::flattenDeep list`

Recursively flattens a nested list.   

```tcl
_::flattenDeep [list 1 2 3 { 3 4 5 { 43 2 { 2 { 32 4 }}}}]
=> 1 2 3 3 4 5 43 2 2 32 4
```

#### flattenDepth
`_::flattenDepth list ?depth`

Flattens a list depth times. Returns a new list. Default depth is 1.      

```tcl
_::flattenDepth [list 1 2 3 { 3 4 5 { 43 2 { 2 { 32 4 }}}}]
=> 1 2 3 3 4 5 { 43 2 { 2 { 32 4 }}}

_::flattenDepth [list 1 2 { 2 3 { 4 5 { 6 7 }}}] 2
=> 1 2 2 3 4 5 { 6 7 }
```

#### hasDepth
`_::hasDepth list`

Determine if passed list has any nested lists.  

```tcl
_::hasDepth 3
=> false

_::hasDepth { 1 2 3 }
=> false

_::hasDepth { 1 { 2 { 3 } } }
=> true
```

#### depth
`_::depth list`

Determine the depth of the passed list.  
Be aware that a single list is considered to have NO depth.  

```tcl
_::depth 10
=> 0

_::depth { 0 1 2 }
=> 0

_::depth { 0 0 { 1 1 { 2 2 { 3 3 { 4 4 { 5 5 } } } } } }
=> 5
```

#### inRange
`_::inRange number ?start ?stop`

Determine if number is within range, up to, but not including stop.  
Default range is 0 <= number < 1   

```tcl
_::inRange 7 5 10
=> true

_::inRange 0.4 -1 -4.3
=> false
```

#### startsWith
`_::startsWith string chars`

Determine if the passed string starts with chars.  

```tcl
_::startsWith "testing testing" "cat"
=> false

_::startsWith "testing testing" "te"
=> true
```

#### endsWith
`_::endsWith string chars`

Determine if the passed string ends with chars.  

```tcl
_::endsWith "testing testcat" "cat"
=> true

_::endsWith "catesting testing" "cat"
=> false
```

#### contains
`_::contains string chars`

Determine if the passed string contains chars.  

```tcl
_::contains "test cat test" "cat"
=> true

_::contains "test tac test" "cat"
=> false
```

### Origins

Fork of [underscore-tcl](https://github.com/arthurschreiber/underscore-tcl)  

Inspired by:   
[lodash](https://lodash.com/)   
[underscore.js](http://underscorejs.org/)
