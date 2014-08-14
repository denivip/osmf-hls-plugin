package org.denivip.osmf.net.httpstreaming.hls.subtitles {
	
	public class WebVTTParser {
		
		private static const TIMESTAMP:RegExp = /^(?:(\d{2,}):)?(\d{2}):(\d{2})[,.](\d{3})$/;
		private static const CUE_1:RegExp = /^(?:(.*)(?:\r\n|\n))?([\d:,.]+) --> ([\d:,.]+)(?:\salign:middle)(?:\r\n|\n)(.*)$/;
		private static const CUE_2:RegExp       = /^(?:(.*)(?:\r\n|\n))?([\d:,.]+) --> ([\d:,.]+)(?:\salign:middle)(?:\r\n|\n)(.*)(?:\r\n|\n)(.*)$/;
		private static const EMPTY_CUE:RegExp = /^^(?:(.*)(?:\r\n|\n))?([\d:,.]+) --> ([\d:,.]+)(?:\salign:middle)$/
		private static const WEBVTT:RegExp    = /^\uFEFF?WEBVTT(?: .*)?/;
		
		private static var _off:Number = 0;
		
		public static function parse(data:String, subtitlesVO:SubtitlesVO):SubtitlesVO {
			if(!subtitlesVO)
				subtitlesVO = new SubtitlesVO();
			
			var lines:Array = data.split(/(?:(?:\r\n|\n){2,})/);
			var matches:Array = [];
			var i:int = 0;
			do{
				if(i == 0 && WEBVTT.test(lines[i])){
					var meta:String = String(lines[i]).split('\n')[1];
					meta = meta.split(',')[0];
					i++;
				}
				
				var start:Number = _off;
				var end:Number = _off;
				var text:String;
				
				if(CUE_2.test(lines[i])){
					matches = CUE_2.exec(lines[i]);
					start += parseTime(matches[2]);
					end += parseTime(matches[3]);
					text = matches[4];
					text += '\n' + matches[5];
				}else if(CUE_1.test(lines[i])){
					matches = CUE_1.exec(lines[i]);
					start += parseTime(matches[2]);
					end += parseTime(matches[3]);
					text = matches[4];
				}else{
					if(!EMPTY_CUE.test(lines[i])){
						i++;
						continue;
					}
					
					matches = EMPTY_CUE.exec(lines[i]);
					start += parseTime(matches[2]);
					end += parseTime(matches[3]);
					text = '';
				}
				
				subtitlesVO.addSubtitlesItem(new SubtitlesItemVO(start, end - start, text));
				
				i++;
			}while(i < lines.length);
			
			_off += 10;
			
			subtitlesVO.sort();
			return subtitlesVO;
		}
		
		private static function parseTime(time:String):Number {
			if(!TIMESTAMP.test(time)){
				return NaN;
			}
			
			var time_a:Array = TIMESTAMP.exec(time);
			var result:Number = time_a[4]/1000;
			result += parseInt(time_a[3]);
			
			if(time_a[2])
				result += time_a[2] * 60;
			
			if(time_a[1])
				result += time_a[1] * 60 * 60;
			
			return result;
		}
		
	}
	
}
