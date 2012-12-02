#!/usr/bin/env ruby1.9

# Copyright 2010-2012 Christopher Alfeld
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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

