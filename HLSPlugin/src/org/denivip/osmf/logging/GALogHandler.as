package org.denivip.osmf.logging
{
	import flash.external.ExternalInterface;

	public class GALogHandler extends LogHandler
	{
		public function GALogHandler()
		{
			super();
		}
		
		/**
		 * Just example handler for demonstrate multi-loghandler possibles.
		 * Need your own implements gaLog js-funcs
		 */
		override public function handleMessage(logMessage:LogMessage):void{
			ExternalInterface.call('gaLog', logMessage.level, logMessage.toString());
		}
	}
}