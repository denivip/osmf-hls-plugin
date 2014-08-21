package org.denivip.osmf.plugins
{
	public class HLSSettings
	{
		// Buffer control
		public static var hlsBufferSizePause	:Number = 4;
		public static var hlsBufferSizeBig		:Number = 4;
		public static var hlsBufferSizeDef		:Number = 4;//OSMFSettings.hdsMinimumBufferTime;
		
		public static var hlsAddBufferSize		:Number = 2; //overlap 2 chunks
		
		public static var hlsMaxProcessingTime:Number = 17.5;
		
		// reload/load playlist troubles
		public static var hlsMaxReloadRetryes	:int = 5;
		public static var hlsReloadTimeout		:int = 1750; //was 5000
		
		// HLSIndexHandler
		public static var hlsMaxErrors:int = 20;

	}
}