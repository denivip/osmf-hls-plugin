package org.denivip.osmf.plugins
{
	import org.osmf.utils.OSMFSettings;

	public class HLSSettings
	{
		public static function applyParams(parameters:Object):void{
			
		}
		
		// Buffer control
		public static var hlsBufferSizePause	:Number = 512;
		public static var hlsBufferSizeBig		:Number = 128;
		public static var hlsBufferSizeDef		:Number = 32;//OSMFSettings.hdsMinimumBufferTime;
		
		// reload/load playlist troubles
		public static var hlsMaxReloadRetryes	:int = 5;
		public static var hlsReloadTimeout		:int = 5000;
		
		// HLSIndexHandler
		public static var hlsMaxErrors:int = 10;
	}
}