coolj
=====

a simple LL-parser builder


This library should eventually replace topdown (this other parser builder I once wrote). It should be simpler and faster.

Since I mainly intend to use this library to base specialised parsers upon for reading all sorts of data formats, and because writing a BNF-parser is not really complex I think it is a good idea to take some shortcuts (to keep things simple and fast):

  - I am not defining an AST
  - I don't have a separate lexer and parser, in a way the lexer could be said to exist in the first two or three case/when-blocks of the parser
  - the amount of whitespace between tokens can be significant, just be sensible in writing your BNF and it won't bite you (really!)
  - the idea is that your BNF is compiled (read: translated) to Ruby code. Small parser-methods are defined on your class (easy to override or hook into) that together form a parser for a complete grammar.

  
That's it for now, more later. Good luck, have fun, use the source and send me your patches! (please)

