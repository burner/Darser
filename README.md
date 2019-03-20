# Darser: A LL(1)+ Parser/Ast Generator

Given a language BNF, as e.yaml, darser will generate a parser, a set of classes
making up the AST, a visitor class and a AST printer class.
The parser, AST, and visitor can be extended by hand written extensions,
see $ darser --help for more information.

e.yaml
```yaml
Expression:
    Postfix: [PostfixExpression#post]

PostfixExpression:
    Primary: [PrimaryExpression#prim]
    Array: [PrimaryExpression#prim, lbrack, Expression#expr, rbrack]
    Call: [PrimaryExpression#prim, lparen, Expression#expr, rparen]

PrimaryExpression:
    Identifier: [ identifier#value ]
    Float: [ float64#value ]
    Integer: [ integer#value ]
    Parenthesis: [lparen, Expression#expr, rparen]
```

Expression, PostfixExpression, and PrimaryExpression are rules.
One level of indentation gives the subrules.
All subrules for one rule must the representable by a trie.
The entries in the square brackets are the rule elements.
Rule elements are either tokens or rules.
Rules start with upper case letters token with lower case letters.
If a rule element is followed by a # it is stored in the AST node.
Rule elements that appear in multiple sub rules and are stored need to have the
name.

The Lexer passed to the ctor of Parser needs to be an input range.

About Kaleidic Associates
-------------------------
We are a boutique consultancy that advises a small number of hedge fund clients.  We are
not accepting new clients currently, but if you are interested in working either remotely
or locally in London or Hong Kong, and if you are a talented hacker with a moral compass
who aspires to excellence then feel free to drop me a line: laeeth at kaleidic.io

We work with our partner Symmetry Investments, and some background on the firm can be
found here:

http://symmetryinvestments.com/about-us/
