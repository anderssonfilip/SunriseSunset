using Toybox.WatchUi as Ui;

class BaseBehaviorDelegate extends Ui.BehaviorDelegate
{
	var sunriseSunsetView = null; //SunriseSunsetView

	function initialize(view)
	{
		sunriseSunsetView = view;
	}
	
    function onMenu()
    {
    	System.println("onMenu");
    	sunriseSunsetView.reset();
    }
    
    function onNextPage()
    {
    	sunriseSunsetView.showNext();
    }
    
    function onPreviousPage()
    {
    	sunriseSunsetView.showPrevious();
    }
}