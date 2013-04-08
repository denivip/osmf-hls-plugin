package org.denivip.osmf.net
{
	import org.osmf.net.DynamicStreamingItem;
	
	/**
	 * HLS Stream complex item
	 * Contains stream chunks
	 * Generated from #EXT-X-STREAM-INF tag (if multiquality playlist), or whole playlist (if simple)
	 */
	public class HLSDynamicStreamingItem extends DynamicStreamingItem
	{
		private var _isLive:Boolean;
		public function get isLive():Boolean{ return _isLive; }
		public function set isLive(value:Boolean):void{ _isLive = value; }
		
		private var _chunks:Vector.<HLSMediaChunk>;
		public function get chunks():Vector.<HLSMediaChunk>{ return _chunks; }
		
		public function HLSDynamicStreamingItem(streamName:String,
												bitrate:Number,
												width:int=-1,
												height:int=-1,
												chunks:Vector.<HLSMediaChunk>=null)
		{
			super(streamName, bitrate, width, height);
			_chunks = chunks;
		}
	}
}