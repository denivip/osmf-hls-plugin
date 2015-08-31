package org.denivip.osmf.events
{
	import flash.events.Event;
	
	public class AlternativeVideoEvent extends Event
	{
		public static const VIDEO_SWITCHING_CHANGE:String = "videoSwitchingChange1";
		
		private var _switching:Boolean = false;
		
		public function AlternativeVideoEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false, switching:Boolean = false)
		{
			super(type, bubbles, cancelable);
			_switching = switching;
		}
		
		public function get switching():Boolean{ return _switching; }
		
		override public function clone():Event{
			return new AlternativeVideoEvent(type, bubbles, cancelable, switching);
		}
	}
}