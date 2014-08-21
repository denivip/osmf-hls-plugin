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
 * ;0 tecteun
 *
 * ***** END LICENSE BLOCK ***** */
 
 
package org.denivip.osmf.net.httpstreaming.hls
{	
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	import org.osmf.utils.OSMFSettings;
	import tec.Faest.CModule;
	import util.Hex;
	
	import org.denivip.osmf.utility.decrypt.AES;
	import org.osmf.logging.Log;
	import org.osmf.logging.Logger;
	import org.osmf.net.httpstreaming.HTTPStreamingFileHandlerBase;
	
	[Event(name="notifySegmentDuration", type="org.osmf.events.HTTPStreamingFileHandlerEvent")]
	[Event(name="notifyTimeBias", type="org.osmf.events.HTTPStreamingFileHandlerEvent")]	
	

	public class HTTPStreamingMP2TSFileHandler extends HTTPStreamingFileHandlerBase
	{
		private var _syncFound:Boolean;
		private var _pmtPID:uint;
		private var _audioPID:uint;
		private var _videoPID:uint;
		private var _mp3AudioPID:uint;
		private var _audioPES:HTTPStreamingMP2PESAudio;
		private var _videoPES:HTTPStreamingMP2PESVideo;
		private var _mp3audioPES:HTTPStreamingMp3Audio2ToPESAudio;
		private var _cachedOutputBytes:ByteArray;
		private var _seek:Boolean;
		private var _seekTime:Number;
		private var _key:HTTPStreamingM3U8IndexKey = null;
		private var _iv:ByteArray = null;
		private var ivptr:int;
		private var mkey:int;		
		
		// AES-128 specific variables
		private var decoder:HTTPStreamingDecoder;
		public function HTTPStreamingMP2TSFileHandler()
		{
			_audioPES = new HTTPStreamingMP2PESAudio;
			_videoPES = new HTTPStreamingMP2PESVideo;
			_mp3audioPES = new HTTPStreamingMp3Audio2ToPESAudio;
			ivptr = CModule.malloc(16);
			mkey = CModule.malloc(16);
		}
		
		override public function beginProcessFile(seek:Boolean, seekTime:Number):void
		{
			_seek = seek;
			_seekTime = seekTime;
			if(seek){
				initialOffset = Math.floor(seekTime);
			}
			if(_iv && _key){
				_iv.position = 0;
				CModule.writeBytes(ivptr, _iv.length, _iv);
				 _key.key.position = 0;
				CModule.writeBytes(mkey, _key.key.length, _key.key);
				if (decoder) {
					decoder.dispose();
				}
				decoder = new HTTPStreamingDecoder(ivptr,mkey);
			}
			
			_syncFound = false;
		}

		override public function get inputBytesNeeded():Number
		{
			return _syncFound ? 187 : 1;
		}
		
		override public function processFileSegment(input:IDataInput):ByteArray
		{
			if(decoder){
				decoder.input = input;
			}

			while (true) {
				if(!_syncFound)
				{
					if (_key) {
						if (_key.type == "AES-128") {
							if (decoder.bytesAvailable < 1) {
								break;
							}
							if (decoder.readByte() == 0x47) {
								_syncFound = true;
							}
							
							
						}
					} else {
						if(input.bytesAvailable < 1)
							break;
						
						if(input.readByte() == 0x47)
							_syncFound = true;
					}
				}
				else
				{
					var packet:ByteArray = new ByteArray();
					
					if (_key) {
						if (_key.type == "AES-128") {
								if (decoder.bytesAvailable < 187) {
									break;
								}
								decoder.readBytes(packet, 187);
								
							
						}
					} else {
						if(input.bytesAvailable < 187)
							break;
						
						input.readBytes(packet, 0, 187);
					}
					
					_syncFound = false;
					return processPacket(packet);
				}
			}
			return null;
		}
		
		//todo: is not called?
		override public function endProcessFile(input:IDataInput):ByteArray
		{
			decoder.dispose();
			return null;	
		}
		
		public function resetCache():void{
			_cachedOutputBytes = null;
		}
		
		public function set isDiscontunity(isDiscontunity:Boolean):void{
			_videoPES.isDiscontunity = isDiscontunity;
			_audioPES.isDiscontunity = isDiscontunity;
			_mp3audioPES.isDiscontunity = isDiscontunity;
		}
		
		public function set initialOffset(offset:Number):void {
			offset *= 1000; // convert to ms
			
			//give the corrected offset of this chunk (this assumes a 10 s chunk-length);
			offset = (offset - (offset % int(10 * 1000)))
			
			_videoPES.initialTimestamp = offset;
			_audioPES.initialTimestamp = offset;
			_mp3audioPES.initialTimestamp = offset;
		}
		
		public function set key(key:HTTPStreamingM3U8IndexKey):void {
			_key = key;
		}
		
		public function set iv(iv:String):void {
			if (iv) {
				_iv = Hex.toArray(iv);
			}
		}
		
		private function processPacket(packet:ByteArray):ByteArray
		{
			// decode rest of transport stream prefix (after the 0x47 flag byte)
			
			// top of second byte
			var value:uint = packet.readUnsignedByte();
			
			//var tei:Boolean = Boolean(value & 0x80);	// error indicator
			var pusi:Boolean = Boolean(value & 0x40);	// payload unit start indication
			//var tpri:Boolean = Boolean(value & 0x20);	// transport priority indication
			
			// bottom of second byte and all of third
			value <<= 8;
			value += packet.readUnsignedByte();
			
			var pid:uint = value & 0x1fff;	// packet ID
			
			// fourth byte
			value = packet.readUnsignedByte();
			//var scramblingControl:uint = (value >> 6) & 0x03;	// scrambling control bits
			var hasAF:Boolean = Boolean(value & 0x20);	// has adaptation field
			var hasPD:Boolean = Boolean(value & 0x10);	// has payload data
			//var ccount:uint = value & 0x0f;		// continuty count
			
			// technically hasPD without hasAF is an error, see spec
			
			if(hasAF)
			{
				// process adaptation field
				// don't care about flags
				// don't care about clocks here
                //noinspection UnnecessaryLocalVariableJS - code inspection is wrong, this cannot be simplified because packet.position changes
                var af:uint = packet.readUnsignedByte();
				packet.position += af;	// skip to end
			}

            return hasPD ? processES(pid, pusi, packet) : null;
		}
		
		private function processES(pid:uint, pusi:Boolean, packet:ByteArray):ByteArray
		{
			var output:ByteArray = null;
			if(pid == 0)	// PAT
			{
				if(pusi)
					processPAT(packet);
			}
			else if(pid == _pmtPID)
			{
				if(pusi)
					processPMT(packet);
			}
			else if(pid == _audioPID)
			{
				output = _audioPES.processES(pusi, packet);
			}
			else if(pid == _videoPID)
			{
				output = _videoPES.processES(pusi, packet);
			}
			else if(pid == _mp3AudioPID)
			{
				output = _mp3audioPES.processES(pusi, packet);
			}
			
			return output;
		}
		
		private function processPAT(packet:ByteArray):void
		{
			packet.readUnsignedByte();   // pointer:uint
			packet.readUnsignedByte();   // tableID:uint
			var remaining:uint = packet.readUnsignedShort() & 0x03ff; // ignoring misc and reserved bits
			
			packet.position += 5; // skip tsid + version/cni + sec# + last sec#
			remaining -= 5;
			
			while(remaining > 4)
			{
				packet.readUnsignedShort(); // program number
				_pmtPID = packet.readUnsignedShort() & 0x1fff; // 13 bits
				remaining -= 4;
				
				//return; // immediately after reading the first pmt ID, if we don't we get the LAST one
			}
			
			// and ignore the CRC (4 bytes)
		}
		
		private function processPMT(packet:ByteArray):void
		{
			packet.readUnsignedByte();  // pointer:uint
			var tableID:uint = packet.readUnsignedByte();
			
			if (tableID != 0x02)
			{
				CONFIG::LOGGING
				{
					logger.warn("PAT pointed to PMT that isn't PMT");
				}
				return; // don't try to parse it
			}

			var remaining:uint = packet.readUnsignedShort() & 0x03ff; // ignoring section syntax and reserved
			
			packet.position += 7; // skip program num, rserved, version, cni, section num, last section num, reserved, PCR PID
			remaining -= 7;
			
			var piLen:uint = packet.readUnsignedShort() & 0x0fff;
			remaining -= 2;
			
			packet.position += piLen; // skip program info
			remaining -= piLen;
			
			while(remaining > 4)
			{
				var type:uint = packet.readUnsignedByte();
				var pid:uint = packet.readUnsignedShort() & 0x1fff;
				var esiLen:uint = packet.readUnsignedShort() & 0x0fff;
				remaining -= 5;
				
				packet.position += esiLen;
				remaining -= esiLen;
				
				switch(type)
				{
					case 0x1b: // H.264 video
						_videoPID = pid;
						break;
					case 0x0f: // AAC Audio / ADTS
						_audioPID = pid;
						break;
					
					case 0x03: // MP3 Audio  (3 & 4)
					case 0x04:
						_mp3AudioPID = pid;
						break;
					
					default:
						CONFIG::LOGGING
						{
							logger.error("unsupported type "+type.toString(16)+" in PMT");
						}
						break;
				}
			}
			
			// and ignore CRC
		}
		
		override public function flushFileSegment(input:IDataInput):ByteArray
		{
			var flvBytes:ByteArray = new ByteArray();
			var flvBytesVideo:ByteArray = _videoPES.processES(false, null, true);
			var flvBytesAudio:ByteArray = _audioPES.processES(false, null, true);
		
			if(flvBytesVideo)
				flvBytes.readBytes(flvBytesVideo);
			if(flvBytesAudio)
				flvBytes.readBytes(flvBytesAudio);
			
			return flvBytes;
		}
		
		CONFIG::LOGGING
		{
		
			private var logger:Logger = Log.getLogger('org.denivip.osmf.net.httpstreaming.hls.HTTPStreamingMP2TSFileHandler') as Logger;
		}
	}
}
