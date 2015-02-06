using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Math as Math;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Gregorian;

var session = null;

class SunriseSunsetView extends Ui.View {

    //! Load your resources here
    function onLayout(dc) {
        setLayout(Rez.Layouts.WatchFace(dc));
        	
    }
    
    function onPosition(info)
	{
		Sys.println("Position " + 	info.position.toGeoString(Position.GEO_DEG));
		
		// As represented in seconds since the Epoch, each and every day shall be accounted for by exactly 86400 seconds.
		var jDate = Time.now().subtract(Gregorian.momentNative(1982, 10, 15, 0, 0, 0)).value() / Gregorian.SECONDS_PER_DAY;
		
		System.println(jDate);
		
		// use absolute to get west as positive
		var lonW = info.position.toDegrees()[1].abs().toFloat();
		var latN = info.position.toDegrees()[0].abs().toFloat();
		
		// n = JulianDate - 2451545.0009 - longitudeWest/360 + 0.5
		var n = jDate - 2451545.0009 - (lonW/360) + 0.5;
		
		//System.println(n);

		// Approximate Solar Noon
		var jStar = 2451545.0009 + (lonW/360) + n;

		// Solar Mean Anomaly
		var M = (357.5291 + 0.98560028 * jStar - 2451545).toLong() % 360;
		
		System.println("M " + M.toString());
		
		// Equation of Center
		var C = 1.9418 * Math.sin(M) + 0.02 * Math.sin(2 * M) + 0.0003 * Math.sin(3 * M);
		
		System.println("C " + C.toString());
		
		// Ecliptic Longitude
		var lambda = (M + 102.9372 + C + 180).toLong() % 360;
		
		System.println("Lambda " + lambda.toString());
		
		// Solar transit
		var jTransit = jStar * 0.0053 * Math.sin(M) - 0.0069 * Math.sin(2*lambda);
		
		System.println("jTransit " + jTransit.toString());
		
		// hour angle??
		var dec = 23.45;  // declination of sun
		var w0 = Math.acos((Math.sin(-0.83) - Math.sin(latN) * Math.sin(dec)) / Math.cos(latN) * Math.cos(dec));
		
		var sunset = 2451545.0009 + (w0 + lonW)/360 + n + 0.0053 * Math.sin(M) - 0.0069 * Math.sin(2*lambda);
		
		var sunrise = 2 * jTransit - sunset;
		
		System.println("sunrise " + sunrise.toString());
		System.println("sunset  " + (sunset - jDate).toString());
		
		var m = Gregorian.moment({ "days" => sunset });
		System.println(m.value());
		
		
	}
	
    //! Restore the state of the app and prepare the view to be shown
    function onShow() {
    
    	Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));  
    }
    
    function onHide() {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }

    //! Update the view
    function onUpdate(dc) {
        // Get and show the current time
        var clockTime = Sys.getClockTime();
        
        var timeString = Lang.format("$1$:$2$", [clockTime.hour, clockTime.min.format("%.2d")]);
        var view = View.findDrawableById("TimeLabel");
        view.setText(timeString);

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
    }

    //! The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
    }

    //! Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
    }

}