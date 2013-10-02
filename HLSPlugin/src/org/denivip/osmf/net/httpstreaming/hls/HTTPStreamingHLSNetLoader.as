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
	import flash.net.NetConnection;
	import flash.net.NetStream;
	
	import org.denivip.osmf.metadata.HLSMetadata;
	import org.denivip.osmf.net.httpstreaming.dvr.HTTPHLSStreamingDVRCastDVRTrait;
	import org.denivip.osmf.net.httpstreaming.dvr.HTTPHLSStreamingDVRCastTimeTrait;
	import org.osmf.events.DVRStreamInfoEvent;
	import org.osmf.media.MediaResourceBase;
	import org.osmf.media.URLResource;
	import org.osmf.metadata.Metadata;
	import org.osmf.metadata.MetadataNamespaces;
	import org.osmf.net.DynamicStreamingResource;
	import org.osmf.net.NetStreamLoadTrait;
	import org.osmf.net.NetStreamSwitchManagerBase;
	import org.osmf.net.NetStreamSwitcher;
	import org.osmf.net.httpstreaming.DefaultHTTPStreamingSwitchManager;
	import org.osmf.net.httpstreaming.HTTPStreamingNetLoader;
	import org.osmf.net.httpstreaming.dvr.DVRInfo;
	import org.osmf.net.metrics.MetricFactory;
	import org.osmf.net.metrics.MetricRepository;
	import org.osmf.net.qos.QoSInfoHistory;
	import org.osmf.net.rules.BufferBandwidthRule;
	import org.osmf.net.rules.RuleBase;
	import org.osmf.traits.LoadState;
	
	public class HTTPStreamingHLSNetLoader extends HTTPStreamingNetLoader
	{
		override public function canHandleResource(resource:MediaResourceBase):Boolean
		{
			return resource.getMetadataValue(HLSMetadata.HLS_METADATA) != null;
		}
		
		override protected function createNetStream(connection:NetConnection, resource:URLResource):NetStream
		{
			var httpNetStream:HTTPHLSNetStream = new HTTPHLSNetStream(connection, new HTTPStreamingHLSFactory(), resource);
			return httpNetStream;
			//return new HTTPNetStream(connection, new HTTPStreamingHLSFactory(), resource);
		}
		
		override protected function processFinishLoading(loadTrait:NetStreamLoadTrait):void
		{
			var resource:URLResource = loadTrait.resource as URLResource;
			
			if (!dvrMetadataPresent(resource))
			{
				updateLoadTrait(loadTrait, LoadState.READY);
				
				return;
			}
			
			var netStream:HTTPHLSNetStream = loadTrait.netStream as HTTPHLSNetStream;
			netStream.addEventListener(DVRStreamInfoEvent.DVRSTREAMINFO, onDVRStreamInfo);
			netStream.DVRGetStreamInfo(null);
			function onDVRStreamInfo(event:DVRStreamInfoEvent):void
			{
				netStream.removeEventListener(DVRStreamInfoEvent.DVRSTREAMINFO, onDVRStreamInfo);
				
				loadTrait.setTrait(new HTTPHLSStreamingDVRCastDVRTrait(loadTrait.connection, netStream, event.info as DVRInfo));
				loadTrait.setTrait(new HTTPHLSStreamingDVRCastTimeTrait(loadTrait.connection, netStream, event.info as DVRInfo));
				updateLoadTrait(loadTrait, LoadState.READY);
			}
		}
		
		override protected function createNetStreamSwitchManager(connection:NetConnection, netStream:NetStream, dsResource:DynamicStreamingResource):NetStreamSwitchManagerBase{
			var qInfoHist:QoSInfoHistory = createNetStreamQoSInfoHistory(netStream);
			var mFactory:MetricFactory = createMetricFactory(qInfoHist);
			var mRepository:MetricRepository = new MetricRepository(mFactory);
			var rules:Vector.<RuleBase> = new Vector.<RuleBase>();
			var ruleWeights:Vector.<Number> = new Vector.<Number>();
			rules.push(
				new BufferBandwidthRule(mRepository, BANDWIDTH_BUFFER_RULE_WEIGHTS, BANDWIDTH_BUFFER_RULE_BUFFER_FRAGMENTS_THRESHOLD)
			);
			ruleWeights.push(1.0);
			var netStreamSw:NetStreamSwitcher = new NetStreamSwitcher(netStream, dsResource);
			return new DefaultHTTPStreamingSwitchManager(netStream, netStreamSw, mRepository, null, true, rules, ruleWeights);
		}
		
		// Internals
		private function dvrMetadataPresent(resource:URLResource):Boolean
		{
			var metadata:Metadata = resource.getMetadataValue(MetadataNamespaces.DVR_METADATA) as Metadata;
			
			return (metadata != null);
		}
	}
}
