(function() {
  var Websock;

  window.Backbone.sync = function(method, model, success, error) {
    return true;
  };

  Websock = (function() {
    function Websock() {}

    Websock.prototype.connected = false;

    Websock.prototype.connecting = false;

    Websock.prototype.should_reconnect = true;

    Websock.prototype.ever_connected = false;

    Websock.prototype.options = {
      host: "ws://" + window.location.hostname + ":8000/",
      connect_timeout: 1000,
      reconnection_delay: 500,
      max_delay: 15 * 1000
    };

    Websock.prototype.websock_connect = function() {
      var _this = this;
      this.ws = new WebSocket(this.options.host);
      this.ws.onopen = function(event) {
        Tp.log("Connected to WS");
        _this.trigger("connected");
        _this.connected = true;
        return _this.ever_connected = true;
      };
      this.ws.onmessage = function(event) {
        return _this.trigger("message", event.data);
      };
      return this.ws.onclose = function(event) {
        _this.trigger("disconnected");
        return _this.disconnected();
      };
    };

    Websock.prototype.send = function(msg) {
      Tp.log("Sending: %s", msg);
      return this.ws.send(msg);
    };

    Websock.prototype.connect = function() {
      var _this = this;
      Tp.log("Connect!");
      if (!this.connected) {
        if (this.connecting) {
          this.disconnect();
        }
        this.websock_connect();
        return this.connect_timeout_timer = setTimeout((function() {
          if (!_this.connected) {
            Tp.log("Could not connect");
            _this.disconnect;
            _this.trigger("connection_failed");
            return _this.trigger("disconnected");
          }
        }), this.options.connect_timeout);
      }
    };

    Websock.prototype.reconnect = function() {
      var maybe_reconnect, reset,
        _this = this;
      Tp.log("Reconnecting");
      this.reconnecting = true;
      this.reconnection_attempts = 0;
      this.reconnection_delay = this.options.reconnection_delay;
      reset = function() {
        Tp.log("Resetting");
        if (_this.connected) {
          _this.trigger("reconnect", _this.reconnection_events);
        }
        delete _this.reconnecting;
        delete _this.reconnection_attempts;
        delete _this.reconnection_delay;
        return delete _this.reconnection_timer;
      };
      maybe_reconnect = function() {
        var max;
        if (!_this.reconnecting) {
          return;
        }
        if (!_this.connected) {
          if (_this.connecting && _this.reconnecting) {
            return _this.reconnection_timer = setTimeout(maybe_reconnect, 1000);
          }
          _this.reconnection_delay *= 2;
          max = _this.options.max_delay;
          if (_this.reconnection_delay > max || _this.reconnection_delay < 0) {
            _this.reconnection_delay = max;
          }
          _this.connect();
          _this.trigger("reconnecting", [_this.reconnection_delay, _this.reconnection_attempts]);
          Tp.log("Reconnection delay: %d s", _this.reconnection_delay / 1000);
          return _this.reconnection_timer = setTimeout(maybe_reconnect, _this.reconnection_delay);
        } else {
          return reset();
        }
      };
      this.reconnection_timer = setTimeout(maybe_reconnect, this.reconnection_delay);
      return this.bind("connect", maybe_reconnect);
    };

    Websock.prototype.disconnect = function() {
      if (this.connect_timeout_timer) {
        clearTimeout(this.connect_timeout_timer);
      }
      if (this.ws) {
        return this.ws.close();
      }
    };

    Websock.prototype.disconnected = function() {
      this.was_connected = this.connected || !this.ever_connected;
      this.connected = false;
      this.connecting = false;
      if (this.should_reconnect && !this.reconnecting) {
        return this.reconnect();
      }
    };

    return Websock;

  })();

  _.extend(Websock.prototype, Backbone.Events);

  Tp.Websock = Websock;

}).call(this);
