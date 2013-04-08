package
{
	import flash.display.Sprite;
	
	import org.denivip.osmf.plugins.HLSPluginInfo;
	import org.osmf.containers.MediaContainer;
	import org.osmf.events.MediaFactoryEvent;
	import org.osmf.media.DefaultMediaFactory;
	import org.osmf.media.MediaElement;
	import org.osmf.media.MediaPlayer;
	import org.osmf.media.PluginInfoResource;
	import org.osmf.media.URLResource;
	
	public class HLSTestPlayer extends Sprite
	{
		private static const HLS_VIDEO:String = 'http://osmfhls.kutu.ru/static/vod/sl_vod.m3u8';//1240_vod.m3u8';//'http://edge-2.ny.2gzr.com/515e7bd6531a480bfa000008.m3u8';//
		private static const F4M_TEST:String = "http://193.232.148.98/1030-hdsmobile-not-protected.f4m";//"http://mediapm.edgesuite.net/osmf/content/test/manifest-files/dynamic_Streaming.f4m";
		
		public function HLSTestPlayer(){
			initPlayer();
		}
		
		private function initPlayer():void{
			var factory:DefaultMediaFactory = new DefaultMediaFactory();
			factory.addEventListener(MediaFactoryEvent.PLUGIN_LOAD, onLoadPlugin);
			factory.addEventListener(MediaFactoryEvent.PLUGIN_LOAD_ERROR, onError);
			factory.loadPlugin(new PluginInfoResource(new HLSPluginInfo()));
			
			var res:URLResource = new URLResource( HLS_VIDEO );
			
			var element:MediaElement = factory.createMediaElement(res);
			if(element == null)
				throw new Error('Unsupported media type!');
			
			var player:MediaPlayer = new MediaPlayer(element);
			
			var container:MediaContainer = new MediaContainer();
			container.addMediaElement(element);
			container.scaleX = .75;
			container.scaleY = .75;
			
			addChild(container);
		}
		
		protected function onError(event:MediaFactoryEvent):void{
			trace("plugin load error!");
		}
		
		protected function onLoadPlugin(event:MediaFactoryEvent):void{
			trace("plugin loaded!");
		}
	}
}