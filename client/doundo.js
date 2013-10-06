// Generated by CoffeeScript 1.6.3
(function() {
  var Heron, assert_members, clone,
    __slice = [].slice,
    __hasProp = {}.hasOwnProperty;

  Heron = this.Heron != null ? this.Heron : this.Heron = {};

  assert_members = function() {
    var k, keys, obj, _i, _len, _results;
    obj = arguments[0], keys = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    _results = [];
    for (_i = 0, _len = keys.length; _i < _len; _i++) {
      k = keys[_i];
      if (obj[k] == null) {
        throw "Missing key: " + k;
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  };

  clone = function(obj) {
    var k, r, v;
    r = {};
    for (k in obj) {
      if (!__hasProp.call(obj, k)) continue;
      v = obj[k];
      r[k] = v;
    }
    return r;
  };

  Heron.DoUndo = (function() {
    function DoUndo(config) {
      if (config == null) {
        config = {};
      }
      this._ = {};
      this.reset();
      if ((config.debug != null) && config.debug === true) {
        config.debug = function(event_name, msg) {
          return console.log(event_name, msg);
        };
      }
      this._.debug = config.debug;
      this._.on_do = config.on_do;
      this._.on_undo = config.on_undo;
      this._.on_redo = config.on_redo;
    }

    DoUndo.prototype.did = function(action) {
      var _base, _base1;
      assert_members(action, 'do', 'undo');
      if (this._.current === -1) {
        this._.queue = [];
      } else {
        this._.queue = this._.queue.slice(0, +this._.current + 1 || 9e9);
      }
      action = clone(action);
      if (action.message == null) {
        action.message = "No message";
      }
      this._.queue.push(action);
      this._.current += 1;
      if (this._.current !== this._.queue.length - 1) {
        throw "Insanity: Queue length.";
      }
      if (typeof (_base = this._).on_do === "function") {
        _base.on_do(action);
      }
      if (typeof (_base1 = this._).debug === "function") {
        _base1.debug('do', action.message);
      }
      return this;
    };

    DoUndo.prototype["do"] = function(action) {
      action["do"]();
      this.did(action);
      return this;
    };

    DoUndo.prototype.undo = function() {
      var action, _base, _base1;
      if (!this.can_undo()) {
        throw "Asked to undo, but can't.";
      }
      action = this._.queue[this._.current];
      action.undo();
      this._.current -= 1;
      if (typeof (_base = this._).on_undo === "function") {
        _base.on_undo(action);
      }
      if (typeof (_base1 = this._).debug === "function") {
        _base1.debug('undo', action.message);
      }
      return this;
    };

    DoUndo.prototype.redo = function() {
      var action, _base, _base1;
      if (!this.can_redo()) {
        throw "Asked to redo, but can't.";
      }
      action = this._.queue[this._.current + 1];
      action["do"]();
      this._.current += 1;
      if (typeof (_base = this._).on_redo === "function") {
        _base.on_redo(action);
      }
      if (typeof (_base1 = this._).debug === "function") {
        _base1.debug('redo', action.message);
      }
      return this;
    };

    DoUndo.prototype.reset = function() {
      this._.queue = [];
      this._.current = -1;
      return this;
    };

    DoUndo.prototype.can_undo = function() {
      return this._.current > -1;
    };

    DoUndo.prototype.can_redo = function() {
      return this._.current < this._.queue.length - 1;
    };

    DoUndo.prototype.actions = function() {
      return this._.queue;
    };

    DoUndo.prototype.location = function() {
      return this._.current;
    };

    DoUndo.prototype.action_messages = function() {
      var action, _i, _len, _ref, _results;
      _ref = this._.queue;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        action = _ref[_i];
        _results.push(action.message);
      }
      return _results;
    };

    return DoUndo;

  })();

}).call(this);
