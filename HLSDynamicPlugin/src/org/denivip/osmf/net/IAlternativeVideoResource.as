package org.denivip.osmf.net
{
	import org.denivip.osmf.net.httpstreaming.hls.HLSStreamInfo;
	import org.osmf.net.StreamingItem;

	public interface IAlternativeVideoResource
	{
		function get alternativeVideoStreamItems():Vector.<StreamingItem>;
		function set alternativeVideoStreamItems(value:Vector.<StreamingItem>):void;
		function alternativeVideoStream(name:String, quality:int):Vector.<HLSStreamInfo>;
	}
}