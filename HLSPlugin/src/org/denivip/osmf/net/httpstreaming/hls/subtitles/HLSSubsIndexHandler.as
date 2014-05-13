package org.denivip.osmf.net.httpstreaming.hls.subtitles
{
	import flash.events.Event;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	
	import org.denivip.osmf.net.httpstreaming.hls.HTTPStreamingM3U8IndexItem;
	import org.denivip.osmf.net.httpstreaming.hls.HTTPStreamingM3U8IndexRateItem;
	import org.denivip.osmf.utility.Url;
	import org.osmf.events.HTTPStreamingEvent;
	import org.osmf.events.HTTPStreamingIndexHandlerEvent;
	import org.osmf.events.TimelineMetadataEvent;
	import org.osmf.media.MediaResourceBase;
	import org.osmf.metadata.Metadata;
	import org.osmf.metadata.TimelineMetadata;
	import org.osmf.net.httpstreaming.HTTPStreamRequest;
	import org.osmf.net.httpstreaming.HTTPStreamRequestKind;
	import org.osmf.net.httpstreaming.HTTPStreamingIndexHandlerBase;
	import org.osmf.net.httpstreaming.flv.FLVTagScriptDataMode;
	import org.osmf.net.httpstreaming.flv.FLVTagScriptDataObject;
	
	[Event(name="notifyIndexReady", type="org.osmf.events.HTTPStreamingFileIndexHandlerEvent")]
	[Event(name="notifyRates", type="org.osmf.events.HTTPStreamingFileIndexHandlerEvent")]
	[Event(name="notifyTotalDuration", type="org.osmf.events.HTTPStreamingFileIndexHandlerEvent")]
	[Event(name="requestLoadIndex", type="org.osmf.events.HTTPStreamingFileIndexHandlerEvent")]
	[Event(name="notifyError", type="org.osmf.events.HTTPStreamingFileIndexHandlerEvent")]
	[Event(name="DVRStreamInfo", type="org.osmf.events.DVRStreamInfoEvent")]
	
	public class HLSSubsIndexHandler extends HTTPStreamingIndexHandlerBase
	{
		private var _timeLine:TimelineMetadata;
		private var _indexInfo:Object = null;
		private var _subItems:HTTPStreamingM3U8IndexRateItem = null;
		private var _segment:int;
		private var _absoluteSegment:int;
		
		private var _subs:SubtitlesVO;
		
		public function HLSSubsIndexHandler(res:MediaResourceBase){
			super();
			
			_timeLine = res.getMetadataValue('SUB_TIMELINE') as TimelineMetadata;
			
			_timeLine.addEventListener(TimelineMetadataEvent.MARKER_TIME_REACHED,
				function(e:TimelineMetadataEvent):void{
					var sm:SubtitlesMarker = e.marker as SubtitlesMarker
					trace(sm.text);
				}
			);
		}
		
		override public function initialize(indexInfo:Object):void{
			_indexInfo = indexInfo;
			if( !_indexInfo ){
				dispatchEvent(new HTTPStreamingEvent(HTTPStreamingEvent.INDEX_ERROR));
				return;
			}
			
			//notifyRatesReady();
			
			//dispatchEvent(new HTTPStreamingIndexHandlerEvent(HTTPStreamingIndexHandlerEvent.REQUEST_LOAD_INDEX, false, false, false, NaN, null, null, new URLRequest(indexInfo.url), 0, true));
			var urlLoader:URLLoader = new URLLoader();
			urlLoader.addEventListener(Event.COMPLETE, function(e:Event):void{
				processIndexData(urlLoader.data, {});
			});
			urlLoader.load(new URLRequest(_indexInfo.url));
		}
		
		override public function dispose():void{
			_indexInfo = null;
			_subItems = null;
		}
		
		override public function processIndexData(data:*, indexContext:Object):void{
			data = String(data).replace(/\\\s*[\r?\n]\s*/g, "");
			
			var lines:Vector.<String> = Vector.<String>(String(data).split(/\r?\n/));
			_subItems = new HTTPStreamingM3U8IndexRateItem(0, _indexInfo.url);
			var indexItem:HTTPStreamingM3U8IndexItem;
			var len:int = lines.length;
			var duration:Number = 0;
			
			for(var i:int = 0; i < len; i++){
				if(i == 0){
					if(lines[i] != '#EXTM3U'){
						dispatchEvent(new HTTPStreamingEvent(HTTPStreamingEvent.INDEX_ERROR));
						return;
					}
				}
				
				if (lines[i].indexOf("#") != 0 && lines[i].length > 0) { //non-empty line not starting with # => segment URI
					var url:String = Url.absolute(_subItems.url, lines[i]);
					indexItem = new HTTPStreamingM3U8IndexItem(duration, url, false);
					_subItems.addIndexItem(indexItem);
				}else if(lines[i].indexOf("#EXTINF:") == 0){
					duration = parseFloat(lines[i].match(/([\d\.]+)/)[1]);						
				}else if(lines[i].indexOf("#EXT-X-ENDLIST") == 0){
					_subItems.isLive = false;
				}else if(lines[i].indexOf("#EXT-X-MEDIA-SEQUENCE:") == 0){
					_subItems.sequenceNumber = parseInt(lines[i].match(/(\d+)/)[1]);;
				}else{
					if(lines[i].indexOf("#EXT-X-TARGETDURATION:") == 0){
						_subItems.targetDuration = parseFloat(lines[i].match(/([\d\.]+)/)[1]);
					}
				}
			}
			_subItems.isParsed = true;
			
			_subs = null;
		}
		
		override public function getFileForTime(time:Number, quality:int):HTTPStreamRequest{
			if(_subItems == null)
				return null;
			var manifest:Vector.<HTTPStreamingM3U8IndexItem> = _subItems.manifest;
			if(!manifest.length)
				return new HTTPStreamRequest(HTTPStreamRequestKind.DONE);	// nothing in the manifest...
			
			var len:int = manifest.length;
			var tempItem:HTTPStreamingM3U8IndexItem = manifest[len-1];
			if(time > tempItem.startTime+tempItem.duration)	// is requested time past the last item in the manifest?
				return new HTTPStreamRequest(HTTPStreamRequestKind.DONE);
			
			var i:int;
			for(i = 0; i < len; i++){
				if(time < manifest[i].startTime)
					break;
			}
			if(i > 0) --i;
			
			_segment = i;
			_absoluteSegment = _subItems.sequenceNumber + _segment;
			/*
			if(!_subItems.isLive){
				notifyTotalDuration(_subItems.totalTime, _subItems.isLive);
			}
			*/
			return getNextFile(quality);
		}
		
		override public function getNextFile(quality:int):HTTPStreamRequest{
			var request:HTTPStreamRequest;
			var manifest:Vector.<HTTPStreamingM3U8IndexItem> = _subItems.manifest;
			/*
			if(!_subItems.isLive){
				notifyTotalDuration(_subItems.totalTime, _subItems.isLive);
			}
			*/
			if(_subItems.isLive){
				if(_absoluteSegment == 0 && _segment == 0){ // Initialize live playback
					_absoluteSegment = _subItems.sequenceNumber + _segment;
				}
				
				if(_absoluteSegment != (_subItems.sequenceNumber + _segment)){ // We re-loaded the live manifest, need to re-normalize the list
					_segment = _absoluteSegment - _subItems.sequenceNumber;
					if(_segment < 0)
					{
						_segment=0;
						_absoluteSegment = _subItems.sequenceNumber;
					}
				}
				if(_segment >= manifest.length){ // Try to force a reload
					//dispatchEvent(new HTTPStreamingIndexHandlerEvent(HTTPStreamingIndexHandlerEvent.REQUEST_LOAD_INDEX, false, false, _subItems.isLive, 0, [_indexInfo.name], [0], new URLRequest(_subItems.url), quality, false));
					var urlLoader:URLLoader = new URLLoader();
					urlLoader.addEventListener(Event.COMPLETE, function(e:Event):void{
						processIndexData(urlLoader.data, {});
					});
					urlLoader.load(new URLRequest(_indexInfo.url));
					return new HTTPStreamRequest(HTTPStreamRequestKind.LIVE_STALL, null, 1.0);
				}
			}
			
			if(_segment >= manifest.length){ // if playlist ended, then end =)
				return new HTTPStreamRequest(HTTPStreamRequestKind.DONE);
			}else{ // load new chunk
				var loader:URLLoader = new URLLoader();
				loader.addEventListener(Event.COMPLETE, function(e:Event):void{
					_subs = WebVTTParser.parse(String(loader.data), _subs);
					for each(var sub:SubtitlesItemVO in _subs.items){
						_timeLine.addMarker(new SubtitlesMarker(sub.start, sub.duration, sub.text));
					}
				});
				loader.load(new URLRequest(manifest[_segment].url));
				
				// Increment segments
				++_segment;
				++_absoluteSegment;
			}
			
			return request;
		}
	}
}