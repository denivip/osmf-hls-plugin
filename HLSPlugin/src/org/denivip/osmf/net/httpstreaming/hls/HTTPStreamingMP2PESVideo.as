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
 * Tecteun
 *
 * ***** END LICENSE BLOCK ***** */
 
package org.denivip.osmf.net.httpstreaming.hls
{
	import flash.utils.ByteArray;
	
	import org.osmf.logging.Log;
	import org.osmf.logging.Logger;
	import org.osmf.net.httpstreaming.flv.FLVTagVideo;

	internal class HTTPStreamingMP2PESVideo extends HTTPStreamingMP2PESBase
	{
		private var _nalData:ByteArray;
		private var _scState:int;
		
		//Store AVCC-nal out of band
		private var spsNALs:Vector.<HTTPStreamingH264NALU> = new Vector.<HTTPStreamingH264NALU>;
		private var ppsNALs:Vector.<HTTPStreamingH264NALU> = new Vector.<HTTPStreamingH264NALU>;
		private var _avccTag:FLVTagVideo;
		private var _vTag:FLVTagVideo;
		private var _vTagData:ByteArray;
		
		//Return buffer
		private var dataReturnTag:ByteArray;
		
		public function HTTPStreamingMP2PESVideo()
		{
			_scState = 0;
			_nalData = new ByteArray();
		}
		
		override public function processES(pusi:Boolean, packet:ByteArray, flush:Boolean = false): ByteArray
		{
			dataReturnTag = new ByteArray();
			var i:int, l:int;
			if(pusi)
			{
				// start of a new PES packet
				var startCode:uint =  packet.readUnsignedInt();
				if(startCode != 0x1e0 && startCode != 0x1ea && startCode != 0x1bd)
				{
					throw new Error("PES start code not found or not AAC/AVC");
				}
				// Ignore packet length and marker bits.
				packet.position += 3;
				// Need PTS and DTS
				var flags:uint = (packet.readUnsignedByte() & 0xc0) >> 6;
				CONFIG::LOGGING
				{
					if(flags != 0x03) {
						//Why don't we have a DTS?
						//logger.warn("video PES packet without DTS");
					}
				}
				
				if(flags != 0x03 && flags != 0x02 && flags != 0x00)
				{
					throw new Error("video PES packet without PTS cannot be decoded");
				}
				// Check PES header length
				var length:uint = packet.readUnsignedByte();
				var pts:Number =
					uint((packet.readUnsignedByte() & 0x0e) << 29) +
					uint((packet.readUnsignedShort() & 0xfffe) << 14) +
					uint((packet.readUnsignedShort() & 0xfffe) >> 1);
				
				length -= 5;
				
				var timestamp:Number;
				if(flags == 0x03)
				{
					var dts:Number = 
						uint((packet.readUnsignedByte() & 0x0e) << 29) + 
						uint((packet.readUnsignedShort() & 0xfffe) << 14) + 
						uint((packet.readUnsignedShort() & 0xfffe) >> 1);
						
					timestamp = Math.round(dts/90);
					_compositionTime =  Math.round(pts/90) - timestamp;
					length -= 5;
				}
				else
				{
					timestamp = Math.round(pts/90);
					_compositionTime = 0;
				}
				
				if(!_timestampReseted) {
					_offset += timestamp - _prevTimestamp;
				}

				if (_isDiscontunity || (!_streamOffsetSet)) {// && _prevTimestamp == 0)) { -- in most cases _prevTimestamp (like any timestamps in stream) can't be 0.
					/*if(timestamp > 0) {
						_offset += timestamp;
					}*/
					_timestamp = _initialTimestamp;
					_streamOffsetSet = true;
				}else{
					_timestamp = _initialTimestamp + _offset;
				}
				
				_prevTimestamp = timestamp;
				_timestampReseted = false;
				_isDiscontunity = false;
				
				// Skip other header data.
				packet.position += length;
			}
			
			if(!flush)
				var dStart:uint = packet.position;	// assume that the copy will be from start-of-data

			var nal:HTTPStreamingH264NALU;
			if(flush)
			{
				nal = new HTTPStreamingH264NALU(_nalData); // full length to end, don't need to trim last 3 bytes
				if(nal.NALtype != 0)
				{
					handleNal(nal);
					CONFIG::LOGGING
					{
						logger.info("pushed one flush nal of type "+nal.NALtype.toString());
					}
				}
				_nalData = new ByteArray();
			}
			else while(packet.bytesAvailable > 0)
			{
				var value:uint = packet.readUnsignedByte();
				
				// finding only 3-byte start codes is ok as trailing zeros are ignored in most (all?) cases
				if (_scState == 0) {
					
					if(value == 0x00)
						_scState = 1;
						
				} else if (_scState == 1) {
					
					if(value == 0x00)
						_scState = 2;
					else
						_scState = 0;
						
				} else if (_scState == 2) {
					
					if(value == 0x00)	// more than 2 zeros... no problem
					{
						// state stays at 2
					}
					else if(value == 0x01)
					{
						// perf
						_nalData.writeBytes(packet, dStart, packet.position-dStart);
						dStart = packet.position;
						// at this point we have the NAL data plus the *next* start code in _nalData
						// unless there was no previous NAL in which case _nalData is either empty or has the leading zeros, if any
						if(_nalData.length > 4) // require >1 byte of payload
						{
							_nalData.length -= 3; // trim off the 0 0 1 (might be one more zero, but in H.264 that's ok)
							nal = new HTTPStreamingH264NALU(_nalData);
							if(nal.NALtype != 0)
							{
								handleNal(nal);
							}
						}
						else
						{
							CONFIG::LOGGING
							{
								logger.warn("length too short! = " + _nalData.length.toString());
							}
						}
						_nalData = new ByteArray(); // and start collecting into the next one
						_scState = 0; // got one, now go back to looking							
					}
					else
					{
						_scState = 0; // go back to looking
						
					}
				}else {
					// shouldn't ever get here
					_scState = 0;
				}				
			} // while bytesAvailable
			
			if(!flush && packet.position-dStart > 0)
				_nalData.writeBytes(packet, dStart, packet.position-dStart);
			
			if(flush)
			{
				;
				CONFIG::LOGGING
				{
					logger.info(" *** VIDEO FLUSH CALLED");
				}
				if (_vTag && _vTagData.length > 0) {
					writeReturnTag(_vTag);
				}
				if (_avccTag) {
					_avccTag = null;
				}
			}
			
			return dataReturnTag;
		}
		
		[Inline]
		private function writeReturnTag(tag:FLVTagVideo):void {
			if(tag){
				FLVTagVideo(tag).write(dataReturnTag);
			}
		}	
		
		/**
		 * handling the Nalu
		 * http://gentlelogic.blogspot.nl/2011/11/exploring-h264-part-2-h264-bitstream.html
		 * @param	nal
		 */
		[Inline]
		private function handleNal(nal:HTTPStreamingH264NALU):void 
		{
			//trace(_timestamp +  " " + nal.NALtype);
			if(nal.NALtype == 7)
			{
				spsNALs.push(nal);
			}
			else if (nal.NALtype == 8)
			{
				ppsNALs.push(nal);				
			}
			else 
			{
				var tag:FLVTagVideo = handleAvccTag(_timestamp);
				if (tag) {
					_avccTag = tag;
				}
			}
			
			if(nal.NALtype == 9)	// AUD -  should read the flags in here too, perhaps
			{
				//var _vTag:FLVTagVideo = new FLVTagVideo();
				//_vTag.codecID = FLVTagVideo.CODEC_ID_AVC;
				//_vTag.avcPacketType = FLVTagVideo.AVC_PACKET_TYPE_END_OF_SEQUENCE;
				//writeReturnTag(_vTag);
				if(_vTag && _vTagData.length > 0)
				{
					//handle Avcc before keyframe
					if(_avccTag)
					{
						writeReturnTag(_avccTag);
						_avccTag = null;
					}
					_vTag.data = _vTagData; // set at end (see below)
					writeReturnTag(_vTag);
				}
				
				//AUD: create a new vTag with this timestamp!
				genVtag();
			}
			else if(nal.NALtype != 7 && nal.NALtype != 8) // no spsNal / ppsNal
			{
				if(_vTag == null)
				{
					CONFIG::LOGGING
					{
						logger.info("needed to create vtag");
					}
					//Should not get here.
					genVtag();
				}
			/*
				if (nal.NALtype == 1 ) {
					//trace("b-slice");					
				}
				if (nal.NALtype == 6 ) {
					//trace("SEI ->  " + _timestamp);
					//_vTag.frameType = FLVTagVideo.FRAME_TYPE_INFO;
				}
			*/	
				if(nal.NALtype == 5) // if keyframe
				{
					_vTag.frameType = FLVTagVideo.FRAME_TYPE_KEYFRAME;
				}
				
				_vTagData.writeUnsignedInt(nal.length);
				_vTagData.writeBytes(nal.NALdata);
				
				//will write this _vTag + _vTagData in AUD
			}
			
		}
		
		[Inline]
		private function handleAvccTag(timestamp:uint):FLVTagVideo {
			var avccTag:FLVTagVideo = null;
			
			// note that this breaks if the sps and pps are in different segments that we process
			if(spsNALs.length > 0 && ppsNALs.length > 0)
			{
				var avcc:ByteArray = new ByteArray();
				avccTag = new FLVTagVideo();
				
				//timestamp seems not important for AVCDecoderConfigurationRecord
				avccTag.timestamp = timestamp;
				avccTag.codecID = FLVTagVideo.CODEC_ID_AVC;
				avccTag.frameType = FLVTagVideo.FRAME_TYPE_KEYFRAME;
				avccTag.avcPacketType = FLVTagVideo.AVC_PACKET_TYPE_SEQUENCE_HEADER;
				
				avcc.writeByte(0x01); // avcC version 1
				// profile, compatibility, level
				avcc.writeBytes(spsNALs[0].NALdata, 1, 3);
				
				//avcc.writeByte(0x3); //Adobe does not set reserved bytes -> 
				avcc.writeByte(0xff); // 111111 + 2 bit NAL size - 1
				
				//write sps'ses
				//padded 3 bits 111 +
				//avcc.writeByte(spsNALs.length); //Adobe does not set reserved bytes -> 
				avcc.writeByte(parseInt("0xE" + spsNALs.length, 16)); // number of SPS
				while (spsNALs.length > 0) {
					var spsNAL:HTTPStreamingH264NALU = spsNALs.shift();
					var spsLength:Number = spsNAL.length;
					/*
						spsNAL.NALdata.position = 1;
						trace("profile " + spsNAL.NALdata.readUnsignedByte());
						spsNAL.NALdata.position++;
						trace("level_idc " + spsNAL.NALdata.readUnsignedByte());
					*/
					avcc.writeByte(spsLength >> 8); // 16-bit SPS byte count
					avcc.writeByte(spsLength);
					avcc.writeBytes(spsNAL.NALdata, 0, spsLength); // the SPS
				}

				//write pps'ses
				avcc.writeByte(ppsNALs.length); // number of PPS
				while (ppsNALs.length > 0) {
					var ppsNAL:HTTPStreamingH264NALU = ppsNALs.shift();
					var ppsLength:Number = ppsNAL.length;
					avcc.writeByte(ppsLength >> 8); // 16-bit PPS byte count
					avcc.writeByte(ppsLength);
					avcc.writeBytes(ppsNAL.NALdata, 0, ppsLength);
				}
				avccTag.data = avcc;
			}
			return avccTag;
		}
		
		[Inline]
		private function genVtag():void 
		{
			_vTag = new FLVTagVideo();
			_vTagData = new ByteArray(); // we assemble the nalus outside, set at end
			_vTag.codecID = FLVTagVideo.CODEC_ID_AVC;
			_vTag.frameType = FLVTagVideo.FRAME_TYPE_INTER; // adjust to keyframe later
			_vTag.avcPacketType = FLVTagVideo.AVC_PACKET_TYPE_NALU;
			_vTag.timestamp = _timestamp;
			_vTag.avcCompositionTimeOffset = _compositionTime;
		}
		
		CONFIG::LOGGING
		{
			private var logger:Logger = Log.getLogger('org.denivip.osmf.net.httpstreaming.hls.HTTPStreamingMP2PESVideo') as Logger;
		}
	
	} // class
	
} // package
