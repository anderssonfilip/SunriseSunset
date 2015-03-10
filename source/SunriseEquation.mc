using Toybox.Math as math;
using Toybox.Time as time;
using Toybox.Time.Gregorian as gregorian;

// http://en.wikipedia.org/wiki/Sunrise_equation
class SunriseEquation{

	function evaluateJulianDay(utcOffset)
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