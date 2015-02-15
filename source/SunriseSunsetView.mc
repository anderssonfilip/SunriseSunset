using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as sys;
using Toybox.Lang as lang;
using Toybox.Math as math;
using Toybox.Time as time;
using Toybox.Time.Gregorian as gregorian;


class SunriseSunsetView extends Ui.View {

	var viewPortHeight = 0;
	var viewPortWidth = 0;
	
	var clockTimer = new Timer.Timer();
	
	var utcOffset = new time.Duration(-sys.getClockTime().timeZoneOffset);
	
	var nextSunPhase = 0; // Julian time of next sun phase (rise OR set)
	var nowShowing = null; // enum: null OR sunrise OR sunset

	var sunTuple = null; // of class SunTuple

	var lonW = 0;
	var latN = 0;
	
	var daysOffset = 0f;

    //! Load your resources here
    function onLayout(dc) 
    {
    	clockTimer.start(method(:clockTimerCallback), 60000 - sys.getTimer() % 60000, false);
    	
    	viewPortHeight = dc.getHeight();
		viewPortWidth  = dc.getWidth();
    	
        setLayout(Rez.Layouts.WatchFace(dc));
    }
    
    function clockTimerCallback()
    {		
		if(evaluateJulianDay().toNumber() != nextSunPhase.toNumber())  
		{
			Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
		}
		
    	Ui.requestUpdate();
    	
    	clockTimer.start(method(:clockTimerCallback), 60000 - sys.getTimer() % 60000, false);
    }
    
    function evaluateJulianDay()
	{
		var timeInfo = gregorian.info(time.now().add(utcOffset), gregorian.FORMAT_SHORT);
		
		var a = (14 - timeInfo.month)/12;
		var y = timeInfo.year + 4800 - a;
		var m = timeInfo.month + 12 * a - 3;
		
		var JDN = timeInfo.day + ((153 * m  + 2) / 5) + 365*y + (y/4).toLong() - (y/100).toLong() + (y/400).toLong() - 32045;
		
		var JD = JDN + (timeInfo.hour - 12)/24.0 + timeInfo.min/1440.0 + timeInfo.sec/(gregorian.SECONDS_PER_DAY*1.0);
	
		//sys.println("Julian day " + JD.toString());
		
		return JD;	
	}
	
