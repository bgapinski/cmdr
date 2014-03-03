(function() {
  Tp.ActionListView = Backbone.View.extend({
    initialize: function() {
      var _this = this;
      return $.get('../src/script/templates/action_list.html', function(template) {
        $.template("action-list-template", template);
        Tp.server.bind("loaded", _this.render);
        Tp.actions.bind("add", _this.render);
        Tp.actions.bind("change", _this.render);
        return Tp.actions.bind("change:selection", _this.selectionChanged);
      });
    },
    render: function() {
      var actionItemClicked, _ref,
        _this = this;
      $('.action-list').html($.tmpl("action-list-template", (_ref = Tp.actions) != null ? _ref.map(function(action) {
        return {
          id: action.get('id'),
          name: action.get('name'),
          icon: action.icon()
        };
      }) : void 0));
      actionItemClicked = function(event) {
        console.log("Trying to select " + event.currentTarget.id);
        return Tp.actions.select(event.currentTarget.id);
      };
      return window.setTimeout((function() {
        return $('.action-list-item').unbind('click').click(actionItemClicked);
      }), 500);
    },
    selectionChanged: function() {
      var _ref;
      $('.action-list-item').removeClass('selected');
      return $("#" + ((_ref = Tp.actions.selection) != null ? _ref.id : void 0)).addClass('selected');
    }
  });

}).call(this);
