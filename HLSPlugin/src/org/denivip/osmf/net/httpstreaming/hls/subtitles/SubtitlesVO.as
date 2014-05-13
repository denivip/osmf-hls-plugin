package org.denivip.osmf.net.httpstreaming.hls.subtitles {
	
	public class SubtitlesVO {
		
		private var _items:Vector.<SubtitlesItemVO>;
		
		public function SubtitlesVO() {
			_items = new Vector.<SubtitlesItemVO>();
		}
		
		public function addSubtitlesItem(item:SubtitlesItemVO):void {
			_items.push(item);
		}
		
		public function sort():void {
			_items.sort(sortFunc);
		}
		
		public function get items():Vector.<SubtitlesItemVO> { return _items }
		
		private function sortFunc(a:SubtitlesItemVO, b:SubtitlesItemVO):int {
			return a.start < b.start ? -1 : a.start > b.start ? 1 : 0;
		}
		
	}
	
}
