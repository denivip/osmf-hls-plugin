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
		private var streamProcessor:Worker;
		private var mtw:MessageChannel;
		private var wtm:MessageChannel;
		private var _processFlag:Boolean = false;
		
		private var _cachedInputBytes:ByteArray = new ByteArray();
		private var _cachedOutputBytes:ByteArray = new ByteArray();
		
		public function HTTPStreamingMP2TSFileHandler()
		{
			// init processing thread
			streamProcessor = WorkerDomain.current.createWorker(WorkerManager.worker_StreamProcessor);
			mtw = Worker.current.createMessageChannel(streamProcessor);
			wtm = streamProcessor.createMessageChannel(Worker.current);
			
			streamProcessor.setSharedProperty('mtw', mtw);
			streamProcessor.setSharedProperty('wtm', wtm);
			
			wtm.addEventListener(Event.CHANNEL_MESSAGE, onWorkerMessage);
			streamProcessor.start();
			
			_cachedInputBytes.shareable = true;
			_cachedOutputBytes.shareable = true;
			
			streamProcessor.setSharedProperty('input', _cachedInputBytes);
			streamProcessor.setSharedProperty('output', _cachedOutputBytes);
		}
		
		protected function onWorkerMessage(event:Event):void{
			if(wtm.messageAvailable){
				var msg:String = wtm.receive();
				trace('<--- '+msg);
				/*if(msg == Messages.DONE){
					_cachedOutputBytes = wtm.receive();
					_processFlag = false;
				}
				
				if(msg == Messages.SYNC)
					_syncFound = true;*/
			}
		}
		
		override public function get inputBytesNeeded():Number
		{
			return 188;
		}
		
		override public function beginProcessFile(seek:Boolean, seekTime:Number):void
		{
			mtw.send(Messages.BEGIN_PROCESS);
		}
		
		private var _outputCache:ByteArray = new ByteArray();
		
		override public function processFileSegment(input:IDataInput):ByteArray
		{
			_outputCache = new ByteArray();
			input.readBytes(_cachedInputBytes);
			
			mtw.send(Messages.PROCESS_SEGMENT);
			
			_cachedOutputBytes.readBytes(_outputCache, _outputCache.length);
			_cachedOutputBytes.atomicCompareAndSwapLength(_cachedOutputBytes.length, 0);
			
			return _outputCache.length == 0 ? null : _outputCache;
		}
		
		override public function endProcessFile(input:IDataInput):ByteArray
		{
			mtw.send(Messages.END_PROCESS);
			return null;	
		}
		
		override public function flushFileSegment(input:IDataInput):ByteArray
		{
			//mtw.send(Messages.FLUSH);
			
			return new ByteArray();
		}
		
		public function resetCache():void{
			_cachedOutputBytes.length = 0;
			_cachedInputBytes.length = 0;
			
			mtw.send(Messages.RESET);
		}
		
		public function set isDiscontunity(isDiscontunity:Boolean):void{
			/*_videoPES.isDiscontunity = isDiscontunity;
			_audioPES.isDiscontunity = isDiscontunity;
			_mp3audioPES.isDiscontunity = isDiscontunity;*/
		}
		
		public function set initialOffset(offset:Number):void{
			trace('Initial offset: '+offset);
			mtw.send(Messages.OFFSET);
			mtw.send(offset);
		}
		
		public function set key(key:HTTPStreamingM3U8IndexKey):void {
			if(key == null)
				return;
			mtw.send(Messages.KEY);
			mtw.send(key.type);
			mtw.send(key.key);
		}
		
		public function set iv(iv:String):void {
			if (iv) {
				mtw.send(Messages.IV);
				mtw.send(iv);
			}
		}
		
		CONFIG::LOGGING
		{
			private var logger:Logger = Log.getLogger('org.denivip.osmf.net.httpstreaming.hls.HTTPStreamingMP2TSFileHandler') as Logger;
		}
	}
}
