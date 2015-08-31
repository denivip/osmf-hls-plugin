package org.denivip.osmf.net
{
	import org.denivip.osmf.net.httpstreaming.hls.HLSStreamInfo;
	import org.osmf.net.DynamicStreamingItem;
	import org.osmf.net.DynamicStreamingResource;
	import org.osmf.net.StreamingItem;
	import org.osmf.net.StreamingItemType;
	
	/**
	 * Simple DynamicStreamingResource, used for correct quality switching
	 */
	public class HLSDynamicStreamingResource extends DynamicStreamingResource implements IAlternativeVideoResource
	{
		public function HLSDynamicStreamingResource(
			url:String,
			streamType:String = null
		)
		{
			super(url, streamType);
		}
		
		override public function indexFromName(name:String):int{
			var index:int = 0;
			
			while(index < streamItems.length){
				if(streamItems[index].streamName == name)
					return index;
				
				index++;
			}
			
			return -1;
		}
		
		public function set qualityLevel(value:int):void{
			_currentQuality = value;
			/*
			var streamName:String = streamItems[_currentQuality].streamName;
			for(var i:int = 0; i < alternativeAudioStreamItems.length; i++){
				var item:StreamingItem = alternativeAudioStreamItems[i];
				if(item.streamName == streamName){
					_currentVideo = i;
					break;
				}
			}
			*/
		}
		
		public function get alternativeVideoStreamItems():Vector.<StreamingItem>
		{
			/*
			if (_alternativeVideoStreamItems == null)
			{
				_alternativeVideoStreamItems = new Vector.<StreamingItem>();
			}
			*/
			return _alternativeVideoStreamItems[_currentQuality];
		}
		public function set alternativeVideoStreamItems(value:Vector.<StreamingItem>):void
		{
			var result:Array = [];
			for(var i:int = 0; i < streamItems.length; i++){
				var hdsi:HLSDynamicStreamingItem = streamItems[i] as HLSDynamicStreamingItem;
				var items:Vector.<StreamingItem> = new Vector.<StreamingItem>();
				result.push(items);
				for(var j:int = 0; j < value.length; j++){
					var sItem:StreamingItem = value[j];
					if(sItem.info.hasOwnProperty('group') &&
						sItem.info.group == hdsi.group){
						items.push(new StreamingItem(StreamingItemType.VIDEO, sItem.streamName, hdsi.bitrate, sItem.info));
					}
				}
			}
			
			_alternativeVideoStreamItems = result;
		}
		
		public function alternativeVideoStream(name:String, quality:int):Vector.<HLSStreamInfo>{
			var videoStream:Vector.<HLSStreamInfo> = new Vector.<HLSStreamInfo>();
			
			var index:int = 0;
			for(; index < alternativeVideoStreamItems.length; index++){
				var it:StreamingItem = alternativeVideoStreamItems[index];
				if(it.streamName == name)
					break;
			}
			
			for(var i:int = 0; i < _alternativeVideoStreamItems.length; i++){
				var sItem:StreamingItem = _alternativeVideoStreamItems[i][index];
				videoStream.push(new HLSStreamInfo(sItem.streamName, sItem.bitrate));
				// update streamName for streamItems
				streamItems[i].streamName = sItem.streamName;
			}
			
			return videoStream;
		}
		
		private var _alternativeVideoStreamItems:Array = null;
		private var _currentQuality:int;
		private var _qualities:Array = [];
	}
}