package org.denivip.osmf.utility
{
	import flash.utils.ByteArray;

	import com.hurlant.util.Hex;
	import com.hurlant.crypto.Crypto;
	import com.hurlant.crypto.symmetric.*;
	
	/**
	 * Contains Utility functions for Decryption
	 */
	public class Decrypt
	{
		public static function hexToByteArray(hexString:String):ByteArray {
			return Hex.toArray(hexString);
		}
		
		public static function decryptAES128(data:ByteArray, key:ByteArray, iv:ByteArray, padType:String="none"):ByteArray {
			var pad:IPad;
			if (padType == "pkcs7") {
				pad = new PKCS5;
			} else {
				pad = new NullPad;
			}
			var mode:ICipher = Crypto.getCipher('aes-128-cbc', key, pad);
			pad.setBlockSize(mode.getBlockSize());
			if (mode is IVMode) {
				var ivmode:IVMode = mode as IVMode;
				ivmode.IV = iv;
			}
			mode.decrypt(data);
			return data;
		}
	}
		
}