using Toybox.Application as App;
using Toybox.System as Sys;

class SunriseSunsetApp extends App.AppBase {

    //! onStart() is called on application start up
    function onStart() {
    
    }
    

    //! onStop() is called when your application is exiting
    function onStop() {
    }

    //! Return the initial view of your application here
    function getInitialView() {
    	var view = new SunriseSunsetView();
        return [ view, new BaseBehaviorDelegate(view) ];
    }

}