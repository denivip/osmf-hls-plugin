package org.denivip.osmf.net.httpstreaming.hls.subtitles {
	
	public class SubtitlesItemVO {
		
		private var _start:Number;
		private var _duration:Number;
		private var _text:String;
		
		public function SubtitlesItemVO(start:Number, duration:Number, text:String) {
			_start = start;
			_duration = duration;
			_text = text;
		}
		
		public function get start():Number { return _start }
		public function get duration():Number { return _duration }
		public function get text():String { return _text }
		
	}
	
}
