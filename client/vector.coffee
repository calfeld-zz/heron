# Copyright 2012-2014 Christopher Alfeld
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

# Type to use for vectors.
c_vector_type = Float32Array

Heron = @Heron ?= {}

# Collection of vector routines.
#
# All methods end in their dimension.  E.g., vec2 for 2d vectors.
#
# This library is designed to be fast.  This is done in two ways.  First,
# vectors are stored as Float32Arrays.  Second, when possible,
# methods *overwrite* their first argument and also return it.  This allows
# reuse of objects.
#
#     a = vec2(1, 2); b = vec2(3, 4); c = add2(a, b)
#
# `a` will now have value (4, 6) and `c` will refer to the same object as `a`.
#
# If you do not want the first argument to be overwritte, use a dup method.
#
#     a = vec2(1, 2); b = vec2(3, 4); c = add2(dup2(a), b)
#
# `a` will have value (1, 2) and `c` will have value (4, 6).
#
# As a convention, if the first argument is overwritten, it will be `a` and if
# it is not, it will be a different name, e.g., `v`.
#
# @author Christopher Alfeld (calfeld@calfeld.net)
# @copyright 2012 Christopher Alfeld
class Heron.Vector

  # Construct 2-vector.
  #
  # @param [float] x X coordinate.
  # @param [float] y Y coordinate
  # @return [2-vector] Vector of [x,y]
  @vec2: ( x = 0, y = 0 ) ->
    v = new c_vector_type(2)
    v[0] = x
    v[1] = y
    v

  # Duplicate a 2-vector.
  #
  # @param [2-vector] v Vector to duplicate.
  # @return [2-vector] Copy of v.
  @dup2: ( v ) ->
    Heron.Vector.vec2( v[0], v[1] )

  # Are two vectors equal
  #
  # @param [2-vector] v Vector to compare to b.
  # @param [2-vector] b Vector to compare to a.
  # @return true iff a and b represent the same point.
  @equal2: ( v, b ) ->
    v[0] == b[0] && v[1] == b[1]

  # a = (x, y)
  #
  # @param [2-vector] a Vector to set value of.
  # @param [float]    x X coordinate.
  # @param [float]    y Y coordinate.
  # @return [2-vector] a
  @set2: ( a, x, y ) ->
    a[0] = x
    a[1] = y
    a

  # a = a + b
  #
  # @param [2-vector] a Vector to add b to.
  # @param [2-vector] b Vector to add to a.
  # @return [2-vector] a
  @add2: ( a, b ) ->
    a[0] += b[0]
    a[1] += b[1]
    a

  # a = a - b
  #
  # @param [2-vector] a Vector to subtract b from.
  # @param [2-vector] b Vector to subtract from a.
  # @return [2-vector] a
  @sub2: ( a, b ) ->
    a[0] -= b[0]
    a[1] -= b[1]
    a

  # v dot b
  #
  # @param [2-vector] v Vector to dot with b.
  # @param [2-vector] b Vector to dot with v.
  # @return [float] Dot product of v and b.
  @dot2: ( a, b ) ->
    a[0] * b[0] + a[1] * b[1]

  # -a
  #
  # @param [2-vector] a Vector to negate.
  # @return [2-vector] a
  @negate2: ( a ) ->
    a[0] *= -1
    a[1] *= -1
    a

  # Length of v
  #
  # @param [2-vector] v Vector to calculate length of.
  # @return [float] Length of v.
  @length2: ( v ) ->
    Math.sqrt( Heron.Vector.dot2( v, v ) )

  # Scale v by s.
  #
  # @param [2-vector] a Vector to scale.
  # @param [Float]    s Amount to scale by.
  # @return [2-vector] a
  @scale2: ( a, s ) ->
    a[0] *= s
    a[1] *= s
    a

  # Normalize a.
  #
  # a will have length 1 after this completes.
  #
  # @param [2-vector] a Vector to normalize.
  # @return [2-vector] a
  @normalize2: ( a ) ->
    Heron.Vector.scale2( a, 1 / Heron.Vector.length2( a ) )

  # Multiply a by matrix m.
  #
  # @param [2-vector] a Vector to multiply.
  # @param [Array<Array<Float>>] m 2x2 matrix to multiply by.  Array of rows.
  # @return [2-vector] a
  @multiply2: ( a, m ) ->
    t = m[0][0] * a[0] + m[1][0] * a[1]
    a[1] = m[0][1] * a[0] + m[1][1] * a[1]
    a[0] = t
    a

  # Rotate a by radians phi.
  #
  # @param [2-vector] a Vector to rotate.
  # @param [Float] Angle to rotate in radians.
  # @return [2-vector] a
  @rotate2: ( a, phi ) ->
    c = Math.cos( phi )
    s = Math.sin( phi )
    Heron.Vector.multiply2( a, [ [ c, -s ], [ s, c ] ] )
    a

  # String representation of v.
  #
  # @param [2-vector] v Vector to represent.
  # @return [string] (x, y) where v = (x, y)
  @to_s2: ( v ) ->
    "(#{v[0]}, #{v[1]})"

  # Convert a to a vector normal to a.
  #
  # @param [2-vector] a Vector to convert.
  # @return [2-vector] a
  @normal2: ( a ) ->
    t    = a[0]
    a[0] = a[1]
    a[1] = -t
    a

  # Convert a to a vector normal to a, other normal.
  #
  # @param [2-vector] a Vector to convert.
  # @return [2-vector] a
  @normalb2: ( a ) ->
    t    = a[0]
    a[0] = -a[1]
    a[1] = t
    a

  # Find the angle between a and the x-axis.
  #
  # @param [2-vector] a First vector.
  # @return [Float] Angle between a x-axis in radians.
  @angle2: ( a, b ) ->
    if a[0] == 0
      if a[1] < 0
        3 * Math.PI / 2
      else
        # Could be zero vector in which case any answer is okay.
        Math.PI / 2
    else
      subphi = Math.atan( a[1] / a[0] )
      if a[0] < 0
        Math.PI + subphi
      else
        ( subphi + 2 * Math.PI ) % ( 2 * Math.PI )
