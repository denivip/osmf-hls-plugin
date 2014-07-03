package worker
{
	public class Messages
	{
		// to worker
		// main commands
		public static const BEGIN_PROCESS:String = 'begin';
		public static const PROCESS_SEGMENT:String = 'process';
		public static const END_PROCESS:String = 'end';
		public static const FLUSH:String = 'flush';
		public static const RESET:String = 'reset';
		public static const DISCONTINUITY:String = 'discontinuity';
		
		public static const OFFSET:String = 'offset';
		
		// decryption command
		public static const KEY:String = 'key';
		public static const IV:String = 'iv';
		
		// to main
		public static const READY:String = 'ready';
		public static const DONE:String = 'done';
		public static const SYNC:String = 'sync';
		public static const NOTDONE:String = 'notdone';
		
	}
}