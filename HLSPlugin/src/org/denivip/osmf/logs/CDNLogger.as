package org.denivip.osmf.logs
{
	import flash.external.ExternalInterface;

	public class CDNLogger
	{
		private static const TWO_MBPS	:String = "Below 2 Mbps";
		private static const FIVE_MBPS	:String = "2 to 5 Mbps";
		private static const OVER_MBPS	:String = "More then 5 Mbps";
		
		public static function getCDNData(size:Number, time:Number):void{
			time = (time == 0) ? .0001 : time;
			var speed:Number = (size/1024)/(time); // bytes / s
			var speedMbps:Number = speed/1024;
			
			var sSpeed:String;
			
			if(speedMbps > 5.0)
				sSpeed = OVER_MBPS;
			else if(speedMbps > 2.0 && speedMbps < 5.0)
				sSpeed = FIVE_MBPS;
			else
				sSpeed = TWO_MBPS;
			
			var funcS:String = "function(){" +
				" _gaq.push([" +
				"'_trackEvent'," +
				" 'CDN', '" +
				"Download" +
				"', '" +
				sSpeed +
				"', " +
				speed.toFixed(3) + "Kbps" +
				"  ]); }";
			
			try{
				if(ExternalInterface.available)
					ExternalInterface.call(funcS);
			}catch(e:SecurityError){
				trace('shit happens...');
			}
			/*
			trace(funcS);
			trace();
			*/
		}
	}
}