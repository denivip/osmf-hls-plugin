package org.denivip.osmf.net
{
	import org.osmf.net.DynamicStreamingItem;
	
	public class HLSDynamicStreamingItem extends DynamicStreamingItem
	{
		private var _group:String;
		public function HLSDynamicStreamingItem(streamName:String, bitrate:Number, group:String='', width:int=-1, height:int=-1)
		{
			super(streamName, bitrate, width, height);
			_group = group;
		}
		
		public function get group():String{ return _group; }
	}
}