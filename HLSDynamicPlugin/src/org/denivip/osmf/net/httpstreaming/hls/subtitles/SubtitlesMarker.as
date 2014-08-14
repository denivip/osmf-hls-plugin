package org.denivip.osmf.net.httpstreaming.hls.subtitles {
	
	import org.osmf.metadata.TimelineMarker;
	
	public class SubtitlesMarker extends TimelineMarker {
		
		private var _text:String;
		
		public function SubtitlesMarker(time:Number, duration:Number, text:String) {
			super(time, duration);
			_text = text;
		}
		
		public function get text():String { return _text }
		
	}
	
}
