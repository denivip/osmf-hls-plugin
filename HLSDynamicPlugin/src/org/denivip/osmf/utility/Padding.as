package org.denivip.osmf.utility
{
	/**
	 * Contains Utility functions for Padding
	 */
	public class Padding
	{
		
		public static function zeropad(num:int, radix:int, length:uint):String {
			var str:String = num.toString(radix);
			while(str.length < length) {
				str = "0" + str;
			}
			return str;
		}
	}
		
}