	function evaluateSunset(lonW, latN, JD)
	{	
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
	
	function reset()
	{
		Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition)); 
	}
	
	function showNext()
	{	
		if(nowShowing.equals("sunset"))
		{
			daysOffset += 1;
			sunTuple = evaluateSunset(lonW, latN, (evaluateJulianDay() + daysOffset).toNumber());
			drawSunInfo(sunTuple.mSunrise);	
		}
		else // "sunrise"
		{
			daysOffset += 0.5;
			drawSunInfo(sunTuple.mSunset);
		}
				
		Ui.requestUpdate();		
	}
	
	function showPrevious()
	{
		if(nowShowing.equals("sunrise"))
		{
			daysOffset -= 1;
			sunTuple = evaluateSunset(lonW, latN, (evaluateJulianDay() + daysOffset).toNumber());
			drawSunInfo(sunTuple.mSunset);
		}
		else // "sunset
		{
			daysOffset -= 0.5;
			drawSunInfo(sunTuple.mSunrise);
		}

		Ui.requestUpdate();	
	}
    
    function onPosition(info)
	{
		daysOffset = 0f;
		
		sys.println("");
		sys.println("Position " + info.position.toGeoString(Position.GEO_DEG));
		
		// use absolute to get west as positive
		lonW = info.position.toDegrees()[1].abs().toDouble();
		lonW = -14.5d;  // MALTA. TODO: remove
		
		latN = info.position.toDegrees()[0].toDouble();
		latN = 35.8833d;  // MALTA. TODO: remove
				
		var JD = evaluateJulianDay();	
				
		sunTuple = evaluateSunset(lonW, latN, JD);
		
		if(sunTuple.mSunset < JD) // if sunset is passed run calculation again for next day
		{
			sunTuple = evaluateSunset(lonW, latN, JD + 1);
			
			//sys.println("sunrise (+1) " + sunTuple.mSunrise.toString());
			//sys.println("sunset  (+1) " + sunTuple.mSunset.toString());
		}
		else
		{
			//sys.println("sunrise " + sunTuple.mSunrise.toString());
			//sys.println("sunset  " + sunTuple.mSunset.toString());
		}
			
		drawSunInfo(JD, sunTuple);
		
		Ui.requestUpdate();	
	}
	
	function drawSunInfo(JD)
	{
		var view = View.findDrawableById("SunLabel");
		var icon = View.findDrawableById("SunIcon");
		
		var wc = viewPortWidth / 2;
		var hc = viewPortHeight / 2;
	
		var vmargin = viewPortHeight * 0.25;
		var hmargin = 6;
		
		var clock = View.findDrawableById("TimeLabel");
		                	
		view.setLocation(wc + 32 + hmargin, hc + clock.height + vmargin);
		icon.setLocation(wc - 16, hc + clock.height + vmargin - 6);

		if(JD <= sunTuple.mSunrise)
		{
			nextSunPhase = sunTuple.mSunrise;
			
			// convert to hours.minutes
			var sunrise = (sunTuple.mSunrise - sunTuple.mSunrise.toLong()) * 24 - 12 - (utcOffset.value() / gregorian.SECONDS_PER_HOUR);
			
			if(sunrise < 0)  // if jumped to previous day
			{
				sunrise += 24;
			}
			
			// draw as hours:minutes
			view.setColor(Gfx.COLOR_YELLOW);
			var timeString = Lang.format("$1$:$2$", [sunrise.toNumber() % 24, ((sunrise - sunrise.toNumber()) * 60).format("%.2d")]);
			view.setText(timeString);
			
			icon.setBitmap(Rez.Drawables.SunriseIcon);
			nowShowing = "sunrise";
		}
		else
		{
			nextSunPhase = sunTuple.mSunset;
		
			// convert to hours.minutes
			var sunset = (sunTuple.mSunset - sunTuple.mSunset.toLong()) * 24 + 12 - (utcOffset.value() / gregorian.SECONDS_PER_HOUR);
			
			// draw as hours:minutes
			view.setColor(Gfx.COLOR_LT_GRAY);
			var timeString = Lang.format("$1$:$2$", [sunset.toNumber() % 24, ((sunset - sunset.toNumber()) * 60).format("%.2d")]);
			view.setText(timeString);
			
			icon.setBitmap(Rez.Drawables.SunsetIcon);
			nowShowing = "sunset";
		}
	}
	
    //! Restore the state of the app and prepare the view to be shown
    function onShow() 
    {
    	Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));  
    }
    
    function onHide() 
    {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }

    //! Update the view
    function onUpdate(dc) 
    {
    	dc.clear();
    	
        // Get and show the current time
        var clockTime = sys.getClockTime();
        var timeString = Lang.format("$1$:$2$", [clockTime.hour, clockTime.min.format("%.2d")]);
        var view = View.findDrawableById("TimeLabel");
        view.setText(timeString);

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        
        if(nowShowing == null)
        {		
        	dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_BLACK);
			dc.drawText(viewPortWidth/2, viewPortHeight/2 + 40, Gfx.FONT_SMALL, "No Activity", Gfx.TEXT_JUSTIFY_CENTER);
		}
				
		if(daysOffset == 0.5 && nowShowing.equals("sunset"))
		{
			dc.drawText(viewPortWidth/2 - 30, viewPortHeight/2 + 55, Gfx.FONT_XTINY, "+1/2", Gfx.TEXT_JUSTIFY_CENTER);
		}
		else if(daysOffset == -0.5 && nowShowing.equals("sunrise"))
		{
			dc.drawText(viewPortWidth/2 - 30, viewPortHeight/2 + 55, Gfx.FONT_XTINY, "-1/2", Gfx.TEXT_JUSTIFY_CENTER);
		}
		else if(daysOffset >= 1)
		{
			dc.drawText(viewPortWidth/2 - 30, viewPortHeight/2 + 55, Gfx.FONT_XTINY, "+" + daysOffset.toNumber(), Gfx.TEXT_JUSTIFY_CENTER);
		}
		else if(daysOffset <= -1)
		{
			dc.drawText(viewPortWidth/2 - 30, viewPortHeight/2 + 55, Gfx.FONT_XTINY, daysOffset.toNumber().toString(), Gfx.TEXT_JUSTIFY_CENTER);
		}	
    }

    //! The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() 
    {
    	Ui.requestUpdate();
    }

    //! Terminate any active timers and prepare for slow updates.
    function onEnterSleep() 
    {
    
    }
    
    
    //! Covert degrees (°) to radians
	function degToRad(degrees)
	{
		return degrees * math.PI / 180;
	}
	
	//! Perform a modulus on two positive (decimal) numbers, i.e. 'a' mod 'n'
	//! 'a' is divident and 'n' is the divisor
	function modulus(a, n)
	{
		return a - (a / n).toLong() * n;
	}
}