package org.denivip.osmf.plugins
{
	import org.osmf.utils.OSMFSettings;

	public class HLSSettings
	{
		public static const NAMESPACE:String = "org.denivip.osmf.hls";
		public static const ALTERNATIVE_VIDEO_METADATA:String = "alternative.video.stream.items";
		
		public static var maxLoadedChunks		:int = 3;//int.MAX_VALUE;
		
		// Buffer control
		public static var hlsBufferSizePause	:Number = 64;
		public static var hlsBufferSizeBig		:Number = 16;
		public static var hlsBufferSizeDef		:Number = OSMFSettings.hdsMinimumBufferTime;
		public static var hlsBufferSizeMin		:Number = 4;
		
		public static var hlsAddBufferSize		:Number = 10;
		
		// reload/load playlist troubles
		public static var hlsMaxReloadRetryes	:int = 5;
		public static var hlsReloadTimeout		:int = 5000;
		
		// HLSIndexHandler
		public static var hlsMaxErrors:int = 10;
		
		public static var headerParamName:String = null;
		public static var headerParamValue:String = null;
	}
}