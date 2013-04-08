package org.denivip.osmf.net
{
	/**
	 * Simple media item for HLS-stream.
	 * Generated from #EXTINF metatag
	 */
	public class HLSMediaChunk
	{
		private var _startTime:Number;
		private var _duration:Number;
		private var _url:String;
		
		public function HLSMediaChunk(
										url:String,
										startTime:Number,
										duration:Number
									 )
		{
			_url = url;
			_startTime = startTime;
			_duration = duration;
		}
		
		public function get url():String{ return _url; }
		public function get duration():Number{ return _duration; }
		public function get startTime():Number{ return _startTime; }
	}
}