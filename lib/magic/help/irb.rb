require "irb"
require "irb/extend-command"

# Now let's hack irb not to alias irb_help -> help
# It saves us a silly warning at startup:
#     irb: warn: can't alias help from irb_help.
module IRB::ExtendCommandBundle # :nodoc:
  @ALIASES.delete_if{|a| a == [:help, :irb_help, NO_OVERRIDE]}
end

# help is a Do-What-I-Mean help function.
# It can be called with either a block or a single argument.
# When called with single argument, it behaves like normal
# help function, except for being much smarter:
#
#  help "Array"         - help on Array
#  help "Array#sort"    - help on Array#sort
#  help "File#sync="    - help on IO#sync=
#
#  help { [].sort }     - help on Array#sort
#  help { obj.foo = 1 } - help on obj.foo=
#  help { Array }       - help on Array
#  help { [] }          - help on Array
#  help { Dir["*"] }    - help on Dir::[]
def help(*args, &block)
  query = Magic::Help.resolve_help_query(*args, &block)
  irb_help(query) if query
end
