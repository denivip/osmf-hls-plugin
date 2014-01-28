package org.denivip.osmf.logs
{
	import flash.external.ExternalInterface;

	public class CDNLogger
	{
		public static function getCDNData(type:String, descr:String, value:Number):void{
			ExternalInterface.call("function(){" +
				" _gaq.push([" +
				"'_trackEvent'," +
				" 'HLSPlayer', '" +
				type +
				"', '" +
				descr +
				"', " +
				value +
				"  ]) }");
		}
	}
}