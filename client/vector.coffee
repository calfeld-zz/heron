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

  # Normalize a.
  #
  # a will have length 1 afeter this completes.
  #
  # @param [2-vector] a Vector to normalize.
  # @return [2-vector] a
  @normalize2: ( a ) ->
    n = Heron.Vector.length2( a )
    a[0] /= n
    a[1] /= n
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

