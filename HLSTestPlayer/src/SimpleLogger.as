package
{
	import org.osmf.logging.Logger;
	
	/**
	 * ...
	 * @author HANGIL LEE
	 */
	public class SimpleLogger extends Logger 
	{
		private var className:String;
		
		public function SimpleLogger(category:String)
		{
			super(category);
			var arr:Array = category.split(".");
			className = arr[arr.length - 1];
		}
		
		override public function debug(message:String, ... rest):void
        {
            trace("D [" + className + "] " + message);
        }
		
		override public function info(message:String, ... rest):void
        {
            trace("I [" + className + "] " + message);
        }
		
		override public function warn(message:String, ... rest):void
        {
            trace("W [" + className + "] " + message);
        }
		
		override public function error(message:String, ... rest):void
        {
            trace("E [" + className + "] " + message);
        }
		
		override public function fatal(message:String, ... rest):void
        {
            trace("F [" + className + "] " + message);
        }
	}

}