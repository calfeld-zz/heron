Heron
=====

Library of coffeescript/javascript code.

Very early code.  You probably don't want to use it.

Run rake to fetch external dependencies.

Use coffee to compile, mocha to test, and rake to document.

Documentation
-------------

API documentation is built via `rake doc`.  Client side documentation can be found in `doc/codo/index.html` and server side in `doc/yard/index.html`.

Note: Most private code also has documentation but this is not included in the rake target.  Run codo or yard directly with the appropriate flags, e.g., `--private` for the private documentation.

Overview
--------

* Heron.Util --- Routines, generally simple, used by multiple other components.
* Heron.Comet --- Comet is a name of pushing messages from server to client.  Heron.Comet is an implementation of this based on Ajax (client) and server threads (server).  The server side consists a general component that could be used in any multithreaded ruby web server and a mixin for easy incorporation into Sinatra.
* Heron.Dictionary --- Heron.Dictionary is a persistent and shared key-value store.  It uses Heron.Comet along with its own server-side support.
* Heron.Thingy --- Heron.Thingy builds a simple object oriented framework on top of Heron.Dictionary.
* Heron.Vector --- Simple vector class (currently 2d) oriented at simplicity and speed.  In particular, most operations mutate an operation rather than create a new vector.
