package com.brightcove.opensource
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	
	public class OmnitureEventsMap extends EventDispatcher
	{
		private var _map:Array = new Array();
		private var _milestones:Array = new Array();
		
		//account-level stuff
		private var _reportSuites:Array = new Array();
		public var visitorNamespace:String;
		public var trackingServer:String;
		public var pageName:String;
		public var pageURL:String;
		public var trackClickMap:Boolean;
		
		[Embed(source="../assets/events_map.xml", mimeType="application/octet-stream")]
		protected const EventsMap:Class;

		public function OmnitureEventsMap(xmlFileURL:String = null)
		{
			if(xmlFileURL)
			{
				var request:URLRequest = new URLRequest(xmlFileURL);
				var loader:URLLoader = new URLLoader();
				loader.addEventListener(Event.COMPLETE, onXMLFileLoaded);
				loader.load(request);
			}
			else
			{
				var byteArray:ByteArray = (new EventsMap()) as ByteArray;
				var bytes:String = byteArray.readUTFBytes(byteArray.length);
				var eventsMapXML:XML = new XML(bytes);
				eventsMapXML.ignoreWhitespace = true;
				
				parseAccountInfo(eventsMapXML);
				parseEventsMap(eventsMapXML);
				
				dispatchEvent(new Event(Event.COMPLETE));
			}
		}
		
		private function onXMLFileLoaded(event:Event):void
		{
			var eventsMapXML:XML = new XML(event.target.data);
			parseAccountInfo(eventsMapXML);
			parseEventsMap(eventsMapXML);
			
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		private function parseAccountInfo(eventsMap:XML):void
		{
			var reportSuites:XMLList = eventsMap.initialization.reportSuites.reportSuite;
			
			for(var i:uint = 0; i < reportSuites.length(); i++)
			{
				_reportSuites.push(reportSuites[i]);
			}
			
			visitorNamespace = eventsMap.initialization.visitorNamespace;
			trackingServer = eventsMap.initialization.trackingServer;
			//pageName and pageURL may both be data-binded values for the experience module; that gets handled from OmnitureSWF.as
			pageName = eventsMap.initialization.pageName;
			pageURL = eventsMap.initialization.pageURL;
			trackClickMap = (eventsMap.initialization.trackClickMap.@value == 'true') ? true : false;
		}
		
		private function parseEventsMap(eventsMap:XML):void
		{
			for(var node:String in eventsMap.events.event)
			{
				var event:XML = eventsMap.events.event[node];
				
				var eventName:String = event.@name;
				var propsXML:XMLList = event.prop;
				var eVarsXML:XMLList = event.evar;
				var eventsXML:XMLList = event.eventNumbers;
				
				var eVars:Array = new Array();
				for(var i:uint = 0; i < eVarsXML.length(); i++)
				{
					var eVarXML:XML = eVarsXML[i];
				
					eVars.push({
						number: eVarXML.@number,
						value: eVarXML.@value 
					});
				}
				
				var props:Array = new Array();
				for(var j:uint = 0; j < propsXML.length(); j++)
				{
					var propXML:XML = propsXML[j];
				
					props.push({
						number: propXML.@number,
						value: propXML.@value 
					});
				}
				
				var events:Array = new Array();
				for(var k:uint = 0; k < eventsXML.length(); k++)
				{
					var eventXML:XML = eventsXML[k];
				
					events.push(eventXML.@value);
				}
				
				var eventInfo:Object = {
					name: eventName,
					props: props,
					eVars: eVars,
					events: events
				};
				
				if(eventName == 'milestone')
				{
					var milestone:Object = {
						props: props,
						eVars: eVars,
						events: events,
						type: event.@type,
						marker: event.@value
					};
					
					_milestones.push(milestone);
				}
				
				_map.push(eventInfo);
			}
		}
		
		public function get reportSuites():String
		{
			return _reportSuites.join(',');
		}
		
		public function get map():Array
		{
			return _map;
		}
		
		public function get milestones():Array
		{
			return _milestones;
		}
	}
}