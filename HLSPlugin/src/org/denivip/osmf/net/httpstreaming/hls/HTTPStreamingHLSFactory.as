/* ***** BEGIN LICENSE BLOCK *****
* Version: MPL 1.1
*
* The contents of this file are subject to the Mozilla Public License Version
* 1.1 (the "License"); you may not use this file except in compliance with
* the License. You may obtain a copy of the License at
* http://www.mozilla.org/MPL/
*
* Software distributed under the License is distributed on an "AS IS" basis,
* WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
* for the specific language governing rights and limitations under the
* License.
*
* The Original Code is the at.matthew.httpstreaming package.
*
* The Initial Developer of the Original Code is
* Matthew Kaufman.
* Portions created by the Initial Developer are Copyright (C) 2011
* the Initial Developer. All Rights Reserved.
*
* Contributor(s):
*
* ***** END LICENSE BLOCK ***** */

package org.denivip.osmf.net.httpstreaming.hls
{
	import org.denivip.osmf.net.HLSDynamicStreamingItem;
	import org.denivip.osmf.net.HLSDynamicStreamingResource;
	import org.denivip.osmf.net.HLSMediaChunk;
	import org.osmf.elements.VideoElement;
	import org.osmf.media.MediaElement;
	import org.osmf.media.MediaResourceBase;
	import org.osmf.metadata.Metadata;
	import org.osmf.metadata.MetadataNamespaces;
	import org.osmf.net.DynamicStreamingItem;
	import org.osmf.net.httpstreaming.HTTPStreamingFactory;
	import org.osmf.net.httpstreaming.HTTPStreamingFileHandlerBase;
	import org.osmf.net.httpstreaming.HTTPStreamingIndexHandlerBase;
	import org.osmf.net.httpstreaming.HTTPStreamingIndexInfoBase;
	import org.osmf.net.httpstreaming.dvr.DVRInfo;
	
	/**
	 * HLS Streaming factory
	 */
	public class HTTPStreamingHLSFactory extends HTTPStreamingFactory
	{
		public function HTTPStreamingHLSFactory()
		{
			super();
		}
		
		override public function createFileHandler(resource:MediaResourceBase):HTTPStreamingFileHandlerBase
		{	
			return new HTTPStreamingMP2TSFileHandler();
		}
		override public function createIndexHandler(resource:MediaResourceBase, fileHandler:HTTPStreamingFileHandlerBase):HTTPStreamingIndexHandlerBase
		{
			return new HTTPStreamingHLSIndexHandler();
		}
		
		override public function createIndexInfo(resource:MediaResourceBase):HTTPStreamingIndexInfoBase
		{
			var hlsr:HLSDynamicStreamingResource = resource as HLSDynamicStreamingResource;
			return createHLSIndexInfo(hlsr);
		}
		
		public function createMediaElement():MediaElement{
			var loader:HTTPStreamingM3U8NetLoader = new HTTPStreamingM3U8NetLoader();
			return new VideoElement(null, loader);
		}
		
		private function createHLSIndexInfo(res:HLSDynamicStreamingResource):HTTPStreamingHLSIndexInfo{
			var indexInfo:HTTPStreamingHLSIndexInfo = null;
			
			var streamItems:Vector.<DynamicStreamingItem> = res.streamItems;//res.playlist;
			var streams:Vector.<HTTPStreamingM3U8IndexRateItem> = new Vector.<HTTPStreamingM3U8IndexRateItem>();
			
			var rItem:HTTPStreamingM3U8IndexRateItem;
			var iItem:HTTPStreamingM3U8IndexItem;
			for each(var item:HLSDynamicStreamingItem in streamItems){
				rItem = new HTTPStreamingM3U8IndexRateItem(item.bitrate, item.streamName, 0, item.isLive);
				
				for each(var subItem:HLSMediaChunk in item.chunks){
					iItem = new HTTPStreamingM3U8IndexItem(subItem.duration, subItem.url);
					rItem.addIndexItem(iItem);
				}
				streams.push(rItem);
			}
			
			//DVR
			var dvrMetadata:Metadata = res.getMetadataValue(MetadataNamespaces.DVR_METADATA) as Metadata;
			var dvrInfo:DVRInfo = createDVRInfo(dvrMetadata);
			
			indexInfo = new HTTPStreamingHLSIndexInfo(res.url, streams, dvrInfo);
			
			return indexInfo;
			
			// service part =)
			function createDVRInfo(metadata:Metadata):DVRInfo{
				if (metadata == null){
					return null;
				}
				
				var dvrInfo:DVRInfo = new DVRInfo();
				dvrInfo.id = "";
				dvrInfo.beginOffset = NaN;
				dvrInfo.endOffset = NaN;
				dvrInfo.windowDuration = NaN;
				dvrInfo.offline = false;
				if (metadata.getValue(MetadataNamespaces.HTTP_STREAMING_DVR_ID_KEY) != null){
					dvrInfo.id = metadata.getValue(MetadataNamespaces.HTTP_STREAMING_DVR_ID_KEY) as String;
				}
				if (metadata.getValue(MetadataNamespaces.HTTP_STREAMING_DVR_BEGIN_OFFSET_KEY) != null){
					dvrInfo.beginOffset = metadata.getValue(MetadataNamespaces.HTTP_STREAMING_DVR_BEGIN_OFFSET_KEY) as uint;
				}
				if (metadata.getValue(MetadataNamespaces.HTTP_STREAMING_DVR_END_OFFSET_KEY) != null){
					dvrInfo.endOffset = metadata.getValue(MetadataNamespaces.HTTP_STREAMING_DVR_END_OFFSET_KEY) as uint;
				}
				if (metadata.getValue(MetadataNamespaces.HTTP_STREAMING_DVR_WINDOW_DURATION_KEY) != null){
					dvrInfo.windowDuration = metadata.getValue(MetadataNamespaces.HTTP_STREAMING_DVR_WINDOW_DURATION_KEY) as int;
				}
				if (metadata.getValue(MetadataNamespaces.HTTP_STREAMING_DVR_OFFLINE_KEY) != null){
					dvrInfo.offline = metadata.getValue(MetadataNamespaces.HTTP_STREAMING_DVR_OFFLINE_KEY) as Boolean;
				}
				
				return dvrInfo;
			}
		}
	}
}