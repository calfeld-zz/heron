#!/usr/bin/env ruby1.9

# Very basic assertion library.
#
# This library exists to provide basic assertion support for Heron without
# adding another dependency.  If you are looking for an assertion library,
# there are superior alternatives.
#
# Example:
#
#   assert( "x too large ) { x > 1 }
#   assert_throw( "x did not throw" ) { foo() }
#
# Author::    Christopher Alfeld (calfeld@calfeld.net)
# Copyright:: Copyright (c) 2012 Christopher Alfeld

# Throw exception with given message if block evaluates to false.
def assert( message = "Assert Fail" )
  raise message if ! yield
end

# Throw exception with given message if block does not throw an exception.
def assert_throw( message = "Assert Exception Fail" )
  okay = false
  begin
    yield
  rescue
    okay = true
  end
  assert( message ) { okay }
end

