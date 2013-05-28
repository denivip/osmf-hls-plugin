package org.denivip.osmf.elements.m3u8Classes
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.utils.Dictionary;
	
	import org.denivip.osmf.net.HLSDynamicStreamingItem;
	import org.denivip.osmf.net.HLSDynamicStreamingResource;
	import org.denivip.osmf.net.HLSMediaChunk;
	import org.osmf.events.ParseEvent;
	import org.osmf.logging.Log;
	import org.osmf.logging.Logger;
	import org.osmf.media.MediaResourceBase;
	import org.osmf.media.URLResource;
	import org.osmf.metadata.Metadata;
	import org.osmf.metadata.MetadataNamespaces;
	import org.osmf.net.DynamicStreamingItem;
	import org.osmf.net.StreamType;
	import org.osmf.net.httpstreaming.dvr.DVRInfo;
	import org.osmf.utils.URL;
	
	
	[Event(name="parseComplete", type="org.osmf.events.ParseEvent")]
	[Event(name="parseError", type="org.osmf.events.ParseEvent")]
	
	/**
	 * You will not belive, but this class parses *.m3u8 playlist 
	 */
	public class M3U8PlaylistParser extends EventDispatcher
	{
		private static const LIVE_CHUNK_LIMIT:int = 4;
		
		private var _parsing:Boolean = false;
		private var _playlist:M3U8Playlist;
		
		private var _queue:Array;
		private var _unfinishedLoads:int;
		private var _loadings:Dictionary;
		
		public function M3U8PlaylistParser(){
			// nothing todo here...
		}
		
		public function parse(value:String, rootURL:String=null, playlist:M3U8Playlist=null, internalParse:Boolean=false):void{
			
			if(!value){
				throw new ArgumentError("Parsed value is missing =(");
			}
			
			_parsing = true;
			
			var lines:Array = value.split('\n');

            for(var itq:int = 1; itq < len; itq++)
                    lines[itq] = lines[itq].replace( /^([\s|\t|\n]+)?(.*)([\s|\t|\n]+)?$/gm, "$2" );
			
			if(lines[0] != '#EXTM3U')
				logger.info('Incorrect header! {0}', lines[0]);
			
			if(!playlist){
				playlist = new M3U8Playlist(0, rootURL);
			}
			if(!internalParse){
				_unfinishedLoads = 0;
				_queue = [];
				_playlist = playlist;
			}
			rootURL = URL.normalizePathForURL(rootURL, true);
						
			var len:int = lines.length;
			var url:String;
			for(var i:int = 1; i < len; i++){
				var line:String = lines[i];
				if(line.charAt(line.length-1) == '\r')
					line = line.substr(0, line.length-1);
				var item:M3U8Item = null;
				
				if(line.indexOf('#EXT-X-MEDIA-SEQUENCE') == 0){
					var sequence:int = parseInt(line.substr(22)); //22 is length of "#EXT-X-MEDIA-SEQUENCE:"
					playlist.sequenceNumber = sequence;
					continue;
				}
				
				if(line.indexOf('#EXT-X-ENDLIST') == 0){
					playlist.isLive = false;
					if(_playlist.isLive)
						_playlist.isLive = false; // reset live flag in root playlist (for multi-quality)
					continue;
				}
				
				if(line.indexOf('#EXTINF:') == 0){
					var duration:Number = parseFloat(line.substr(8)); // 8 is length of '#EXTINF:'
					
					++i;
					if(i >= len)
						throw new Error("Unexpected end of file!");
					
					line = lines[i];
					if(line.charAt(line.length-1) == '\r')
						line = line.substr(0, line.length-1);
					
					if(line.toLowerCase().indexOf("http://") == 0 || line.toLowerCase().indexOf("https://") == 0)
					{
						url = line;
					}
					else
					{
						var itUrl:String = line;
						if(itUrl.charAt() == '/')
							itUrl = itUrl.substr(1);
						url = rootURL + itUrl;
					}
					
					item = new M3U8Item(duration, url);
				}
				
				if(line.indexOf('#EXT-X-STREAM-INF:') == 0){
					++i;
					if(i >= len)
						throw new Error("Unexpected end of file!");
					
					line = lines[i]
					if(line.charAt(line.length-1) == '\r')
						line = line.substr(0, line.length-1);
					
					if(line.toLowerCase().indexOf("http://") == 0 || line.toLowerCase().indexOf("https://") == 0)
					{
						url = line;
					}
					else
					{
						url = rootURL + line;
					}
					
					if(url.search(/(https?|file)\:\/\/.*?\.m3u8(\?.*)?/i) !== -1){ // if item is playlist
						_unfinishedLoads++;
						item = new M3U8Playlist(0, url);
						
						var loader:URLLoader = new URLLoader();
						loader.addEventListener(Event.COMPLETE, onLoadComplete);
						loader.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
						loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onLoadError);
						
						loader.load(new URLRequest(url));
						
						if(!_loadings){
							_loadings = new Dictionary(true);
						}
						
						_loadings[loader] = item;
					}else{ // if simple media stream
						item = new M3U8Item(0, url);
					}
					// Parse service params
					var paramsStr:String = String(lines[i-1]).substr(18); // 18 = '#EXT-X-STREAM-INF:'.length
					var params:Array = paramsStr.split(',');
					
					var pLen:int = params.length;
					for(var j:int = 0; j < pLen; j++){
						var par:String = String(params[j]).replace(' ', ''); // remove all spaces
						
						if(par.indexOf('BANDWIDTH=') == 0)
							item.bandwidth = parseInt(par.substr(10))/1000; // 10 = 'BANDWIDTH='.length
						
						if(par.indexOf('RESOLUTION=') == 0)
							item.resolution = par.substr(11); // 11 = 'RESOLUTION='.length
					}
				}
				
				if(item != null)
					playlist.addItem(item);
			}
			
			_parsing = false;
			
			if(_unfinishedLoads == 0)// && processQueue())
				finishParse();
		}
		
		public function createResource(value:M3U8Playlist, originalRes:URLResource):MediaResourceBase{
			var resource:HLSDynamicStreamingResource;
			var url:String;
			
			var manifestURL:URL = new URL(originalRes.url);
			var cleanedPath:String = '/'+manifestURL.path;
			cleanedPath = cleanedPath.substr(0, cleanedPath.lastIndexOf('/'));
			var manifestFolder:String = manifestURL.protocol+'://' +
										manifestURL.host +
										(manifestURL.port != ''? ':' + manifestURL.port : '') +
										cleanedPath;
			
			// create dynamic streaming resource
			var baseURL:String = value.url != null ? value.url : manifestFolder;
			baseURL = URL.normalizeRootURL(baseURL);
			var streamType:String = (value.isLive ? StreamType.LIVE : StreamType.RECORDED);
			if(streamType == StreamType.LIVE && value.dvrInfo != null)
				streamType = StreamType.DVR;
			
			var streamItems:Vector.<DynamicStreamingItem> = new Vector.<DynamicStreamingItem>;
			
			var item:HLSDynamicStreamingItem;
			var chunks:Vector.<HLSMediaChunk>;
			
			for each(var plItem:M3U8Item in value.streamItems){
				if(plItem is M3U8Playlist){
					var pl:M3U8Playlist = (plItem as M3U8Playlist);
					chunks = new Vector.<HLSMediaChunk>();
					for each(var it:M3U8Item in pl.streamItems){
						chunks.push(new HLSMediaChunk(it.url, it.startTime, it.duration));
					}
					item = new HLSDynamicStreamingItem(pl.url, pl.bandwidth, pl.width, pl.height, chunks);
					item.isLive = pl.isLive;
					
					streamItems.push(item);
				}else{
					if(!chunks)
						chunks = new Vector.<HLSMediaChunk>();
					
					chunks.push(new HLSMediaChunk(plItem.url, plItem.startTime, plItem.duration));
				}
			}
			
			if(!(value.streamItems[0] is M3U8Playlist)){
				item = new HLSDynamicStreamingItem(value.url, value.bandwidth, value.width, value.height, chunks);
				item.isLive = value.isLive;
				streamItems.push(item);
			}
			
			resource = new HLSDynamicStreamingResource(baseURL, streamType, streamItems);
			
			resource.addMetadataValue(MetadataNamespaces.DERIVED_RESOURCE_METADATA, originalRes);
			
			var dvrInfo:DVRInfo = value.dvrInfo;
			if(dvrInfo){
				var metadata:Metadata = new Metadata();
				
				metadata.addValue(MetadataNamespaces.HTTP_STREAMING_DVR_BEGIN_OFFSET_KEY, dvrInfo.beginOffset);
				metadata.addValue(MetadataNamespaces.HTTP_STREAMING_DVR_END_OFFSET_KEY, dvrInfo.endOffset);
				metadata.addValue(MetadataNamespaces.HTTP_STREAMING_DVR_WINDOW_DURATION_KEY, dvrInfo.windowDuration);
				metadata.addValue(MetadataNamespaces.HTTP_STREAMING_DVR_OFFLINE_KEY, dvrInfo.offline);
				metadata.addValue(MetadataNamespaces.HTTP_STREAMING_DVR_ID_KEY, dvrInfo.id);
				
				resource.addMetadataValue(MetadataNamespaces.DVR_METADATA, metadata);
			}
			
			return resource;
		}
		
		/*
			Service functions
		*/
		
		private function finishParse():void{
			if(processQueue())
				return;
			
			if(_parsing)
				return;
			
			if(!_playlist)
				return;
			
			// DVR!!!
			addDVRInfo(); // after all we add DVRInfo (if it needed of course)
			
			dispatchEvent(new ParseEvent(ParseEvent.PARSE_COMPLETE, false, false, _playlist));
		}
		
		
		private function onLoadComplete(event:Event):void{
			var loader:URLLoader = event.target as URLLoader;
			
			loader.removeEventListener(Event.COMPLETE, onLoadComplete);
			loader.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
			loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onLoadError);
			
			var data:String = String(loader.data);
			var playlist:M3U8Playlist = _loadings[loader];
			delete _loadings[loader];
			
			_queue.push(
				{data:data, playlist:playlist}
			);
			
			_unfinishedLoads--;
			
			if(_unfinishedLoads == 0)
				processQueue();
		}
		
		private function onLoadError(event:Event):void{
			_unfinishedLoads--;
			dispatchEvent(new ParseEvent(ParseEvent.PARSE_ERROR));
		}
		
		private function processQueue():Boolean{
			if(_parsing)
				return true;
			
			if(_queue.length > 0){
				var res:Object = _queue.pop();
				var data:String = String(res['data']);
				var pl:M3U8Playlist = M3U8Playlist(res['playlist']);
				var url:String = pl.url;
				parse(data, url, pl, true);
				return true;
			}else{
				return false;
			}
		}
		
		private function addDVRInfo():void{
			if(!_playlist.isLive || _playlist.totalLength < LIVE_CHUNK_LIMIT)
				return; // http://fc06.deviantart.net/fs70/f/2011/288/3/c/nothing_to_do_here_by_rober_raik-d4cxltj.png
			
			logger.info('DVR!!! \\o/'); // we happy!
			
			// black magic...
			var dvrInfo:DVRInfo = new DVRInfo();
			dvrInfo.id = dvrInfo.url = _playlist.url;
			dvrInfo.isRecording = true; // if live then in process
			//dvrInfo.startTime = 0.0;
			// attach info into playlist
			_playlist.dvrInfo = dvrInfo;
		}
		
		private var logger:Logger = Log.getLogger("org.denivip.osmf.elements.m3u8Classes.M3U8PlaylistParser");
	}
}