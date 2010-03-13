// ==========================================================================
// Project:   Tp5.ContextAreaView
// Copyright: ©2010 My Company, Inc.
// ==========================================================================
/*globals Tp5 */

/** @class

  (Document Your View Here)

  @extends SC.View
*/
sc_require('views/projector_overlay');
Tp5.ContextAreaView = SC.View.extend(
/** @scope Tp5.ContextAreaView.prototype */ {

	childViews: 'projectorOverlay'.w(),
	
	projectorOverlay: Tp5.ProjectorOverlayView.design({
		layout: {bottom: 0, left:0, right:0, height: 70}
	})

});
