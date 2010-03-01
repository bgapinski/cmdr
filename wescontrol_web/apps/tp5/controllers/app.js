// ==========================================================================
// Project:   Tp5.appController
// Copyright: ©2010 My Company, Inc.
// ==========================================================================
/*globals Tp5 */

/** @class

  (Document Your Controller Here)

  @extends SC.Object
*/
Tp5.appController = SC.ObjectController.create(
/** @scope Tp5.appController.prototype */ {

	init: function() {
		this.clock = "";
		this._timer = SC.Timer.schedule({ 
			target: this, 
			action: 'tick', 
			repeats: YES, 
			interval: 1000
		});
	},
	
	// TODO: Add your own code here.
	now: function() {
		//return new SC.DateTime.create().toFormattedString("%I:%M %p");
		return new Date().format('h:mm') + " PM"; 
	},
	
	tick: function() {
		this.set('clock', this.now());
	}
	
}) ;
