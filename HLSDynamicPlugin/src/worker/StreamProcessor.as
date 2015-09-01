package worker
{
	import com.hurlant.util.Hex;
	
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.system.MessageChannel;
	import flash.system.Worker;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	import org.denivip.osmf.net.httpstreaming.hls.HTTPStreamingM3U8IndexKey;
	import org.denivip.osmf.utility.decrypt.AES;
	
	public class StreamProcessor extends Sprite
	{
		private static const PROCESS_INTERVAL:int = 1000;
		
		private var _syncFound:Boolean;
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
		
		private var mtw:MessageChannel;
		private var wtm:MessageChannel;
		
		private var _input:ByteArray;
		private var _output:ByteArray;
		
		private var _inputCache:ByteArray;
		
		private var _timer:Timer = new Timer(PROCESS_INTERVAL);
		
		private var _discontinuityPos:ByteArray;
		private var _aesData:ByteArray;
		
		private var _initialOffset:int;
		
		public function StreamProcessor(){
			trace("A working thread was created");
			_videoPES = new HTTPStreamingMP2PESVideo();
			_audioPES = new HTTPStreamingMP2PESAudio();
			_mp3audioPES = new HTTPStreamingMp3Audio2ToPESAudio();
			
			mtw = Worker.current.getSharedProperty('mtw');
			wtm = Worker.current.getSharedProperty('wtm');
			
			_input = Worker.current.getSharedProperty('input');
			_output = Worker.current.getSharedProperty('output');
			_discontinuityPos = Worker.current.getSharedProperty('discPos');
			_aesData = Worker.current.getSharedProperty('aesData');
			
			_inputCache = new ByteArray();
			
			_timer.addEventListener(TimerEvent.TIMER, processData);
			
			mtw.addEventListener(Event.CHANNEL_MESSAGE, onMainMessage);
			
			_timer.start();
			wtm.send(Messages.READY);
		}
		
		protected function processData(event:TimerEvent):void{
			if (_input.bytesAvailable) {
				if (!_inputCache.bytesAvailable || _inputCache.bytesAvailable < 187) {
					//_inputCache.clear();
					_input.readBytes(_inputCache, _inputCache.length);
					_input.clear();
				}
				trace("Input MEMORY STATS:",_input.length, _input.bytesAvailable);
				trace("Cache MEMORY STATS:",_inputCache.length, _inputCache.bytesAvailable);
				
			}
			
			if(_inputCache.bytesAvailable < 187) {
				if(_inputCache.bytesAvailable == 0 && _input.bytesAvailable == 0){
					wtm.send(Messages.DONE);
				}
				return;
			}
			
			var out:ByteArray = processFileSegment(_inputCache);
			
			if(out != null){
				out.readBytes(_output, _output.length);
				trace("["+new Date().toLocaleString()+"] "+_output.bytesAvailable+' processed bytes sent to main stream');
				//wtm.send(_output.bytesAvailable+' bytes sent to main stream');
			}
		}
		
		protected function onMainMessage(event:Event):void{
			if(!mtw.messageAvailable)
				return;
			
			var msg:String = mtw.receive();
			
			trace("["+new Date().toLocaleString()+"] "+ msg+' message received in worker thread');
			/*
			if(msg == Messages.PROCESS_SEGMENT){
				//var swap:ByteArray = new ByteArray();
				//swap.writeBytes(_inputCache, _inputCache.position, _inputCache.bytesAvailable);
				//_inputCache = swap;
				//_input.readBytes(_inputCache, _inputCache.length);
				//_input.clear();
			}
			
			if(msg == Messages.BEGIN_PROCESS){
				//_syncFound = false;
			}
			
			if(msg == Messages.FLUSH){
				//_output = flushFileSegment();
				//flushFileSegment();
			}
			
			if(msg == Messages.END_PROCESS){
				//endProcessFile();
			}
			
			if(msg == Messages.RESET){
				resetCache();
			}*/
			
			if(msg == Messages.OFFSET){
				_initialOffset = mtw.receive();
				initialOffset = _initialOffset;
				trace("Worker offset configured:", _initialOffset);
				//initialOffset = _initialOffset;
			}
		}
		
		private var _discs:Array = [];
		private var _aes:Object = {};
		private var _cposition:uint = 0;
		private function processFileSegment(input:ByteArray):ByteArray
		{
			/*if (mtw.messageAvailable) {
				trace("["+new Date().toLocaleString()+"] Not yet processed messages prevent data processing");
				return null;
			}*/
			trace('start processing... Input length = '+input.length+' Input position = '+input.position);
			
			var bytesAvailableStart:uint = input.bytesAvailable;
			var output:ByteArray;
			
			// Update DISCONTINUITY data if available
			while (_discontinuityPos.bytesAvailable) {
				var dp:uint = _discontinuityPos.readUnsignedInt();
				var offset:Number = _discontinuityPos.readDouble();
				trace("Discontinuity to put:", dp);
				_discs.push(dp);
				_discs.push(offset);
			}
			_discontinuityPos.clear();
			
			// Update AES data if available
			while(_aesData && _aesData.bytesAvailable) {
				var cpos:uint = _aesData.position;
				var sz:int = _aesData.readInt();
				if (sz<=_aesData.bytesAvailable) {
					var tba:ByteArray = new ByteArray();
					_aesData.readBytes(tba, 0, sz);
					tba.position = 0;
					var tag:int = tba.readByte();
					if (tag==1) {//< AES key received
						var keyPos:uint = tba.readUnsignedInt();//< Key position from the beginning
						var keySz:int = tba.readInt();//< Key length
						var keyBytes:ByteArray = new ByteArray();
						tba.readBytes(keyBytes, 0, keySz);//< Key itself
						var keyTag:int = tba.readByte();//< 2 for key type
						var keyType:String = tba.readUTF();//< Key type itself
						if (_aes.hasOwnProperty(keyPos)) {
							_aes[keyPos].key = new HTTPStreamingM3U8IndexKey(keyType, null);
							_aes[keyPos].key.key = keyBytes;
						} else {
							_aes[keyPos] = {key: new HTTPStreamingM3U8IndexKey(keyType, null)};
							_aes[keyPos].key.key = keyBytes;
						}
						trace("["+new Date().toLocaleString()+"] AES key for",keyPos,"configured:",_aes[keyPos].key.key.length);
					} else if (tag==3) {//< IV received
						var civPos:uint = tba.readUnsignedInt();//< IV position from the beginning
						var civ:String = tba.readUTF();//< IV itself
						if (_aes.hasOwnProperty(civPos)) {
							_aes[civPos].iv = civ;
						} else {
							_aes[civPos] = {iv: civ};
						}
						trace("["+new Date().toLocaleString()+"] IV for",civPos,"configured:",_aes[civPos].iv.length);
					} else {
						trace("["+new Date().toLocaleString()+"] ERROR! Unknown AES data.");
					}					
				} else {
					trace("["+new Date().toLocaleString()+"] ERROR! Not yet ready AES data");
					_aesData.position = cpos;
				}
				
			}
			
			// Actual processing
			output = new ByteArray();
			
			var st:Date = new Date();
			
			while (true) {
				_cposition += bytesAvailableStart - input.bytesAvailable;
				bytesAvailableStart = input.bytesAvailable;
				
				// Apply discontinuities if needed
				if(_discs.length>1 && _discs[0] == _cposition) {
					//output.writeBytes(flushFileSegment());
					trace('putting discontinuity, position now: '+_cposition);
					isDiscontunity = true;
					initialOffset = _discs[1];
					_discs.shift();
					_discs.shift();
				}
				
				//trace("["+new Date().toLocaleString()+"] Current position:",_cposition);
				// Apply AES settings if needed
				if (_aes.hasOwnProperty(_cposition)){
					trace("["+new Date().toLocaleString()+"] Time to configure AES:",_cposition);
					_key = _aes[_cposition].key;
					iv = _aes[_cposition].iv;
					if (_decryptAES) {
						_decryptAES.destroy();
					}
					_decryptAES = null;
					delete _aes[_cposition];
				}
				
				if(!_syncFound)
				{
					if (_key) {
						if (_key.type == "AES-128") {
							if (input.bytesAvailable < 16) {
								if (_decryptBuffer.bytesAvailable < 1) {
									break;
								}
							} else {
								if (!decryptToBuffer(input, 16)) {
									break;
								}
							}
							if (_decryptBuffer.readByte() == 0x47) {
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
							if (input.bytesAvailable < 176) {
								if (_decryptBuffer.bytesAvailable < 187) {
									break;
								}
							} else {
								var bytesLeft:uint = input.bytesAvailable - 176;
								if (bytesLeft > 0 && bytesLeft < 15) {
									if (!decryptToBuffer(input, input.bytesAvailable)) {
										break;
									}
								} else {
									if (!decryptToBuffer(input, 176)) {
										break;
									}
								}
							}
							_decryptBuffer.readBytes(packet, 0, 187);
						}
					} else {
						if(input.bytesAvailable < 187)
							break;
						
						input.readBytes(packet, 0, 187);
					}
					
					_syncFound = false;
					var result:ByteArray = processPacket(packet);
					if (result !== null) {
						output.writeBytes(result);
					}
					
					/*if (output.length > 4*1024*1024) {
						var dt:Date = new Date();
						trace("Processing limit reached in " + (dt.time-st.time)+"ms");
						output.position = 0;
						return output;
					}*/					
				}
			}
			var dt:Date = new Date();
			trace("Processing of "+output.length+" bytes finished in " + (dt.time-st.time)+"ms");
			
			output.position = 0;
			
			return output.length === 0 ? null : output;
		}
		
		private function flushFileSegment():ByteArray
		{
			/*if(_timer.running)
			_timer.reset();
			*/
			var flvBytes:ByteArray = new ByteArray();
			var flvBytesVideo:ByteArray = _videoPES.processES(false, null, true);
			var flvBytesAudio:ByteArray = _audioPES.processES(false, null, true);
			
			if(flvBytesVideo)
				flvBytes.readBytes(flvBytesVideo);
			if(flvBytesAudio)
				flvBytes.readBytes(flvBytesAudio);
			
			return flvBytes;
		}
		
		private function endProcessFile():void{
			_decryptBuffer.clear();
			if (_decryptAES) {
				_decryptAES.destroy();
			}
			_decryptAES = null;
			/*
			if(_timer.running)
			_timer.reset();
			*/
		}
		
		private function resetCache():void{
			trace("===============================");
			trace("Cleaning things up. FULL RESET.");
			_decryptBuffer.clear();
			if (_decryptAES) {
				_decryptAES.destroy();
			}
			_decryptAES = null;
			_aes = {};
			//_aesData.clear();
			_key = null;
			_iv = null;
			
			_discs.length = 0;
			initialOffset = 0;
			_inputCache.clear();
			_input.clear();
			_output.clear();
		}
		
		private function set key(key:HTTPStreamingM3U8IndexKey):void {
			_key = key;
			if (_decryptAES) {
				_decryptAES.destroy();
			}
			_decryptAES = null;
		}
		
		private function set iv(iv:String):void {
			if (iv) {
				_iv = Hex.toArray(iv);
			}
		}
		
		private function set isDiscontunity(isDiscontunity:Boolean):void{
			_videoPES.isDiscontunity = isDiscontunity;
			_audioPES.isDiscontunity = isDiscontunity;
			_mp3audioPES.isDiscontunity = isDiscontunity;
		}
		
		
		private function set initialOffset(offset:Number):void{
			offset *= 1000; // convert to ms
			_videoPES.initialTimestamp = offset;
			_audioPES.initialTimestamp = offset;
			_mp3audioPES.initialTimestamp = offset;
		}
		
		
		// service funcs
		private function decryptToBuffer(input:ByteArray, blockSize:int):Boolean{
			if (_key) {
				// Clear buffer
				if (_decryptBuffer.bytesAvailable == 0) {
					_decryptBuffer.clear();
				}
				
				if (_key.type == "AES-128" && blockSize % 16 == 0 && _key.key) {
					if (!_decryptAES) {
						_decryptAES = new AES(_key.key);
						_decryptAES.pad = "none";
						_decryptAES.iv = _iv;
					}
					
					// Save buffer position
					var currentPosition:uint = _decryptBuffer.position;
					_decryptBuffer.position += _decryptBuffer.bytesAvailable;
					
					// Save block to decrypt
					var decrypt:ByteArray = new ByteArray;
					input.readBytes(decrypt, 0, blockSize);
					if(decrypt.bytesAvailable==0) {
						return false;
					}
					// Save new IV from ciphertext
					var newIv:ByteArray = new ByteArray;
					decrypt.position += (decrypt.bytesAvailable-16);
					decrypt.readBytes(newIv, 0, 16);
					decrypt.position = 0;
					// Decrypt
					if (input.bytesAvailable == 0) {
						_decryptAES.pad = "pkcs7";
					}
					_decryptAES.decrypt(decrypt);
					decrypt.position = 0;
					// Write into buffer
					_decryptBuffer.writeBytes(decrypt);
					_decryptBuffer.position = currentPosition;
					// Update AES IV
					_decryptAES.iv = newIv;
					
					return true;
				}
			}
			
			return false;
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
			//wtm.send('pid: '+pid);
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
		
	}
}