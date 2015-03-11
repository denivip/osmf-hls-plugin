package org.denivip.osmf.net
{
	import flash.utils.ByteArray;
	
	import org.osmf.net.StreamingItem;
	import org.osmf.net.StreamingURLResource;
	
	public class HLSStreamingResource extends StreamingURLResource
	{
		public function HLSStreamingResource(url:String
											 , streamType:String = null
											 , clipStartTime:Number = NaN
											 , clipEndTime:Number = NaN
											 , connectionArguments:Vector.<Object> = null
											 , urlIncludesFMSApplicationInstance:Boolean = false
											 , drmContentData:ByteArray = null)
		{
			super(url, streamType, clipStartTime, clipEndTime, connectionArguments, urlIncludesFMSApplicationInstance, drmContentData);
		}
		
		public function get alternativeVideoStreamItems():Vector.<StreamingItem>
		{
			if (_alternativeVideoStreamItems == null)
			{
				_alternativeVideoStreamItems = new Vector.<StreamingItem>();
			}
			return _alternativeVideoStreamItems;
		}
		public function set alternativeVideoStreamItems(value:Vector.<StreamingItem>):void
		{
			_alternativeVideoStreamItems = value;
		}
		
		private var _alternativeVideoStreamItems:Vector.<StreamingItem> = null;
	}
}