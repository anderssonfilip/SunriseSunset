using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as sys;
using Toybox.Lang as lang;
using Toybox.Math as math;
using Toybox.Time as time;
using Toybox.Time.Gregorian as gregorian;


class SunriseSunsetView extends Ui.View {

	var _dc = null;

    //! Load your resources here
    function onLayout(dc) {
    	_dc = dc;
        setLayout(Rez.Layouts.WatchFace(dc));
    }
    
    function onPosition(info)
	{
		sys.println("");
		sys.println("Position " + info.position.toGeoString(Position.GEO_DEG));
		
		var utcOffset = new time.Duration(-sys.getClockTime().timeZoneOffset);
		var timeInfo = gregorian.info(time.now().add(utcOffset), gregorian.FORMAT_SHORT);
		
		var a = (14 - timeInfo.month)/12;
		var y = timeInfo.year + 4800 - a;
		var m = timeInfo.month + 12 * a - 3;
		
		var JDN = timeInfo.day + ((153 * m  + 2) / 5) + 365*y + (y/4).toLong() - (y/100).toLong() + (y/400).toLong() - 32045;
		
		var JD = JDN + (timeInfo.hour - 12)/24.0 + timeInfo.min/1440.0 + timeInfo.sec/(gregorian.SECONDS_PER_DAY*1.0);
			
		sys.println("Julian day " + JD.toString());
		
		// use absolute to get west as positive
		var lonW = info.position.toDegrees()[1].abs().toDouble();
		lonW = -14.5d;
		
		var latN = info.position.toDegrees()[0].toDouble();
		latN = 35.8833d;
				
		var sunTuple = evaluateSunset(lonW, latN, JD);
		
		if(sunTuple.mSunset < JD) // if sunset is passed run calculation again for next day
		{
			sunTuple = evaluateSunset(lonW, latN, JD+1);
			
			sys.println("sunrise (+1) " + sunTuple.mSunrise.toString());
			sys.println("sunset  (+1) " + sunTuple.mSunset.toString());
		}
		else
		{
			sys.println("sunrise " + sunTuple.mSunrise.toString());
			sys.println("sunset  " + sunTuple.mSunset.toString());
		}
		
		// convert to hour:minutes
		var sunrise = (sunTuple.mSunrise - sunTuple.mSunrise.toLong()) * 24 - 12 - (utcOffset.value() / gregorian.SECONDS_PER_HOUR);
		sys.println("sunrise " + sunrise.toLong().toString() + ":" + ((sunrise - sunrise.toLong()) * 60).toLong().toString());
		
		var sunset = (sunTuple.mSunset - sunTuple.mSunset.toLong()) * 24 + 12 - (utcOffset.value() / gregorian.SECONDS_PER_HOUR);
		sys.println("sunset  " + sunset.toLong().toString() + ":" + ((sunset - sunset.toLong()) * 60).toLong().toString());
		
		var view = View.findDrawableById("SunLabel");
		var icon = View.findDrawableById("SunIcon");
		
		var hc = _dc.getHeight() / 2;
		var wc = _dc.getWidth() / 2;
		
		view.setLocation(1.42 * wc, 1.5 * hc);
		icon.setLocation(0.85 * wc, 1.4 * hc);

		if(JD <= sunTuple.mSunrise)
		{
			view.setColor(Gfx.COLOR_YELLOW);
			view.setText(sunrise.toLong().toString() + ":" + ((sunrise - sunrise.toLong()) * 60).toLong().toString());
			
			icon.setBitmap(Rez.Drawables.SunriseIcon);
		}
		else
		{
			view.setColor(Gfx.COLOR_LT_GRAY);
			view.setText(sunset.toLong().toString() + ":" + ((sunset - sunset.toLong()) * 60).toLong().toString());
			
			icon.setBitmap(Rez.Drawables.SunsetIcon);
		}
		
		View.onUpdate(_dc);	
	}
	
	function evaluateSunset(lonW, latN, JD)
	{	
		//var today = time.today();
		//var now = time.now();
		//var hour = (now.subtract(today).value() / gregorian.SECONDS_PER_HOUR).toLong();
		//var minutes = ((now.subtract(today).value() % gregorian.SECONDS_PER_HOUR) / gregorian.SECONDS_PER_MINUTE).toLong();
		//var seconds = ((now.subtract(today).value() % gregorian.SECONDS_PER_HOUR) % gregorian.SECONDS_PER_MINUTE).toLong();
		
		// n = JulianDate - 2451545.0009 - longitudeWest/360 + 0.5
		var n = (JD - 2451545.0009d - (lonW/360) + 0.50).toLong();
		
		// Approximate Solar Noon
		var jStar = 2451545.0009d + (lonW/360) + n;
		
		//sys.println("Solar Noon " + jStar.toString());

		// Solar Mean Anomaly
		// is there a built in round() function
		var mPrim = 0;
		if((357.5291d + 0.98560028 * (jStar - 2451545)) - 
		   (357.5291d + 0.98560028 * (jStar - 2451545)).toLong() >= 0.5)
		{
			mPrim = 1;
		}
		var M = (mPrim + 357.5291d + 0.98560028 * (jStar - 2451545)).toLong() % 360;
		
		//sys.println("M " + M.toString());
		
		// Equation of Center
		var C = 1.9418d * math.sin(degToRad(M)) + 0.02 * math.sin(degToRad(2 * M)) + 0.0003 * math.sin(degToRad(3 * M));
		
		//sys.println("C " + C.toString());
		
		// Ecliptic Longitude
		// is there a built in round() function
		var lPrim = 0;
		if((M + 102.9372d + C + 180) - 
		   (M + 102.9372d + C + 180).toLong() >= 0.5)
		{
			lPrim = 1;
		}
		var lambda = modulus(lPrim + M + 102.9372d + C + 180, 360);
		
		//sys.println("Lambda " + lambda.toString());
		
		// Solar transit
		var jTransit = jStar + 0.0053 * math.sin(degToRad(M)) - 0.0069 * math.sin(degToRad(2*lambda));
		
		//sys.println("jTransit " + jTransit.toString());
		
		var dec = math.sin(degToRad(lambda)) * math.sin(degToRad(23.45d));
	
		//sys.println("sun declination " + dec.toString());

		var w0 = math.acos((math.sin(degToRad(-0.83)) - math.sin(degToRad(latN)) * dec) / (math.cos(degToRad(latN)) * math.cos(math.asin(dec))));
		
		//sys.println("hour angle " + w0.toString());
		
		var sunset = 2451545.0009d + (degToRad(lonW) + w0)/(2d*math.PI) + n + (0.0053 * math.sin(degToRad(M))) - (0.0069 * math.sin(degToRad(2*lambda)));
		var sunrise = jTransit - (sunset - jTransit);
		
		return new SunTuple(sunrise, sunset);
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
        var clockTime = sys.getClockTime();
        
        var timeString = Lang.format("$1$:$2$", [clockTime.hour, clockTime.min.format("%.2d")]);
        var view = View.findDrawableById("TimeLabel");
        view.setLocation(view.locX, view.locY-5);
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
    
    
    //! Covert degrees (°) to radians
	function degToRad(degrees){
		return degrees * math.PI / 180;
	}
	
	//! Perform a modulus on two positive (decimal) numbers, i.e. 'a' mod 'n'
	//! 'a' is divident and 'n' is the divisor
	function modulus(a, n){
		return a - (a / n).toLong() * n;
	}

}