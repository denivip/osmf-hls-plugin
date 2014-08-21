package org.denivip.osmf.net.httpstreaming.hls
{
	public class HLSStreamInfo
	{
		private var _streamName:String;
		private var _bitrate:Number;
		private var _height:int;
		private var _width:int;
		
		public function HLSStreamInfo(
			streamName:String,
			bitrate:Number,
			width:int = -1,
			height:int = -1
		){
			_width = width;
			_height = height;
			_streamName = streamName;
			_bitrate = bitrate;
		}
		
		public function get streamName():String{ return _streamName; }
		public function get bitrate():Number{ return _bitrate; }
		
		public function get width():int 
		{
			return _width;
		}
		
		public function get height():int 
		{
			return _height;
		}
	}
}