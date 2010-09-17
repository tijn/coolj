require 'English' # from the stdlib
# $&  ->  $MATCH
#    The string matched by the last successful pattern match. This variable is local to the current scope. Read only. Thread local.
# $`  ->  $PREMATCH
#    The string preceding the match in the last successful pattern match. This variable is local to the current scope. Read only. Thread local.
# $'  ->  $POSTMATCH
#    The string following the match in the last successful pattern match. This variable is local to the current scope. Read only. Thread local.

module CoolJ

  class DoesNotParse < StandardError; end

  class Parser
    def initialize(input)
      @input = StringScanner.new(input)
    end

    def parse_literal(literal)
      @input.scan(Regexp.new(Regexp.escape(literal))) or raise DoesNotParse
    end

    def parse_case_insensitive_literal(literal)
      @input.scan(Regexp.new(Regexp.escape(literal), Regexp::IGNORECASE)) or raise DoesNotParse
    end

    def self.parser(name, bnf)
      puts name
      method_name = "parse_#{name}"
      #raise "method already defined #{method_name}" if respond_to? method_name.to_sym
      str = ["def #{method_name}", "  " + bnf_to_ruby(bnf), "end"].join("\n")
      puts '#' + "-"*10, "# #{name} ::= #{bnf}", str, ""
      self.class_eval str
#     rescue
#       raise DoesNotParse, bnf
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


  module Rfc5234
    EXPRESSION = /(\ə\d+)/ # like ə1

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
    GROUPING = /\(#{EXPRESSION}\)/ # (foo bar baz / whatever)
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
      puts "alternatives #{left}, #{right}"
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
        puts "rule name #{$~}"
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
        raise DoesNotParse, "What is #{bnf}??"
      end
    end
  end

#   class Foo
#
#
#     puts bnf_to_ruby('"foo"'), "-"*40
#   #   Rfc5234.parse('%x4242ab')
#     puts bnf_to_ruby('"bar" "baz"'), "-"*40
#     puts bnf_to_ruby('"foo" "bar"; foo followed by bar'), "-"*40
#     puts bnf_to_ruby('("foz" "bar")'), "-"*40
#     puts bnf_to_ruby('["foz"] "bar"'), "-"*40
#   end



  class Foo < Parser
    extend Rfc5234

    parser :foo, '"foo"'
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
  end

end
