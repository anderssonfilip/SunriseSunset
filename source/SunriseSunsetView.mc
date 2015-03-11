using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as sys;
using Toybox.Lang as lang;
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
	
	var se = new SunriseEquation();

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
		if(se.evaluateJulianDay(utcOffset).toNumber() != nextSunPhase.toNumber())  
		{
			Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
		}
		
    	Ui.requestUpdate();
    	
    	clockTimer.start(method(:clockTimerCallback), 60000 - sys.getTimer() % 60000, false);
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
			sunTuple = se.evaluateSunset(lonW, latN, (se.evaluateJulianDay(utcOffset) + daysOffset).toNumber());
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
			sunTuple = se.evaluateSunset(lonW, latN, (se.evaluateJulianDay(utcOffset) + daysOffset).toNumber());
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
		
		//sys.println("");
		//sys.println("Position " + info.position.toGeoString(Position.GEO_DEG));
		
		// use absolute to get west as positive
		lonW = info.position.toDegrees()[1].abs().toDouble();
		
		latN = info.position.toDegrees()[0].toDouble();
	
		var JD = se.evaluateJulianDay(utcOffset);	
				
		sunTuple = se.evaluateSunset(lonW, latN, JD);
		
		if(sunTuple.mSunset < JD) // if sunset is passed run calculation again for next day
		{
			sunTuple = se.evaluateSunset(lonW, latN, JD + 1);
			
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
		var timeLabel = View.findDrawableById("TimeLabel");
		var sunIcon = View.findDrawableById("SunIcon");
		var sunLabel = View.findDrawableById("SunLabel");
		            
		var locX = viewPortWidth/2 - 64;	
		var locY = viewPortHeight/2 - 76;
		sunIcon.setLocation(locX, locY);
		sunLabel.setLocation(locX + 64, locY);

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
			sunLabel.setColor(Gfx.COLOR_YELLOW);
			var timeString = Lang.format("$1$:$2$", [sunrise.toNumber() % 24, ((sunrise - sunrise.toNumber()) * 60).format("%.2d")]);
			sunLabel.setText(timeString);
			
			sunIcon.setBitmap(Rez.Drawables.SunriseIcon);
			nowShowing = "sunrise";
		}
		else
		{
			nextSunPhase = sunTuple.mSunset;
		
			// convert to hours.minutes
			var sunset = (sunTuple.mSunset - sunTuple.mSunset.toLong()) * 24 + 12 - (utcOffset.value() / gregorian.SECONDS_PER_HOUR);
			
			// draw as hours:minutes
			sunLabel.setColor(Gfx.COLOR_LT_GRAY);
			var timeString = Lang.format("$1$:$2$", [sunset.toNumber() % 24, ((sunset - sunset.toNumber()) * 60).format("%.2d")]);
			sunLabel.setText(timeString);
			
			sunIcon.setBitmap(Rez.Drawables.SunsetIcon);
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
        var timeLabel = View.findDrawableById("TimeLabel");
        var sunLabel = View.findDrawableById("SunLabel");
        timeLabel.setText(timeString);

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        
        if(nowShowing == null)
        {		
        	dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_BLACK);
			dc.drawText(viewPortWidth/2, 
						timeLabel.locX + timeLabel.height, 
						Gfx.FONT_MEDIUM, 
						"No Activity", 
						Gfx.TEXT_JUSTIFY_CENTER);
		}
				
		var d = null;		
		if(daysOffset == 0.5 && nowShowing.equals("sunset"))
		{
			d = "1/2";
		}
		else if(daysOffset == -0.5 && nowShowing.equals("sunrise"))
		{
			d = "-1/2";
		}
		else if(daysOffset >= 1)
		{
			d = "+" + daysOffset.toNumber().toString();
		}
		else if(daysOffset <= -1)
		{
			d = daysOffset.toNumber().toString();
		}	
		
		if(d != null)
		{
			dc.drawText(sunLabel.locX + 50, sunLabel.locY, Gfx.FONT_XTINY, d, Gfx.TEXT_JUSTIFY_CENTER);
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
}