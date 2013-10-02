package org.denivip.osmf.plugins
{
	import org.denivip.osmf.elements.M3U8Loader;
	import org.osmf.elements.LoadFromDocumentElement;
	import org.osmf.media.MediaElement;
	import org.osmf.media.MediaFactoryItem;
	import org.osmf.media.MediaFactoryItemType;
	import org.osmf.media.MediaResourceBase;
	import org.osmf.media.PluginInfo;
	import org.osmf.media.URLResource;
	
	public class HLSPluginInfo extends PluginInfo
	{
		public function HLSPluginInfo(items:Vector.<MediaFactoryItem>=null, elementCreationNotifFunc:Function=null){
			
			items = new Vector.<MediaFactoryItem>();
			items.push(
				new MediaFactoryItem(
					'org.denivip.osmf.plugins.HLSPlugin',
					canHandleResource,
					createMediaElement,
					MediaFactoryItemType.STANDARD
				)
			);
			
			super(items, elementCreationNotifFunc);
		}
		
		private function canHandleResource(resource:MediaResourceBase):Boolean{
			if(resource == null || !(resource is URLResource))
				return false;
			
			var urlResource:URLResource = resource as URLResource;
			if (urlResource.url.search(/(https?|file)\:\/\/.*?\.m3u8(\?.*)?/i) !== -1) {
				return true;
			}
			
			var contentType:Object = urlResource.getMetadataValue("content-type");
			if (contentType && contentType is String) {
				if ((contentType as String).search(/(application\/x-mpegURL|vnd.apple.mpegURL)/i) !== -1) {
					return true;
				}
			}
			
			return false;
		}
		
		private function createMediaElement():MediaElement{
			return new LoadFromDocumentElement(null, new M3U8Loader());
		}
	}
}
