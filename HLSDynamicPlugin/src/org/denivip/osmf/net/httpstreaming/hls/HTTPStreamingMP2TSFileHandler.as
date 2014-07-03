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
	import com.hurlant.crypto.symmetric.NullPad;
	
	import flash.events.Event;
	import flash.sampler.NewObjectSample;
	import flash.system.MessageChannel;
	import flash.system.Worker;
	import flash.system.WorkerDomain;
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	
	import org.osmf.net.httpstreaming.HTTPStreamingFileHandlerBase;
	
	import worker.Messages;
	
	[Event(name="notifySegmentDuration", type="org.osmf.events.HTTPStreamingFileHandlerEvent")]
	[Event(name="notifyTimeBias", type="org.osmf.events.HTTPStreamingFileHandlerEvent")]	
	

	public class HTTPStreamingMP2TSFileHandler extends HTTPStreamingFileHandlerBase
	{
		private var _syncFound:Boolean;
		/*
		private var _pmtPID:uint;
		private var _audioPID:uint;
		private var _videoPID:uint;
		private var _mp3AudioPID:uint;
		private var _audioPES:HTTPStreamingMP2PESAudio;
		private var _videoPES:HTTPStreamingMP2PESVideo;
		private var _mp3audioPES:HTTPStreamingMp3Audio2ToPESAudio;
		
		private var _cachedOutputBytes:ByteArray;
		private var alternatingYieldCounter:int = 0;
		
		private var _key:HTTPStreamingM3U8IndexKey = null;
		private var _iv:ByteArray = null;
		private var _decryptBuffer:ByteArray = new ByteArray;
		
		// AES-128 specific variables
		private var _decryptAES:AES = null;
		*/
		private var _key:HTTPStreamingM3U8IndexKey = null;
		private var _iv:ByteArray = null;
		
		//multithread
		private var streamProcessor:Worker = null;
		private var mtw:MessageChannel;
		private var wtm:MessageChannel;
		private var _processFlag:Boolean = false;
		
		private var _cachedInputBytes:ByteArray;
		private var _cachedOutputBytes:ByteArray;
		
		private var _isDiscontinuity:Boolean = false;
		private var _initialOffset:Number = 0;
		private var _discontinuityPos:ByteArray;
		private var _aesData:ByteArray;
		
		private var _lastPos:uint = 0;
		
		public function HTTPStreamingMP2TSFileHandler()
		{
			createWorker();
		}
		
		private var oldWorker:Worker = null;
		
		private function createWorker():void {
			if (streamProcessor) {
				oldWorker = streamProcessor;
				streamProcessor = null;
				oldWorker.terminate();
				trace("Old worker was terminated");
			}
			
			// init processing thread
			streamProcessor = WorkerDomain.current.createWorker(WorkerManager.worker_StreamProcessor);
			mtw = Worker.current.createMessageChannel(streamProcessor);
			wtm = streamProcessor.createMessageChannel(Worker.current);
			
			streamProcessor.setSharedProperty('mtw', mtw);
			streamProcessor.setSharedProperty('wtm', wtm);
			
			_discontinuityPos = new ByteArray();
			_discontinuityPos.shareable = true;
			streamProcessor.setSharedProperty('discPos', _discontinuityPos);
			
			_aesData = new ByteArray();
			_aesData.shareable = true;
			streamProcessor.setSharedProperty('aesData', _aesData);
			
			_cachedInputBytes = new ByteArray();
			_cachedInputBytes.clear();
			_cachedInputBytes.shareable = true;
			streamProcessor.setSharedProperty('input', _cachedInputBytes);
			
			_cachedOutputBytes = new ByteArray();
			_cachedOutputBytes.clear();
			_cachedOutputBytes.shareable = true;
			streamProcessor.setSharedProperty('output', _cachedOutputBytes);
			
			wtm.addEventListener(Event.CHANNEL_MESSAGE, onWorkerMessage);
			streamProcessor.start();
		}
		
		protected function onWorkerMessage(event:Event):void{
			if(wtm.messageAvailable){
				var msg:String = wtm.receive();
				trace("["+new Date().toLocaleString()+"]<--- "+msg);
				
				if(msg.length>4 && msg.indexOf(Messages.DONE) == 0){
					var lastProc:Number = Number(msg.substr(5));
					trace("["+new Date().toLocaleString()+"] Finished processing:"+lastProc+" of "+_lastPos);
					if (this._lastPos == lastProc) {
						_endOfStream = true;						
					}
				} else if (msg == Messages.NOTDONE){
					_endOfStream = false;
				} else if (msg == Messages.READY) {
					trace("["+new Date().toLocaleString()+"]", _cachedInputBytes.bytesAvailable, _cachedOutputBytes.bytesAvailable);
				}
				
				/*
				if(msg == Messages.SYNC)
					_syncFound = true;*/
			}
		}
		
		override public function get inputBytesNeeded():Number
		{
			return 188;
			//return _syncFound ? 187 : 1;
		}
		
		override public function beginProcessFile(seek:Boolean, seekTime:Number):void
		{
			//trace('---> Messages.BEGIN_PROCESS');
			//mtw.send(Messages.BEGIN_PROCESS);
		}
		
		private var _outputCache:ByteArray = new ByteArray();
		private var _endOfStream:Boolean;
		private var _inputQueue:Array = [];
		override public function processFileSegment(input:IDataInput):ByteArray
		{
			var ba:ByteArray;
			if (input) {
				// Remember the position
				var lp:uint = input.bytesAvailable;
				_lastPos += lp;
				
				// Send input bytes
				trace("package of size",input.bytesAvailable,"put into the queue for position:", _lastPos-lp);
				//input.readBytes(_cachedInputBytes, _cachedInputBytes.length);
				ba = new ByteArray();
				input.readBytes(ba, 0);
				ba.position=0;
				_inputQueue.push(ba);
				
				_endOfStream = false;
				
				// Send discontinuity data
				if(_isDiscontinuity){
					//mtw.send(Messages.DISCONTINUITY);
					_discontinuityPos.writeUnsignedInt(_lastPos-lp);//< Discontinuity position from the beginning
					_discontinuityPos.writeDouble(_initialOffset);//< Discontinuity offset in seconds
					trace('discontinuity position: '+(_lastPos-lp).toString()+" offset: "+_initialOffset);
					isDiscontunity = false;
				}//else
				
				// Send aes data
				if (_shouldSendAES) {
					var tba:ByteArray;
					if (_ckey) {
						tba = new ByteArray();
						tba.writeByte(1);//< 1 for key
						tba.writeUnsignedInt(_lastPos-lp);//< Key position from the beginning
						tba.writeInt(_ckey.key.length);//< Key length
						tba.writeBytes(_ckey.key);//< Key itself
						tba.writeByte(2);//< 2 for key type
						tba.writeUTF(_ckey.type);//< Key type itself
						_aesData.writeInt(tba.length);
						_aesData.writeBytes(tba);
						trace("aes key data sent for position:", _lastPos-lp);
					}
					if (_civ) {
						tba = new ByteArray();
						tba.writeByte(3);//< 3 for IV
						tba.writeUnsignedInt(_lastPos-lp);//< IV position from the beginning
						tba.writeUTF(_civ);//< IV itself
						_aesData.writeInt(tba.length);
						_aesData.writeBytes(tba);
						trace("aes iv data sent for position:", _lastPos-lp);
					}
					_shouldSendAES = false;
					trace("["+new Date().toLocaleString()+"] AES data sent to a worker");
				}
				//trace('main to worker ---> Messages.PROCESS_SEGMENT');
				//mtw.send(Messages.PROCESS_SEGMENT);
			}

			while (_inputQueue.length) {
				if (_cachedInputBytes.length<2*1024*1024) {
					ba = _inputQueue.shift();
					trace("package of size",ba.length,"taken out of the queue");
					ba.readBytes(_cachedInputBytes, _cachedInputBytes.length);
				} else {
					break;
				}
			}
			trace("["+new Date().toLocaleString()+"] "+_cachedInputBytes.length+" bytes waiting for a worker");
			trace("["+new Date().toLocaleString()+"] "+_inputQueue.length+" packets waiting for a cache to be free");
			
			/*if (_restarted) {
				_cachedOutputBytes.clear();
				_restarted = false;
			}*/
			
			_outputCache = new ByteArray();
			// Receive processed bytes
			if (_cachedOutputBytes.bytesAvailable) {
				_cachedOutputBytes.readBytes(_outputCache);
				_cachedOutputBytes.clear();
			}
			
			if (_outputCache.length) {
				trace("["+new Date().toLocaleString()+"] Received processed bytes: "+_outputCache.length);
			}
			return _outputCache.length == 0 ? null : _outputCache;
		}
		
		override public function endProcessFile(input:IDataInput):ByteArray
		{
			//mtw.send(Messages.END_PROCESS);
			return null;	
		}
		
		override public function flushFileSegment(input:IDataInput):ByteArray
		{
			//mtw.send(Messages.FLUSH);
			
			return new ByteArray();
		}
		
		private var _restarted:Boolean = false;
		public function resetCache():void{
			trace("["+new Date().toLocaleString()+"] ======================");
			trace("["+new Date().toLocaleString()+"] RESET command received");
			_lastPos = 0;
			_discontinuityPos.length = 0;
			_isDiscontinuity = false;
			_ckey = null;
			_civ = null;
			_shouldSendAES = false;
			_aesData.clear();
			//mtw.send(Messages.RESET);
			_inputQueue.length = 0;
			_outputCache.clear();
			_cachedInputBytes.clear();
			_cachedOutputBytes.clear();
			createWorker();
			_restarted = true;
		}
		
		public function set isDiscontunity(isDiscontunity:Boolean):void{
			/*_videoPES.isDiscontunity = isDiscontunity;
			_audioPES.isDiscontunity = isDiscontunity;
			_mp3audioPES.isDiscontunity = isDiscontunity;*/
			//mtw.send(Messages.DISCONTINUITY);
			trace("["+new Date().toLocaleString()+"] set discontinuity "+isDiscontunity);
			_isDiscontinuity = isDiscontunity;
		}
		
		public function set initialOffset(offset:Number):void{
			trace("["+new Date().toLocaleString()+"] initial offset: "+offset);
			_initialOffset = offset;
			mtw.send(Messages.OFFSET);
			mtw.send(offset);
		}
		
		private var _ckey:HTTPStreamingM3U8IndexKey = null;
		private var _shouldSendAES:Boolean = false;
		public function set key(key:HTTPStreamingM3U8IndexKey):void {
			//if(key == null) {
				//return;
			//}
			//if (_ckey && _ckey.url == key.url) {
				//return;
			//}
			_ckey = key; 
			_shouldSendAES = true;
			trace("["+new Date().toLocaleString()+"] New AES key received");
			//mtw.send(Messages.KEY);
			//mtw.send(key.type);
			//mtw.send(key.key);
		}
		
		private var _civ:String = null;
		public function set iv(iv:String):void {
			//if (_civ==iv) {
				//return;
			//}
			trace("["+new Date().toLocaleString()+"] New IV received");
			_civ = iv;
			//if (iv) {
				//mtw.send(Messages.IV);
				//mtw.send(iv);
			//}
		}
		
		public function get endOfStream():Boolean{
			if (_endOfStream && (_cachedOutputBytes.length == 0) && (_cachedInputBytes.length == 0)) {
				trace("["+new Date().toLocaleString()+"] True end of HLS stream achieved");								
			}
			
			return _endOfStream && (_cachedOutputBytes.length == 0) && (_cachedInputBytes.length == 0);
		}
		
		CONFIG::LOGGING
		{
			private var logger:Logger = Log.getLogger('org.denivip.osmf.net.httpstreaming.hls.HTTPStreamingMP2TSFileHandler') as Logger;
		}
	}
}
