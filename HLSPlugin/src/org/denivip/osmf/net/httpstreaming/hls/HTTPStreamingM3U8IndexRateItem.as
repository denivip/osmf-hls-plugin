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
	
	internal class HTTPStreamingM3U8IndexRateItem
	{
		private var _bw:Number;
		private var _url:String;
		private var _manifest:Vector.<HTTPStreamingM3U8IndexItem>;
		private var _totalTime:Number;
		private var _sequenceNumber:int; // Stores the #EXT-X-MEDIA-SEQUENCE value for the current manifest (needed for live streaming)
		private var _live:Boolean;
		
		public function HTTPStreamingM3U8IndexRateItem(bw:Number = 0, url:String = null, seqNum:int = 0, live:Boolean = true) // Live is true for all streams until we get a #EXT-X-ENDLIST tag
		{
			_bw = bw;
			_url = url;
			_manifest = new Vector.<HTTPStreamingM3U8IndexItem>;
			_totalTime = 0;
			_sequenceNumber = seqNum;
			_live = live;
		}
		
		public function get bw():Number
		{
			return _bw;
		}
		
		public function get url():String
		{
			return _url;
		}
		
		public function get live():Boolean
		{
			return _live;
		}
		
		public function get urlBase():String
		{
			var offset:int;
			offset = _url.lastIndexOf("/");
			return _url.substr(0, offset+1);
		}
		
		public function get totalTime():Number
		{
			return _totalTime;
		}
		
		public function get sequenceNumber():int
		{
			return _sequenceNumber;
		}
		
		public function setSequenceNumber(seqNum:int):void
		{
			_sequenceNumber = seqNum;
		}
		
		public function setLive(live:Boolean):void
		{
			_live = live;
		}
		
		public function addIndexItem(item:HTTPStreamingM3U8IndexItem):void
		{
			item.startTime = _totalTime;
			_totalTime += item.duration;
			_manifest.push(item);
		}
		
		public function clearManifest():void
		{
			_manifest = new Vector.<HTTPStreamingM3U8IndexItem>;
			_totalTime = 0;
		}
		
		public static function sortComparison(item1:HTTPStreamingM3U8IndexRateItem, item2:HTTPStreamingM3U8IndexRateItem):Number
		{
			return item1._bw - item2._bw;
		}
		
		public function get manifest():Vector.<HTTPStreamingM3U8IndexItem>
		{
			return _manifest;
		}
		
	}
}