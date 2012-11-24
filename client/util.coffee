
Heron = @Heron ?= {}

# Table that {generate_id} uses.
c_generate_id_table = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

# Miscalaneous Utilities
#
# This file contains routines used by much other Heron code that do simple
# common tasks.
#
# @author Christopher Alfeld (calfeld@calfeld.net)
# @copyright 2012 Christopher Alfeld
class Heron.Util

  # @return [integer] Random number in [0, n)
  @rand = ( n ) ->
    Math.floor( Math.random() * n )

  # @param [integer] n Length of identifier.
  # @return [string] Random string of length n.
  @generate_id = ( n = 8 ) ->
    l = c_generate_id_table.length
    ( c_generate_id_table[ @rand( l ) ] for i in [0..n-1] ).join( '' )

