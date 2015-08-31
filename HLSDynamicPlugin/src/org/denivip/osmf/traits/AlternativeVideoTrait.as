package org.denivip.osmf.traits
{
	import flash.net.NetStreamPlayOptions;
	
	import org.denivip.osmf.events.AlternativeVideoEvent;
	import org.denivip.osmf.net.IAlternativeVideoResource;
	import org.denivip.osmf.net.httpstreaming.hls.HTTPHLSNetStream;
	import org.osmf.media.MediaResourceBase;
	import org.osmf.net.NetClient;
	import org.osmf.net.NetStreamCodes;
	import org.osmf.net.NetStreamUtils;
	import org.osmf.net.StreamingItem;
	import org.osmf.traits.MediaTraitBase;
	import org.osmf.utils.OSMFStrings;
	
	public class AlternativeVideoTrait extends MediaTraitBase
	{
		public static const ALTERNATIVE_VIDEO:String = "alternativeVideo";
		
		public function AlternativeVideoTrait(stream:HTTPHLSNetStream, resource:IAlternativeVideoResource)
		{
			super(ALTERNATIVE_VIDEO);
			
			_numAlternativeVideoStreams = resource.alternativeVideoStreamItems.length;
			_switching = false;
			
			_streamingResource = resource;
			_netStream = stream;
			
			if(_netStream != null && _netStream.client != null)
				NetClient(_netStream.client).addHandler(NetStreamCodes.ON_PLAY_STATUS, onPlayStatus);
		}
		
		override public function dispose():void{
			_netStream = null;
			_streamingResource = null;
		}
		
		public function get numAlternativeVideoStreams():int
		{
			return _numAlternativeVideoStreams;
		}
		
		public function get currentIndex():int
		{
			return _currentIndex;
		}
		
		public function getItemForIndex(index:int):StreamingItem
		{
			if (index <= INVALID_TRANSITION_INDEX || index >= numAlternativeVideoStreams)
			{
				throw new RangeError("Invalid index");
			}
			
			return _streamingResource.alternativeVideoStreamItems[index];
		}
		
		public function get switching():Boolean
		{			
			return _switching;
		}
		
		public function switchTo(index:int):void
		{
			if (index != _indexToSwitchTo)
			{
				if (index < INVALID_TRANSITION_INDEX || index >= numAlternativeVideoStreams)
				{
					throw new RangeError(OSMFStrings.getString("Invalid index"));
				}
				
				// This method sets the switching state to true.  The processing
				// and completion of the switch are up to the implementing media,
				// but once the switch is completed or aborted the implementing
				// media must set the switching mode to false.
				setSwitching(true, index);
			}			
		}
		
		// Internals
		protected final function setCurrentIndex(value:int):void
		{
			_currentIndex = value;
		}
		
		protected final function setSwitching(newSwitching:Boolean, index:int):void
		{
			if (newSwitching != _switching || index != _indexToSwitchTo)
			{
				beginSwitching(newSwitching, index);
				
				// Update the index when a change finishes.
				_switching = newSwitching;
				if (_switching == false)
				{
					setCurrentIndex(index);
				}
				
				endSwitching(index);
			}
		}
		
		protected function beginSwitching(newSwitching:Boolean, index:int):void
		{
			if (newSwitching)
			{
				// Keep track of the target index, we don't want to begin
				// the switch now since our switching state won't be
				// updated until the switchingChangeEnd method is called.
				_indexToSwitchTo = index;
			}
		}
		
		protected function endSwitching(index:int):void
		{
			if(switching){
				executeSwitching(_indexToSwitchTo);
			}
			
			if (!_switching){
				// The switching is now over. Reset the cached value.
				_indexToSwitchTo = INVALID_TRANSITION_INDEX;	
			}
			
			dispatchEvent( new AlternativeVideoEvent( AlternativeVideoEvent.VIDEO_SWITCHING_CHANGE, false, false, switching) );
		}
		
		protected function executeSwitching(indexToSwitchTo:int):void
		{
			if (_lastTransitionIndex != indexToSwitchTo)
			{	
				_activeTransitionIndex = indexToSwitchTo;
				_activeTransitionStreamName = _streamingResource.alternativeVideoStreamItems[_activeTransitionIndex].streamName;
				
				_transitionInProgress = true;
				
				var playArgs:Object = NetStreamUtils.getPlayArgsForResource(MediaResourceBase(_streamingResource));
				
				var nso:NetStreamPlayOptions = new NetStreamPlayOptions();
				nso.start = playArgs.start;
				nso.len = playArgs.len;
				nso.streamName = _activeTransitionStreamName;
				nso.oldStreamName = prepareStreamName(_lastTransitionStreamName);
				nso.transition = 'switch_video';
				_netStream.play2(nso);
			}
		}
		
		private function onPlayStatus(info:Object):void
		{
			switch (info.code)
			{
				case NetStreamCodes.NETSTREAM_PLAY_TRANSITION_COMPLETE:
					//var updatedTransitionStreamName:String = info.details;					
					if (_transitionInProgress && _activeTransitionIndex > INVALID_TRANSITION_INDEX)
					{
						_lastTransitionIndex = _activeTransitionIndex;
						_lastTransitionStreamName = _activeTransitionStreamName;
						
						_transitionInProgress = false;
						_activeTransitionIndex = INVALID_TRANSITION_INDEX;
						_activeTransitionStreamName = null;
						
						setSwitching(false, _lastTransitionIndex);
					}
					break;
			}
		}
		
		private function prepareStreamName(value:String):String
		{
			if (value != null && value.indexOf("?") >= 0)
			{
				return value.substr(0, value.indexOf("?"));
			}
			return value;
		}
		
		/// Internals
		protected static const INVALID_TRANSITION_INDEX:int = -1;
		protected static const DEFAULT_TRANSITION_INDEX:int = 0;
		
		private var _currentIndex:int = DEFAULT_TRANSITION_INDEX;
		private var _numAlternativeVideoStreams:int;
		private var _switching:Boolean;
		
		protected var _indexToSwitchTo:int = INVALID_TRANSITION_INDEX;
		
		private var _netStream:HTTPHLSNetStream = null;
		private var _streamingResource:IAlternativeVideoResource;
		
		private var _transitionInProgress:Boolean = false;
		private var _activeTransitionIndex:int = DEFAULT_TRANSITION_INDEX;
		private var _activeTransitionStreamName:String = null;
		private var _lastTransitionIndex:int = INVALID_TRANSITION_INDEX;
		private var _lastTransitionStreamName:String = null;
		
	}
}