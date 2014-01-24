package org.denivip.osmf.logs
{
	import flash.external.ExternalInterface;

	public class CDNLogger
	{
		public function CDNLogger()
		{
		}
		
		public static function getCDNData(msg:String, ...rest):void{
			ExternalInterface.call('log',msg);
		}
	}
}