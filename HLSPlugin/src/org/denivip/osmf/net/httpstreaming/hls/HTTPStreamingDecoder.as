package org.denivip.osmf.net.httpstreaming.hls 
{
	import flash.external.ExternalInterface;
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	CONFIG::LOGGING{
		import org.osmf.logging.Log;
		import org.osmf.logging.Logger;
	}
	import tec.Faest.CModule;
	/**
	 * ...
	 * @author 
	 */
	public class HTTPStreamingDecoder 
	{
		private static const BUFFERSIZE:uint = 20 * 1024 * 1024; //20mb
		private static var ctx:uint;
		private static var pData:uint;
		private var pCipherOffset:uint;
		private var pDataReadOffset:uint;
		private var pDataWriteOffset:uint;
		private var _input:IDataInput;
		private var _bytesAvailable:uint;
		private var iv:uint;
		private var mkey:uint;
		public function HTTPStreamingDecoder(iv:uint, mkey:uint) 
		{
			pDataWriteOffset = pDataReadOffset = pData;
			this.mkey = mkey;
			this.iv = iv;
			
			
			//init new Faest context
			if (Faest.AesCtxIni(ctx, iv, mkey, Faest.KEY128, String(Faest.CBC)) < 0) {
				;
				CONFIG::LOGGING {
					logger.error("fAESt init error");	
				}
			}else {
				;
				CONFIG::LOGGING{
					logger.info("initialized fAESt: " + pData);
					logger.info("fAESt config: *ctx -> " + ctx + " *iv -> "  + iv + " *mkey -> " + mkey);
				}
			}
		}
		
		public function dispose():void {
			CModule.free(this.mkey);
			CModule.free(this.iv);
		}
		
		public function readByte():uint {
			decode(1);
			var retval:uint = CModule.read8(pDataReadOffset);
			pDataReadOffset += 1;
			return retval;
		}
		
		public function readBytes(output:ByteArray, length:uint):void {
			decode(length);
			CModule.readBytes(pDataReadOffset, length, output);
			pDataReadOffset += length;
			output.position = 0;
		}
		
		private function decode(numBytes:uint):uint {
			var decryptedBytes:int = 0;
			if (bufferBytesAvailable < numBytes) { //without this check video goes skipping
				//need to decode more bytes, buffer is quite empty
				
				//always write and decrypt in blocks of 16
				var toWriteInCipher:uint  = multipleOf16(numBytes - bufferBytesAvailable);
				
				if(toWriteInCipher <= _input.bytesAvailable){
					//load new bytes in ciphered_space pCipher
					CModule.writeBytes(pDataWriteOffset, toWriteInCipher, _input);
					
					//decrypt into decrypted_space pData
					decryptedBytes = Faest.AesDecrypt(ctx, pDataWriteOffset, pDataWriteOffset, toWriteInCipher);
					if (decryptedBytes < 0) {
						;
						CONFIG::LOGGING {
							logger.error(HTTPStreamingDecoder + " error in decryption\n");
						}
					}else {
						decryptedBytes = pDataWriteOffset += toWriteInCipher;
					}
				}
			}
			return decryptedBytes; //actually decrypted bytes.
			
		}
		
		private function roundUp(numToRound:int, multiple:int):int
		{ 
			if(multiple == 0) 
			{ 
				return numToRound; 
			} 

			var remainder:int = numToRound % multiple;
			if (remainder == 0){
				return numToRound;
			}
			return numToRound + multiple - remainder;
		} 
		
		private function multipleOf16(i:uint):uint {
			//return i % 16 < 16 ?  i - i % 16: i + (i - i % 16);
			return roundUp(i, 16);
		}
		
		private function get bufferBytesAvailable():uint 
		{
			return pDataWriteOffset - pDataReadOffset;
		}
		
		public function get bytesAvailable():uint 
		{
			//use lower 16 limit
			return (_input.bytesAvailable - _input.bytesAvailable % 16) + bufferBytesAvailable;
		}
		
		public function set input(value:IDataInput):void 
		{
			_input = value;
		}
		
		/**
		 * CModule Memory Fragmentation workaround
		 * https://github.com/adobe-flash/crossbridge/wiki/Memory-Fragmentation
		 * http://www.adobe.com/devnet-docs/flascc/docs/capidocs/as3.html
		 * http://www.adobe.com/devnet-docs/flascc/docs/apidocs/com/adobe/flascc/CModule.html#ram
		 */
		public static function fragmentationFix():void {
			
			pData =  CModule.malloc(BUFFERSIZE);
			ctx = CModule.malloc(500);
			CModule.throwWhenOutOfMemory = false;
			CModule.startAsync();
			/*
			var p:int=CModule.malloc(BUFFERSIZE * 2);//pre-allocate a block domain memory, the size should be according to your project
			if (!p)
				throw(new Error("You have opened too many pages, close some of them or restart your browser!"));
			CModule.malloc(1);//take up the domain memory
			CModule.free(p);//release the pre-allocated memory so that it can be used for new C/C++ Object
		    */
		}
		
				
		CONFIG::LOGGING
		{
			private static const logger:Logger = Log.getLogger("org.denivip.osmf.net.httpstreaming.hls.HTTPStreamingDecoder") as Logger;
		}
	}

}