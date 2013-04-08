package org.denivip.osmf.elements.m3u8Classes
{
	/**
	 * Parsed playlist element
	 */
	public class M3U8Playlist extends M3U8Item
	{
		public var sequenceNumber:int;
		
		public var isLive:Boolean = true;
		
		public var streamItems:Vector.<M3U8Item>;
		
		public function M3U8Playlist(duration:Number, url:String){
			super(duration, url);
			
			streamItems = new Vector.<M3U8Item>();
			_startTime = 0;
		}
		
		public function addItem(item:M3U8Item):void{
			item.startTime = _duration;
			_duration += item.duration;
			streamItems.push(item);
		}
	}
}