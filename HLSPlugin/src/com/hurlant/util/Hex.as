/**
 * Hex
 *
 * Utility class to convert Hex strings to ByteArray or String types.
 * Copyright (c) 2007 Henri Torgemane
 *
 * See LICENSE.txt for full license information.
 */
package com.hurlant.util {

	import flash.utils.ByteArray;

	public class Hex {

		/**
		 * Generates byte-array from given hexadecimal string
		 *
		 * Supports straight and colon-laced hex (that means 23:03:0e:f0, but *NOT* 23:3:e:f0)
		 * The first nibble (hex digit) may be omitted.
		 * Any whitespace characters are ignored.
		 */
		public static function toArray(hex:String):ByteArray {
			hex = hex.replace(/^0x|\s|:/gm,'');
			var a:ByteArray = new ByteArray;
			if ((hex.length&1)==1) hex="0"+hex;
			for (var i:uint=0;i<hex.length;i+=2) {
				a[i/2] = parseInt(hex.substr(i,2),16);
			}
			return a;
		}

		/**
		 * Generates lowercase hexadecimal string from given byte-array
		 */
		public static function fromArray(array:ByteArray, colons:Boolean=false):String {
			var s:String = "";
			for (var i:uint=0;i<array.length;i++) {
				s+=("0"+array[i].toString(16)).substr(-2,2);
				if (colons) {
					if (i<array.length-1) s+=":";
				}
			}
			return s;
		}

		/**
		 * Generates string from given hexadecimal string
		 */
		public static function toString(hex:String, charSet:String='utf-8'):String {
			var a:ByteArray = toArray(hex);
			return a.readMultiByte(a.length, charSet);
		}

		/**
		 * Convenience method for generating string using iso-8859-1
		 */
		public static function toRawString(hex:String):String {
			return toString(hex, 'iso-8859-1');
		}

		/**
		 * Generates hexadecimal string from given string
		 */
		public static function fromString(str:String, colons:Boolean=false, charSet:String='utf-8'):String {
			var a:ByteArray = new ByteArray;
			a.writeMultiByte(str, charSet);
			return fromArray(a, colons);
		}

		/**
		 * Convenience method for generating hexadecimal string using iso-8859-1
		 */
		public static function fromRawString(str:String, colons:Boolean=false):String {
			return fromString(str, colons, 'iso-8859-1');
		}

	}
}
