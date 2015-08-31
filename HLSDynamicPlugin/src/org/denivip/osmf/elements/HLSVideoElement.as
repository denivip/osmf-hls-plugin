package org.denivip.osmf.elements
{
	import org.denivip.osmf.net.IAlternativeVideoResource;
	import org.denivip.osmf.net.httpstreaming.hls.HTTPHLSNetStream;
	import org.denivip.osmf.traits.AlternativeVideoTrait;
	import org.osmf.elements.VideoElement;
	import org.osmf.media.MediaResourceBase;
	import org.osmf.net.NetLoader;
	import org.osmf.net.NetStreamLoadTrait;
	import org.osmf.traits.MediaTraitType;
	
	public class HLSVideoElement extends VideoElement
	{
		private var _stream:HTTPHLSNetStream = null;
		
		public function HLSVideoElement(resource:MediaResourceBase=null, loader:NetLoader=null)
		{
			super(resource, loader);
		}
		
		override protected function processReadyState():void{
			super.processReadyState();
			
			// add av_trait
			var loadTrait:NetStreamLoadTrait = (getTrait(MediaTraitType.LOAD) as NetStreamLoadTrait);
			_stream = loadTrait.netStream as HTTPHLSNetStream;
			var temp:IAlternativeVideoResource = resource as IAlternativeVideoResource;
			if(temp != null && temp.alternativeVideoStreamItems != null && temp.alternativeVideoStreamItems.length > 0){
				
				var avTrait:AlternativeVideoTrait = loadTrait.getTrait(AlternativeVideoTrait.ALTERNATIVE_VIDEO) as AlternativeVideoTrait;
				
				if(avTrait == null)
					avTrait = new AlternativeVideoTrait(_stream, temp);
				
				addTrait(AlternativeVideoTrait.ALTERNATIVE_VIDEO, avTrait);
			}
		}
		
		override protected function processUnloadingState():void{
			removeTrait(AlternativeVideoTrait.ALTERNATIVE_VIDEO);
			
			super.processUnloadingState();
		}
	}
}