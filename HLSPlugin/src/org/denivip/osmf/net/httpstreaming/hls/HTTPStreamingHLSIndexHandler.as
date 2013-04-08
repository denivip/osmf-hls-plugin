/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is the at.matthew.httpstreaming package.
 *
 * The Initial Developer of the Original Code is
 * Matthew Kaufman.
 * Portions created by the Initial Developer are Copyright (C) 2011
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 * ***** END LICENSE BLOCK ***** */
 
 package org.denivip.osmf.net.httpstreaming.hls
{
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	
	import org.denivip.osmf.elements.m3u8Classes.M3U8Item;
	import org.denivip.osmf.elements.m3u8Classes.M3U8Playlist;
	import org.denivip.osmf.elements.m3u8Classes.M3U8PlaylistParser;
	import org.osmf.events.HTTPStreamingEvent;
	import org.osmf.events.HTTPStreamingIndexHandlerEvent;
	import org.osmf.events.MediaError;
	import org.osmf.events.MediaErrorEvent;
	import org.osmf.events.ParseEvent;
	import org.osmf.logging.Log;
	import org.osmf.logging.Logger;
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
	
	/**
	 * 
	 */
	public class HTTPStreamingHLSIndexHandler extends HTTPStreamingIndexHandlerBase
	{
		private static const MAX_ERRORS:int = 2;
		
		private var _indexInfo:HTTPStreamingHLSIndexInfo;
		private var _baseURL:String;
		private var _rateVec:Vector.<HTTPStreamingM3U8IndexRateItem>;
		private var _segment:int;
		private var _absoluteSegment:int;
		private var _quality:int;
		
		private var _streamNames:Array;
		private var _streamQualityRates:Array;
		
		private var _prevPlaylist:String;
		private var _matchCounter:int;
		
		override public function initialize(indexInfo:Object):void{
			_indexInfo = indexInfo as HTTPStreamingHLSIndexInfo;
			if(_indexInfo == null){
				logger.error("Incorrect indexInfo!");
				
				dispatchEvent(new HTTPStreamingEvent(HTTPStreamingEvent.INDEX_ERROR));
				return;
			}
			
			_streamNames = [];
			_streamQualityRates = [];
			_quality = 0;
			
			_rateVec = _indexInfo.streams;
			
			var streamsCount:int = _rateVec.length;
			for(var quality:int = 0; quality < streamsCount; quality++){
				var item:HTTPStreamingM3U8IndexRateItem = _rateVec[quality];
				
				if(item){
					_streamNames[quality] = item.url;
					_streamQualityRates[quality] = item.bw;
				}
			}
			
			notifyRatesReady();
			notifyIndexReady(_quality);
		}
		
		override public function dispose():void{
			_indexInfo = null;
			_rateVec = null;
			
			_streamNames = null;
			_streamQualityRates = null;
		}
		
		/*
			used only in live streaming
		*/
		override public function processIndexData(data:*, indexContext:Object):void{
			// refresh index context
			if(indexContext){
				if(_absoluteSegment > 0){
					HTTPStreamingM3U8IndexRateItem(indexContext).clearManifest();
				}
			}
			
			var ba:ByteArray = ByteArray(data);
			var pl_str:String = ba.readUTFBytes(ba.length);
			if(pl_str.localeCompare(_prevPlaylist) == 0)
				++_matchCounter;
			
			if(_matchCounter == MAX_ERRORS){ // if delivered playlist again not changed then alert!
				var mediaErr:MediaError = new MediaError(0, "Stream is stuck. Playlist on server don't updated!");
				dispatchEvent(new MediaErrorEvent(MediaErrorEvent.MEDIA_ERROR, false, false, mediaErr));
				
				logger.error("Stream is stuck. Playlist on server don't updated!");
			}
			
			_prevPlaylist = pl_str;
				
			// simple parsing && update rate items
			var parser:M3U8PlaylistParser = new M3U8PlaylistParser();
			parser.addEventListener(ParseEvent.PARSE_COMPLETE, onComplete);
			parser.addEventListener(ParseEvent.PARSE_ERROR, onError);
			parser.parse(pl_str, HTTPStreamingM3U8IndexRateItem(indexContext).urlBase);
			
			// service functions
			function onComplete(e:ParseEvent):void{
				parser.removeEventListener(ParseEvent.PARSE_COMPLETE, onComplete);
				parser.removeEventListener(ParseEvent.PARSE_ERROR, onError);
				
				var pl:M3U8Playlist = M3U8Playlist(e.data);
				
				updateRateItem(pl, HTTPStreamingM3U8IndexRateItem(indexContext));
				
				notifyRatesReady();
				notifyIndexReady(_quality);
			}
			
			function onError(e:ParseEvent):void{
				parser.removeEventListener(ParseEvent.PARSE_COMPLETE, onComplete);
				parser.removeEventListener(ParseEvent.PARSE_ERROR, onError);
			}
		}
		
		override public function getFileForTime(time:Number, quality:int):HTTPStreamRequest{
			_quality = quality;
			var item:HTTPStreamingM3U8IndexRateItem = _rateVec[quality];
			var manifest:Vector.<HTTPStreamingM3U8IndexItem> = item.manifest;
			
			var len:int = manifest.length;
			var i:int;
			for(i = 0; i < len; i++){
				if(time < manifest[i].startTime)
					break;
			}
			if(i > 0) --i;
			
			_segment = i;
			_absoluteSegment = item.sequenceNumber + _segment;
			
			return getNextFile(quality);
		}
		
		override public function getNextFile(quality:int):HTTPStreamRequest{
			var item:HTTPStreamingM3U8IndexRateItem = _rateVec[quality];
			var manifest:Vector.<HTTPStreamingM3U8IndexItem> = item.manifest;
			var request:HTTPStreamRequest;
			
			notifyTotalDuration(item.totalTime, quality, item.live);
			
			if(item.live){
				if(_absoluteSegment == 0 && _segment == 0){ // Initialize live playback
					_absoluteSegment = item.sequenceNumber + _segment;
				}
				
				if(_absoluteSegment != (item.sequenceNumber + _segment)){ // We re-loaded the live manifest, need to re-normalize the list
					_segment = _absoluteSegment - item.sequenceNumber;
					if(_segment < 0)
					{
						_segment=0;
						_absoluteSegment = item.sequenceNumber;
					}
					_matchCounter = 0; // reset error counter!
				}
				if(_segment >= manifest.length){ // Try to force a reload
					dispatchEvent(new HTTPStreamingIndexHandlerEvent(HTTPStreamingIndexHandlerEvent.REQUEST_LOAD_INDEX, false, false, item.live, 0, null, null, new URLRequest(_rateVec[quality].url), _rateVec[quality], false));						
					return new HTTPStreamRequest(HTTPStreamRequestKind.LIVE_STALL, null, 1.0);
				} 
			}
			
			if(_segment >= manifest.length)
				return new HTTPStreamRequest(HTTPStreamRequestKind.DONE);
			else{
				request = new HTTPStreamRequest(HTTPStreamRequestKind.DOWNLOAD, manifest[_segment].url);
				
				dispatchEvent(new HTTPStreamingEvent(HTTPStreamingEvent.FRAGMENT_DURATION, false, false, manifest[_segment].duration));
				
				++_segment;
				++_absoluteSegment;
			}
			
			return request;
		}
		
		/*
			Private secton
		*/
		private function notifyRatesReady():void{
			dispatchEvent(
				new HTTPStreamingIndexHandlerEvent(
					HTTPStreamingIndexHandlerEvent.RATES_READY,
					false,
					false,
					false,
					0,
					_streamNames,
					_streamQualityRates
				)
			);
		}
		
		private function notifyIndexReady(quality:int):void{
			var item:HTTPStreamingM3U8IndexRateItem = _rateVec[quality];
			var initialOffset:Number = NaN;
			if(item.live)
				initialOffset = item.totalTime - ((item.totalTime/item.manifest.length) * 3);
			
			dispatchEvent(
				new HTTPStreamingIndexHandlerEvent(
					HTTPStreamingIndexHandlerEvent.INDEX_READY,
					false,
					false,
					item.live,
					initialOffset
				)
			);
		}
		
		private function notifyTotalDuration(duration:Number, quality:int, live:Boolean):void{
			var sdo:FLVTagScriptDataObject = new FLVTagScriptDataObject();
			var metaInfo:Object = new Object();
			if(!live)
				metaInfo.duration = duration;
			else
				metaInfo.duration = 0;
			
			sdo.objects = ["onMetaData", metaInfo];
			dispatchEvent(
				new HTTPStreamingEvent(
					HTTPStreamingEvent.SCRIPT_DATA,
					false,
					false,
					0,
					sdo,
					FLVTagScriptDataMode.IMMEDIATE
				)
			);
		}
		
		private function updateRateItem(playlist:M3U8Playlist, item:HTTPStreamingM3U8IndexRateItem):void{
			// refresh manifest items
			for each(var m3u8Item:M3U8Item in playlist.streamItems){
				var iItem:HTTPStreamingM3U8IndexItem = new HTTPStreamingM3U8IndexItem(m3u8Item.duration, m3u8Item.url);
				item.addIndexItem(iItem);
			}
			
			//item.bw = playlist.bandwidth;
			item.setSequenceNumber(playlist.sequenceNumber);
			item.setLive(playlist.isLive);
		}
		protected var logger:Logger = Log.getLogger("org.denivip.osmf.plugins.hls.HTTPStreamingM3U8IndexHandler");
	}
}
