package org.denivip.osmf.utils
{
	import org.osmf.utils.URL;
	
	public class Utils
	{
		public static function createFullUrl(rootUrl:String, url:String):String{
			
			if(url.search(/(ftp|file|https?):\/\/\/?/) == 0)
				return url;
			
			// other manipulations :)
			if(url.charAt(0) == '/'){
				return URL.getRootUrl(rootUrl) + url;
			}
			
			if(rootUrl.lastIndexOf('/') != rootUrl.length)
				rootUrl += '/';
			
			return rootUrl + url;
		}
	}
}