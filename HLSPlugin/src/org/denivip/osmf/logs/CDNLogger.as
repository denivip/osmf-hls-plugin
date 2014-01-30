package org.denivip.osmf.logs
{
	import flash.external.ExternalInterface;

	public class CDNLogger
	{
		public static function getCDNData(type:String, descr:String, value:Number):void{
			var funcS:String = "function(){" +
				"console.log('" + type + "', '" + descr + "', " + value.toString() + "); " + 
				" _gaq.push([" +
				"'_trackEvent'," +
				" 'HLSPlayer', '" +
				type +
				"', '" +
				descr +
				"', " +
				value +
				"  ]); }";
			ExternalInterface.call(funcS);
		}
	}
}