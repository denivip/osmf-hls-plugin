package org.denivip.osmf.elements
{
	import flash.events.Event;
	
	import org.osmf.elements.ProxyElement;
	import org.osmf.elements.XMLLoader;
	import org.osmf.elements.proxyClasses.LoadFromDocumentLoadTrait;
	import org.osmf.events.LoadEvent;
	import org.osmf.media.MediaResourceBase;
	import org.osmf.net.StreamingXMLResource;
	import org.osmf.traits.LoadState;
	import org.osmf.traits.LoadTrait;
	import org.osmf.traits.LoaderBase;
	import org.osmf.traits.MediaTraitType;
	import org.osmf.utils.OSMFStrings;
	
	public class M3U8Element extends ProxyElement
	{
		public function M3U8Element(resource:MediaResourceBase)
		{
			super(null);
			
			this.loader = new M3U8Loader();			
			this.resource = resource;
			
			if (loader == null)
			{
				throw new ArgumentError(OSMFStrings.getString(OSMFStrings.NULL_PARAM));
			} 
		}
		
		/**
		 * @private
		 * 
		 * Overriding is necessary because there is a null proxiedElement.
		 */ 
		override public function set resource(value:MediaResourceBase):void 
		{
			if (_resource != value && value != null)
			{
				_resource = value;
				
				if (value is StreamingXMLResource)
				{
					loader = new XMLLoader();
				}
				
				loadTrait = new LoadFromDocumentLoadTrait(loader, resource);
				loadTrait.addEventListener(LoadEvent.LOAD_STATE_CHANGE, onLoadStateChange, false, int.MAX_VALUE);
				
				if (super.getTrait(MediaTraitType.LOAD) != null)
				{
					super.removeTrait(MediaTraitType.LOAD);
				}
				super.addTrait(MediaTraitType.LOAD, loadTrait);			
			}						
		}
		
		/**
		 * @private
		 */
		override public function get resource():MediaResourceBase
		{
			return _resource;
		}
		
		// Internals
		//
		
		private function onLoaderStateChange(event:Event):void
		{
			// Remove the temporary LoadTrait.
			removeTrait(MediaTraitType.LOAD);
			
			proxiedElement = loadTrait.mediaElement;
		}
		
		private function onLoadStateChange(event:LoadEvent):void
		{
			if (event.loadState == LoadState.READY)
			{
				event.stopImmediatePropagation();
				
				// Remove the temporary LoadTrait.
				removeTrait(MediaTraitType.LOAD);
				
				// Tell the soon-to-be proxied element to load itself.
				// Note that we do this before setting it as the proxied
				// element, so as to avoid dispatching a second LOADING
				// event.
				
				// Set up a listener so that we can prevent the dispatch
				// of a second LOADING event.
				var proxiedLoadTrait:LoadTrait = loadTrait.mediaElement.getTrait(MediaTraitType.LOAD) as LoadTrait;
				proxiedLoadTrait.addEventListener(LoadEvent.LOAD_STATE_CHANGE, onProxiedElementLoadStateChange, false, int.MAX_VALUE);
				
				// Expose the proxied element.
				proxiedElement = loadTrait.mediaElement;
				
				// If our proxied element hasn't started loading yet, we should
				// initiate the load.
				if (proxiedLoadTrait.loadState == LoadState.UNINITIALIZED)
				{
					proxiedLoadTrait.load();
				}
				
				function onProxiedElementLoadStateChange(event:LoadEvent):void
				{
					if (event.loadState == LoadState.LOADING)
					{
						event.stopImmediatePropagation();
					}
					else
					{
						proxiedLoadTrait.removeEventListener(LoadEvent.LOAD_STATE_CHANGE, onProxiedElementLoadStateChange);
					}
				}
			}
		}
		
		private var _resource:MediaResourceBase;
		private var loadTrait:LoadFromDocumentLoadTrait;
		private var loader:LoaderBase;
	}
}