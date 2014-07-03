package org.denivip.osmf.plugins
{
	import flash.external.ExternalInterface;
	
	import org.denivip.osmf.elements.M3U8Loader;
	import org.osmf.elements.LoadFromDocumentElement;
	import org.osmf.media.MediaElement;
	import org.osmf.media.MediaFactoryItem;
	import org.osmf.media.MediaFactoryItemType;
	import org.osmf.media.MediaResourceBase;
	import org.osmf.media.PluginInfo;
	import org.osmf.media.URLResource;
	import org.osmf.metadata.Metadata;
		
	public class HLSPluginInfo extends PluginInfo
	{
		private static const VER:String = "v1.2.1 debug";
		
		public function HLSPluginInfo(items:Vector.<MediaFactoryItem>=null, elementCreationNotifFunc:Function=null){
			
			CONFIG::LOGGING{
				if(ExternalInterface.available)
					ExternalInterface.call("console.log", "HLSPlugin "+VER+" (c) DENIVIP");
			}
			
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
			var md:Metadata = new Metadata();
			md.addValue("adsEnabled", "true");
			resource.addMetadataValue("http://www.liverail.com/plugins/osmf/metadata",md);
			
			return M3U8Loader.canHandle(resource);	
		}
		
		private function createMediaElement():MediaElement{
			var me:MediaElement = new LoadFromDocumentElement(null, new M3U8Loader());
			var md:Metadata = new Metadata();
			md.addValue("adsEnabled", "true");
			me.addMetadata("http://www.liverail.com/plugins/osmf/metadata",md);
			return me;
		}
		
		override public function initializePlugin(resource:MediaResourceBase):void{
			var hls_settings:Metadata = resource.getMetadataValue(HLSSettings.NAMESPACE) as Metadata;
			if(hls_settings){
				var minBuffer:Number = hls_settings.getValue('minBuffer') as Number;
				if(minBuffer)
					HLSSettings.hlsBufferSizeMin = minBuffer;
				
				var defBuffer:Number = hls_settings.getValue('defaultBuffer') as Number;
				if(defBuffer)
					HLSSettings.hlsBufferSizeDef = defBuffer;
				
				var bigBuffer:Number = hls_settings.getValue('bigBuffer') as Number;
				if(bigBuffer)
					HLSSettings.hlsBufferSizeBig = bigBuffer;
				
				var pauseBuffer:Number = hls_settings.getValue('pauseBuffer') as Number;
				if(pauseBuffer)
					HLSSettings.hlsBufferSizePause = pauseBuffer;
				
				var addBuffer:Number = hls_settings.getValue('addBuffer') as Number;
				if(addBuffer)
					HLSSettings.hlsAddBufferSize = addBuffer;
			}
		}
	}
}
