package org.denivip.osmf.net
{
	import org.osmf.net.DynamicStreamingItem;
	import org.osmf.net.DynamicStreamingResource;
	
	/**
	 * Simple DynamicStreamingResource, used for correct quality switching
	 */
	public class HLSDynamicStreamingResource extends DynamicStreamingResource
	{
		public function HLSDynamicStreamingResource(
			url:String,
			streamType:String = null,
			streamItems:Vector.<DynamicStreamingItem> = null
		)
		{
			super(url, streamType);
			this.streamItems = streamItems;
		}
	}
}