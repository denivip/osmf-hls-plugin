package org.denivip.osmf.net
{
	import flash.utils.ByteArray;
	
	import org.denivip.osmf.net.httpstreaming.hls.HLSStreamInfo;
	import org.osmf.net.StreamingItem;
	import org.osmf.net.StreamingURLResource;
	
	public class HLSStreamingResource extends StreamingURLResource implements IAlternativeVideoResource
	{
		public static function createHLSResource(source:StreamingURLResource):HLSStreamingResource{
			return new HLSStreamingResource(source.url,
											source.streamType,
											source.clipStartTime,
											source.clipEndTime,
											source.connectionArguments,
											source.urlIncludesFMSApplicationInstance,
											source.drmContentData);
		}
		
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
		
		public function alternativeVideoStream(name:String, quality:int):Vector.<HLSStreamInfo>{
			return Vector.<HLSStreamInfo>([new HLSStreamInfo(name, 0)]);
		}
		
		private var _alternativeVideoStreamItems:Vector.<StreamingItem> = null;
	}
}