require 'English'

module CoolJ

  class DoesNotParse < StandardError; end


  class Parser
    def initialize(input)
      @input = StringScanner.new(input)
    end

    def parse_literal(literal)
      @input.scan Regexp.new(Regexp.escape(literal))
    end

    def parse_case_insensitive_literal(literal)
      @input.scan Regexp.new(Regexp.escape(literal), Regexp::IGNORECASE)
    end

    def self.parser(name, bnf)
#       puts name
      str = ["def parse_#{name}", "  " + bnf_to_ruby(bnf), "end"].join("\n")
      puts '#' + "-"*10, "# #{name} ::= #{bnf}", str, ""
      self.class_eval str
    end
  end


  class BnfParser
    # first the terminals:
    IDENTIFIER = /(\w+)/ # like: name or foo or while or do
    LITERAL = /\"(\w+)\"|\'(\w+)\'/ # TODO fix character class
    CASE_INSENSITIVE_LITERAL = /\"(\w+)\"i|\'(\w+)\'/

    # then the non-terminals
    EXPRESSION = /\%(\w+)\%/ # like %expr1%%

    PLUS = /#{EXPRESSION}\+/
    STAR = /#{EXPRESSION}\*/
    BRACKETS = /\(#{EXPRESSION}\)/
    SQUARE_BRACKETS = /\[#{EXPRESSION}\]/

    ALTERNATION = /#{EXPRESSION} | #{EXPRESSION}/
    CONCATENATION = /#{EXPRESSION} , #{EXPRESSION}/
  end


  # http://tools.ietf.org/html/rfc5234
  module Rfc5234
    EXPRESSION = /(\ə\d+)/ # something like ə1

    def next_expression
      @expression_number = @expression_number.to_i + 1
      "ə#{@expression_number}"
    end

    # Terminal Values
    BINARY = /\%b[0-1]+/
    DECIMAL = /\%d[0-9]+/
    HEXADECIMAL = /\%x[0-9A-Fa-f]+/
    # no support for dot-concatenation yet

    LITERAL = /\"([^"]+)\"/ # ABNF strings are case insensitive and the character set for these strings is US-ASCII.

    RULE_NAME = /([a-z]+)|\<([a-z]+)\>/

    # Operators
    CONCATENATION = /#{EXPRESSION} #{EXPRESSION}/ # foo bar
    ALTERNATIVES =  /#{EXPRESSION} \/ #{EXPRESSION}/ # foo / bar
    # I don't support Incremental Alternatives
    # no support for Value Range Alternatives
    GROUPING = /\(\s*#{EXPRESSION}\s*\)/ # (foo bar baz / whatever)
    REPETITION = /(\d*)\*(\d*)#{EXPRESSION}/ # *foo  or  4*10line
    SPECIFIC_REPETITION = /(\d+)#{EXPRESSION}/ # 3foo  or  42(foz quux)
    OPTIONAL = /\[#{EXPRESSION}\]/ # [foo bar]

    COMMENT = /;(.*)$/

    def literal(literal)
      "parse_literal(#{literal.inspect})"
    end

    def rule_name(name)
      "parse_#{name}"
    end

    def concatenation(left, right)
      "#{left} and #{right}"
    end

    def alternatives(left, right)
      "#{left} or #{right}"
    end

    def grouping(grouping)
      "(#{grouping})"
    end

    def optional(optional)
      "(#{optional} or true)"
    end

    def bnf_to_ruby(bnf, exp = next_expression)
      puts "parse\t#{bnf}"
      case bnf
      when COMMENT
        bnf_to_ruby($PREMATCH) + "##{$1}"
      when BINARY, DECIMAL, HEXADECIMAL, LITERAL
        bnf_to_ruby($PREMATCH + exp + $POSTMATCH).sub(exp, literal($1))
      when RULE_NAME
#         puts "rule name #{$~}"
        bnf_to_ruby($PREMATCH + exp + $POSTMATCH).sub(exp, rule_name($1))

      when REPETITION, SPECIFIC_REPETITION
        bnf_to_ruby($PREMATCH + exp + $POSTMATCH).sub(exp, code_for($1))
      when GROUPING
        bnf_to_ruby($PREMATCH + exp + $POSTMATCH).sub(exp, grouping($1))
      when OPTIONAL
        bnf_to_ruby($PREMATCH + exp + $POSTMATCH).sub(exp, optional($1))
      when CONCATENATION
        bnf_to_ruby($PREMATCH + exp + $POSTMATCH).sub(exp, concatenation($1, $2))
      when ALTERNATIVES
        bnf_to_ruby($PREMATCH + exp + $POSTMATCH).sub(exp, alternatives($1, $2))
      when /^#{EXPRESSION}$/
        bnf
      else
        raise DoesNotParse, "What is '#{bnf}'?"
      end
    end
  end


  class Foo
    extend Rfc5234

    puts bnf_to_ruby('"foo"'), "-"*40
    bnf_to_ruby('%x4242ab')
    puts bnf_to_ruby('"bar" "baz"'), "-"*40
    puts bnf_to_ruby('"foo" "bar"; foo followed by bar'), "-"*40
    puts bnf_to_ruby('("foz" "bar")'), "-"*40
    puts bnf_to_ruby('["foz"] "bar"'), "-"*40
  end


  class Bar < Parser
    extend Rfc5234

    parser :foo, '"foo"' # define a parser method for "foo" called #parse_foo
    parser :bar, "foo"
    parser :baz, "[foo]"
    parser :quux, "foo baz"
    parser :foobaz, "[foo baz]"
    parser :foobar, "foo / bar"
    parser :foobarbaz, "foo / bar / baz"
    parser :foobarbaz, "foo / bar baz" # i have no idea about precedence here
    parser :foobarbaz, "foo bar / baz" # i have no idea about precedence here
    parser :foobarbaz, "(foo bar) / baz"
    parser :foobarbaz, "foo (bar / baz)"
    parser :foobarbaz, "foo (bar / baz )"
    parser :foobarbaz, "foo ( bar / baz)"
    parser :foobarbaz, "foo ( bar / baz )"
    parser :elem, "(elem (foo / bar) elem)"
  #     parser :foobarbaz, "foo (bar | baz)"
  end

end
