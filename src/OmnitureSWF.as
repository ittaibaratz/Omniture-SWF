/**
 * Brightcove Omniture SWF 1.1.0 (2 SEPTEMBER 2011)
 *
 * REFERENCES:
 *	 Website: http://opensource.brightcove.com
 *	 Source: http://github.com/brightcoveos
 *
 * AUTHORS:
 *	 Brandon Aaskov <baaskov@brightcove.com>
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the “Software”),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, alter, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to
 * whom the Software is furnished to do so, subject to the following conditions:
 *   
 * 1. The permission granted herein does not extend to commercial use of
 * the Software by entities primarily engaged in providing online video and
 * related services.
 *  
 * 2. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT ANY WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, SUITABILITY, TITLE,
 * NONINFRINGEMENT, OR THAT THE SOFTWARE WILL BE ERROR FREE. IN NO EVENT
 * SHALL THE AUTHORS, CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY WHATSOEVER, WHETHER IN AN ACTION OF
 * CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH
 * THE SOFTWARE OR THE USE, INABILITY TO USE, OR OTHER DEALINGS IN THE SOFTWARE.
 *  
 * 3. NONE OF THE AUTHORS, CONTRIBUTORS, NOR BRIGHTCOVE SHALL BE RESPONSIBLE
 * IN ANY MANNER FOR USE OF THE SOFTWARE.  THE SOFTWARE IS PROVIDED FOR YOUR
 * CONVENIENCE AND ANY USE IS SOLELY AT YOUR OWN RISK.  NO MAINTENANCE AND/OR
 * SUPPORT OF ANY KIND IS PROVIDED FOR THE SOFTWARE.
 */
 
package {
	import com.brightcove.api.APIModules;
	import com.brightcove.api.CustomModule;
	import com.brightcove.api.dtos.VideoCuePointDTO;
	import com.brightcove.api.dtos.VideoDTO;
	import com.brightcove.api.events.AdEvent;
	import com.brightcove.api.events.CuePointEvent;
	import com.brightcove.api.events.EmbedCodeEvent;
	import com.brightcove.api.events.ExperienceEvent;
	import com.brightcove.api.events.MediaEvent;
	import com.brightcove.api.events.MenuEvent;
	import com.brightcove.api.events.ShortenedLinkEvent;
	import com.brightcove.api.modules.AdvertisingModule;
	import com.brightcove.api.modules.CuePointsModule;
	import com.brightcove.api.modules.ExperienceModule;
	import com.brightcove.api.modules.MenuModule;
	import com.brightcove.api.modules.SocialModule;
	import com.brightcove.api.modules.VideoPlayerModule;
	import com.brightcove.opensource.DataBinder;
	import com.brightcove.opensource.OmnitureEventsMap;
	import com.omniture.AppMeasurement;
	
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.utils.Timer;

	public class OmnitureSWF extends CustomModule
	{	
		private var _experienceModule:ExperienceModule;
		private var _videoPlayerModule:VideoPlayerModule;
		private var _advertisingModule:AdvertisingModule;
		private var _socialModule:SocialModule;
		private var _menuModule:MenuModule;
		private var _cuePointsModule:CuePointsModule;
		private var _omniture:AppMeasurement = new AppMeasurement();
		private var _eventsMap:OmnitureEventsMap = new OmnitureEventsMap();
		private var _binder:DataBinder = new DataBinder();

		private var _debug:Boolean = false;
		private var _currentVideo:VideoDTO;
		private var _customID:String;
		private var _trackingInfo:Object;
		private var _currentVolume:Number;

		private var _currentPosition:Number;
		private var _previousTimestamp:Number;
		private var _timeWatched:Number;
		private var _mediaBegin:Boolean = false;
		private var _mediaComplete:Boolean = false;
		private var _videoMuted:Boolean = false;
		private var _trackSeekForward:Boolean = false;
		private var _trackSeekBackward:Boolean = false;
		private var _positionBeforeSeek:Number;
		private var _seekCheckTimer:Timer = new Timer(1000);

		public function OmnitureSWF():void
		{
			trace("@project OmnitureSWF");
			trace("@author Brandon Aaskov");
			trace("@version 1.1.0");
		}

		//---------------------------------------------------------------------------------------------- INITIALIZATION
		override protected function initialize():void
		{			
			_experienceModule = player.getModule(APIModules.EXPERIENCE) as ExperienceModule;
			_videoPlayerModule = player.getModule(APIModules.VIDEO_PLAYER) as VideoPlayerModule;
			_advertisingModule = player.getModule(APIModules.ADVERTISING) as AdvertisingModule;
			_socialModule = player.getModule(APIModules.SOCIAL) as SocialModule;
			_menuModule = player.getModule(APIModules.MENU) as MenuModule;
			_cuePointsModule = player.getModule(APIModules.CUE_POINTS) as CuePointsModule;

			//initialization of some important variables
			setupEventListeners();			
			_currentVideo = _videoPlayerModule.getCurrentVideo();
			_currentVolume = _videoPlayerModule.getVolume();
			_debug = (getParamValue("debug") == "true") ? true : false;
			
			/*
			Look for an eventsMap XML file URL. If it exists, load it and use that for the _eventsMap. When the 'complete' 
			handler fires, we can configure the actionsource object and anything else that relies on the _eventsMap being 
			populated. If there isn't an XML file, we must be using the compiled XML file, in which case we can just 
			manually call the onEventsMapParsed handler and it will configure everything straight away.
			*/
			var xmlFileURL:String = getParamValue('eventsMap');
			if(xmlFileURL)
			{
				_eventsMap = new OmnitureEventsMap(xmlFileURL);
				_eventsMap.addEventListener(Event.COMPLETE, onEventsMapParsed);
			}
			else
			{
				onEventsMapParsed(null);
			}
			
			
			/*
			Since Flash doesn't have an "unload" event, when a user leaves the page without letting the Media 
			object close, Omniture stores that information until the user returns, at which point it's tracked. 
			If you want to send that information right when the user closes the page, make a JavaScript call 
			into the player and call onOmnitureUnload and the Media object will be closed when the page is.
			*/
			if(ExternalInterface.available)
			{
				ExternalInterface.addCallback("onOmnitureUnload", onOmnitureUnload);
			}
			else
			{
				debug("ExternalInterface is not available");
			}
		}

		private function setupEventListeners():void
		{
			_experienceModule.addEventListener(ExperienceEvent.ENTER_FULLSCREEN, onEnterFullScreen);
			_experienceModule.addEventListener(ExperienceEvent.EXIT_FULLSCREEN, onExitFullScreen);

			_videoPlayerModule.addEventListener(MediaEvent.CHANGE, onMediaChange);
			_videoPlayerModule.addEventListener(MediaEvent.BEGIN, onMediaBegin);
			_videoPlayerModule.addEventListener(MediaEvent.PLAY, onMediaPlay);
			_videoPlayerModule.addEventListener(MediaEvent.PROGRESS, onMediaProgress);
			_videoPlayerModule.addEventListener(MediaEvent.SEEK, onMediaSeek);
			_videoPlayerModule.addEventListener(MediaEvent.STOP, onMediaStop);
			_videoPlayerModule.addEventListener(MediaEvent.COMPLETE, onMediaComplete);
			_videoPlayerModule.addEventListener(MediaEvent.MUTE_CHANGE, onMuteChange);
			_videoPlayerModule.addEventListener(MediaEvent.VOLUME_CHANGE, onVolumeChange);
			_videoPlayerModule.addEventListener(MediaEvent.RENDITION_CHANGE_REQUEST, onRenditionChangeRequest);
			_videoPlayerModule.addEventListener(MediaEvent.RENDITION_CHANGE_COMPLETE, onRenditionChangeComplete);

			if(_advertisingModule)
			{
				_advertisingModule.addEventListener(AdEvent.AD_START, onAdStart);
				_advertisingModule.addEventListener(AdEvent.AD_PAUSE, onAdPause);
				_advertisingModule.addEventListener(AdEvent.AD_RESUME, onAdResume);
				_advertisingModule.addEventListener(AdEvent.EXTERNAL_AD, onExternalAd);
				_advertisingModule.addEventListener(AdEvent.AD_COMPLETE, onAdComplete);
				_advertisingModule.addEventListener(AdEvent.AD_CLICK, onAdClick);
				_advertisingModule.addEventListener(AdEvent.AD_POSTROLLS_COMPLETE, onAdPostrollsComplete);
			}

			_socialModule.addEventListener(EmbedCodeEvent.EMBED_CODE_RETRIEVED, onEmbedCodeRetrieved);
			_socialModule.addEventListener(ShortenedLinkEvent.LINK_GENERATED, onLinkGenerated);

			_menuModule.addEventListener(MenuEvent.COPY_CODE, onCopyCode);
			_menuModule.addEventListener(MenuEvent.COPY_LINK, onCopyLink);
			_menuModule.addEventListener(MenuEvent.BLOG_POST_CLICK, onBlogPostClick);
			_menuModule.addEventListener(MenuEvent.MENU_PAGE_OPEN, onMenuPageOpen);
			_menuModule.addEventListener(MenuEvent.MENU_PAGE_CLOSE, onMenuPageClose);
			_menuModule.addEventListener(MenuEvent.SEND_EMAIL_CLICK, onSendEmailClick);

			_cuePointsModule.addEventListener(CuePointEvent.CUE, onCuePoint);
		
			_seekCheckTimer.addEventListener(TimerEvent.TIMER, onSeekCheckTimer);
		}

		private function configureOmnitureDefaults():void
		{
			/* Specify the Report Suite ID(s) to track here */
			_omniture.account = _eventsMap.reportSuites;
			var paramAccountList:String = getParamValue("account");
			if(paramAccountList)
			{
				_omniture.account = paramAccountList;
			}
			debug("Account ID(s) is " + _omniture.account);

			/* Turn on and configure debugging here */
			_omniture.debugTracking = true;
			_omniture.trackLocal = true;

			/* You may add or alter any code config here */
			_omniture.pageName = _binder.getValue(_eventsMap.pageName, _experienceModule);
			_omniture.pageURL = _binder.getValue(_eventsMap.pageURL, _experienceModule);
			_omniture.charSet = _eventsMap.charSet;
			_omniture.currencyCode = _eventsMap.currencyCode;

			/* Turn on and configure ClickMap tracking here */
			_omniture.trackClickMap = _eventsMap.trackClickMap;

			/* WARNING: Changing any of the below variables will cause drastic changes
			to how your visitor data is collected.  Changes should only be made
			when instructed to do so by your account manager.*/
			if(_eventsMap.visitorNamespace)
			{
				_omniture.visitorNamespace = _eventsMap.visitorNamespace;
			}
			else
			{
				throw new Error("Please add the visitorNamespace information to your events map XML file");
			}

			if(_eventsMap.trackingServer) 
			{
				_omniture.trackingServer = _eventsMap.trackingServer;	
			}
			else
			{
				throw new Error("Please add the trackingServer information to your events map XML file");
			}

            addChild(_omniture);
		}


		//---------------------------------------------------------------------------------------------- EXPERIENCE EVENTS
		private function onEnterFullScreen(event:ExperienceEvent):void
		{
			var trackingInfo:Object = findEventInformation("enterFullScreen", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		private function onExitFullScreen(event:ExperienceEvent):void
		{
			var trackingInfo:Object = findEventInformation("exitFullScreen", _eventsMap.map, _currentVideo);

			trackEvent(trackingInfo);
		}

		//---------------------------------------------------------------------------------------------- VIDEO PLAYER EVENTS
		private function onMediaChange(event:MediaEvent):void
		{
			_mediaBegin = false;
			_mediaComplete = false;

			updateVideoInfo(); //this doesn't always fire, so we also update in onMediaBegin
		}

		private function onMediaBegin(event:MediaEvent):void
		{
			if(!_mediaBegin)
			{				
				updateVideoInfo();

				debug("Opening Media object.");

				_omniture.Media.open(_customID, _currentVideo.length, _experienceModule.getPlayerName());
				_omniture.Media.play(_customID, 0);

				var trackingInfo:Object = findEventInformation("mediaBegin", _eventsMap.map, _currentVideo);
				trackEvent(trackingInfo);

				_mediaBegin = true;
				_mediaComplete = false;
			}
		}

		private function onMediaPlay(event:MediaEvent):void
		{
			if(!_mediaBegin)
			{
				onMediaBegin(event);
			}
			else
			{
				//unpause
				_omniture.Media.play(_customID, event.position);

				var trackingInfo:Object = findEventInformation("mediaResume", _eventsMap.map, _currentVideo);
				trackEvent(trackingInfo);
			}
		}

		private function onMediaProgress(event:MediaEvent):void
		{
			_currentPosition = event.position;
			updateTrackedTime();	

			/*
			This will track the media complete event when the user has watched 98% or more of the video. 
			Why do it this way and not use the Player API's event? The mediaComplete event will 
			only fire once, so if a video is replayed, it won't fire again. Why 98%? If the video's 
			duration is 3 minutes, it might really be 3 minutes and .145 seconds (as an example). When 
			we track the position here, there's a very high likelihood that the current position will 
			never equal the duration's value, even when the video gets to the very end. We use 98% since 
			short videos may never see 99%: if the position is 15.01 seconds and the video's duration 
			is 15.23 seconds, that's just over 98% and that's not an unlikely scenario. If the video is 
			long-form content (let's say an hour), that leaves 1.2 minutes of video to play before the 
			true end of the video. However, most content of that length has credits where a user will 
			drop off anyway, and in most cases content owners want to still track that as a media 
			complete event. Feel free to change this logic as needed, but do it cautiously and test as 
			much as you possibly can!
			*/
			if(event.position/event.duration > .98 && !_mediaComplete)
			{
				onMediaComplete(event);
			}
		}

		private function onMediaSeek(event:MediaEvent):void
		{
			if(!_positionBeforeSeek)
			{
				_positionBeforeSeek = _currentPosition;
			}

			if(event.position > _positionBeforeSeek)
			{
				_trackSeekForward = true;
				_trackSeekBackward = false;
			}
			else
			{
				_trackSeekForward = false;
				_trackSeekBackward = true;
			}

			_seekCheckTimer.stop();
			_seekCheckTimer.start();
		}

		private function onMediaStop(event:MediaEvent):void
		{
			if(!_mediaComplete)
			{
				//pause
				_omniture.Media.stop(_customID, event.position);

				var trackingInfo:Object = findEventInformation("mediaPause", _eventsMap.map, _currentVideo);
				trackEvent(trackingInfo);
			}
		}

		private function onMediaComplete(event:MediaEvent):void
		{
			if(!_mediaComplete)
			{
				debug("Closing media object.");

				var trackingInfo:Object = findEventInformation("mediaComplete", _eventsMap.map, _currentVideo);
				trackEvent(trackingInfo);

				_omniture.Media.close(_customID);

				_mediaBegin = false;
				_mediaComplete = true;
			}
		}

		private function onMuteChange(event:MediaEvent):void
		{
			var trackingInfo:Object;

			if(_videoPlayerModule.getVolume() > 0)
			{
				_videoMuted = false;

				trackingInfo = findEventInformation("mediaMuted", _eventsMap.map, _currentVideo);
				trackEvent(trackingInfo);
			}
			else
			{
				_videoMuted = true;

				trackingInfo = findEventInformation("mediaUnmuted", _eventsMap.map, _currentVideo);
				trackEvent(trackingInfo);
			}
		}

		private function onVolumeChange(event:MediaEvent):void
		{
			_videoMuted = false;

			if(_videoPlayerModule.getVolume() !== _currentVolume) //have to check this, otherwise the event fires twice for some reason
			{
				_currentVolume = _videoPlayerModule.getVolume();

				var trackingInfo:Object = findEventInformation("volumeChanged", _eventsMap.map, _currentVideo);
				trackEvent(trackingInfo);
			}
		}

		private function onRenditionChangeRequest(event:MediaEvent):void
		{
			var trackingInfo:Object = findEventInformation("renditionChangeRequest", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		private function onRenditionChangeComplete(event:MediaEvent):void
		{
			var trackingInfo:Object = findEventInformation("renditionChangeComplete", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		//---------------------------------------------------------------------------------------------- ADVERTISING EVENTS
		private function onAdStart(event:AdEvent):void
		{			
			var trackingInfo:Object = findEventInformation("adStart", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		private function onAdPause(event:AdEvent):void
		{
			var trackingInfo:Object = findEventInformation("adPause", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		private function onAdResume(event:AdEvent):void
		{
			var trackingInfo:Object = findEventInformation("adResume", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		private function onExternalAd(event:AdEvent):void
		{
			var trackingInfo:Object = findEventInformation("externalAd", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		private function onAdComplete(event:AdEvent):void
		{
			var trackingInfo:Object = findEventInformation("adComplete", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		private function onAdClick(event:AdEvent):void
		{
			var trackingInfo:Object = findEventInformation("adClick", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		private function onAdPostrollsComplete(event:AdEvent):void
		{
			var trackingInfo:Object = findEventInformation("adPostrollsComplete", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		//---------------------------------------------------------------------------------------------- SOCIAL EVENTS
		private function onEmbedCodeRetrieved(event:EmbedCodeEvent):void
		{
			var trackingInfo:Object = findEventInformation("embedCodeRetrieved", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		private function onLinkGenerated(event:ShortenedLinkEvent):void
		{	
			var trackingInfo:Object = findEventInformation("linkGenerated", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		//---------------------------------------------------------------------------------------------- MENU EVENTS
		private function onCopyCode(event:MenuEvent):void
		{
			var trackingInfo:Object = findEventInformation("codeCopied", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		private function onCopyLink(event:MenuEvent):void
		{
			var trackingInfo:Object = findEventInformation("linkCopied", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		private function onBlogPostClick(event:MenuEvent):void
		{
			var trackingInfo:Object = findEventInformation("blogPosted", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		private function onMenuPageOpen(event:MenuEvent):void
		{
			var trackingInfo:Object = findEventInformation("menuPageOpened", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		private function onMenuPageClose(event:MenuEvent):void
		{
			var trackingInfo:Object = findEventInformation("menuPageClosed", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		private function onSendEmailClick(event:MenuEvent):void
		{
			var trackingInfo:Object = findEventInformation("emailSent", _eventsMap.map, _currentVideo);
			trackEvent(trackingInfo);
		}

		//---------------------------------------------------------------------------------------------- CUE POINT EVENTS
		private function onCuePoint(event:CuePointEvent):void
		{
			var cuePoint:VideoCuePointDTO = event.cuePoint;
			var trackingInfo:Object = {};

			if(cuePoint.type == 1 && cuePoint.name == "omniture-milestone")
            {   
            	var metadataSplit:Array;

            	if(cuePoint.metadata.indexOf('%') !== -1) //percentage
            	{
            		metadataSplit = cuePoint.metadata.split('%');
            		trackingInfo = findEventInformation("milestone", _eventsMap.map, _currentVideo, "percent", metadataSplit[0]);
            		
            		_cuePointsModule.removeCodeCuePointsAtTime(_currentVideo.id, cuePoint.time);
            	}
            	else if(cuePoint.metadata.indexOf('s') !== -1) //seconds
            	{
            		metadataSplit = cuePoint.metadata.split('s');
            		trackingInfo = findEventInformation("milestone", _eventsMap.map, _currentVideo, "time", metadataSplit[0]);
            		
            		_cuePointsModule.removeCodeCuePointsAtTime(_currentVideo.id, cuePoint.time);
            	}

                trackEvent(trackingInfo);
            }
		}

		//---------------------------------------------------------------------------------------------- LOCAL OBJECT EVENTS
		private function onEventsMapParsed(event:Event):void
		{
			configureOmnitureDefaults();
		}
		
		private function onSeekCheckTimer(event:TimerEvent):void
		{
			if(_trackSeekBackward || _trackSeekForward)
			{
				var eventName:String = (_trackSeekForward) ? "seekForward" : "seekBackward";

				var trackingInfo:Object = findEventInformation(eventName, _eventsMap.map, _currentVideo);
				trackEvent(trackingInfo);

				//reset values
				_trackSeekForward = false;
				_trackSeekBackward = false;
				_positionBeforeSeek = new Number();
			}

			_seekCheckTimer.stop();
		}




		//---------------------------------------------------------------------------------------------- HELPER FUNCTIONS
		private function trackEvent(pTrackingInfo:Object, mediaTrack:Boolean = true):void
		{					
			if(pTrackingInfo) //omniture won't send anything anyway, but I'm checking to make sure this isn't null just to be sure
			{
				setupActionsourceVariables(pTrackingInfo);
		
				if(mediaTrack)
				{
					_omniture.Media.track(_customID);
				}
		
				_omniture.events = ""; //clearing the events to prevent any from firing twice and reporting incorrect numbers
			}
		}

		private function updateVideoInfo():void
		{
			_currentVideo = _videoPlayerModule.getCurrentVideo();
			_customID = getCustomVideoName(_currentVideo);

			if(!_mediaBegin) //we only want to call this once per video
			{
				createCuePoints(_eventsMap.milestones, _currentVideo);
			}
		}

		/**
		 * Keeps track of the aggregate time the user has been watching the video. If a user watches 10 seconds, 
		 * skips forward, watches another 10 seconds, skips again and watches 30 more seconds, the _timeWatched 
		 * will track as 50 seconds when the mediaComplete event fires. 
		 */ 
		private function updateTrackedTime():void
		{
			var currentTimestamp:Number = new Date().getTime();
			var timeElapsed:Number = (currentTimestamp - _previousTimestamp)/1000;
			_previousTimestamp = currentTimestamp;

			//check if it's more than 2 seconds in case the user paused or changed their local time or something
			if(timeElapsed < 2) 
			{
				_timeWatched += timeElapsed;
			} 
		}

		private function setupActionsourceVariables(pTrackingInfo:Object):void
		{
			var actionsourceEvents:String = "";
			var whatToTrack:Array = new Array();

			for(var trackType:Object in pTrackingInfo)
			{
				//takes the prop and evars objects and tacks on the proper number and assigns the proper value
				if(trackType == 'prop' || trackType == 'eVar')
				{
					for(var property:* in pTrackingInfo[trackType])
					{
						var propertyValue:String = pTrackingInfo[trackType][property]; //e.g. value for prop5
						_omniture[trackType + property] = propertyValue; //e.g. _omniture['prop5']

						whatToTrack.push(trackType + property); //e.g. prop5

						debug(trackType + " to track: " + trackType + property + ' = ' + propertyValue);
					}
				}
				else if(trackType == 'event')
				{
					var eventNumbers:String = pTrackingInfo[trackType];
					var events:Array = eventNumbers.split(',');

					if(events.length > 0)
					{
						whatToTrack.push('events');

						//takes the events array and creates a string like: event11,event12,event13
						for(var i:uint = 0; i < events.length; i++)
						{
							if(i > 0)
							{
								actionsourceEvents += ",";
							}
							actionsourceEvents += String(trackType + events[i]);
						}

						_omniture.events = actionsourceEvents;
						_omniture.Media.trackEvents = actionsourceEvents;
					}
				}
			}

			debug("What to track: " + whatToTrack.join(','));
			_omniture.Media.trackVars = whatToTrack.join(',');
		}

        private function createCuePoints(milestones:Array, video:VideoDTO):void
        {
        	if(milestones)
			{
	        	var cuePoints:Array = new Array();
	        	
				for(var i:uint = 0; i < milestones.length; i++)
				{
					var milestone:Object = milestones[i];
					var cuePoint:Object = {};
	
					if(milestone.type == 'percent')
					{
						cuePoint = {
							type: 1, //code cue point
							name: "omniture-milestone",
							metadata: milestone.marker + "%", //percent
							time: (video.length/1000) * (milestone.marker/100)
						};
					}
					else if(milestone.type == 'time')
					{
						cuePoint = {
							type: 1, //code cue point
							name: "omniture-milestone",
							metadata: milestone.marker + "s", //seconds
							time: milestone.marker
						};
					}
	
					cuePoints.push(cuePoint);
				}
				
				//clear out existing omniture cue points if they're still around after replay
				var existingCuePoints:Array = _cuePointsModule.getCuePoints(video.id);
				if(existingCuePoints)
				{
					for(var j:uint = 0; j < existingCuePoints.length; j++)
					{
						var existingCuePoint:VideoCuePointDTO = existingCuePoints[j];
						if(existingCuePoint.type == 1 && existingCuePoint.name == 'omniture-milestone')
						{
							_cuePointsModule.removeCodeCuePointsAtTime(video.id, existingCuePoint.time);
						}
					}
				}
				
				_cuePointsModule.addCuePoints(video.id, cuePoints);
			}
        }

        private function findEventInformation(eventName:String, map:Array, video:VideoDTO, milestoneType:String = null, milestoneMarker:uint = 0):Object
 		{
 			for(var i:uint = 0; i < map.length; i++)
			{
				//sets up shell object for the tracking info so we can easily add values to each inner object
				var eventInfo:Object = {
					prop: {},
					eVar: {},
					event: null
				};

				var props:Array = map[i].props;
				var eVars:Array = map[i].eVars;
				eventInfo.event = map[i].events; //just add the events as an array

				eventName = eventName.toLowerCase(); //if you have to trim this, it means you fat fingered something in the code somewhere
				var mappedEventName:String = trim(map[i].name.toLowerCase(), ' ');

				//if it's a milestone, head into the first inner if block. or enter if the argument name passed in matches the mapped event name
				if(eventName == "milestone" || eventName == mappedEventName)
				{
					if(eventName == "milestone")
					{
						for(var l:uint = 0; l < _eventsMap.milestones.length; l++)
						{
							var milestone:Object = _eventsMap.milestones[l];

							if(milestone.type.toLowerCase() == milestoneType.toLowerCase() && milestone.marker == milestoneMarker)
							{
								props = milestone.props;
								eVars = milestone.eVars;
								eventInfo.event = milestone.events;

								break;
							}							
						}
					}

					//add prop numbers as the key, and their value as the value
					for(var j:uint = 0; j < props.length; j++)
					{
						var prop:Object = props[j];						
						eventInfo.prop[prop.number] = _binder.getValue(prop.value, _experienceModule, _currentVideo);
					}

					//add evar numbers as the key, and their value as the value
					for(var k:uint = 0; k < eVars.length; k++)
					{	
						var eVar:Object = eVars[k];												
						eventInfo.eVar[eVar.number] = _binder.getValue(eVar.value, _experienceModule, _currentVideo);
					}

					return eventInfo;
				}
			}

			return null;
 		}

 		public function getCustomVideoName(video:VideoDTO):String
		{
			return video.id + " | " + video.displayName;
		}

		public function onOmnitureUnload():void
		{
			_omniture.Media.close(_customID);
		}		

		private function debug(message:String):void
		{
			_experienceModule.debug("Omniture: " + message);
		}

		private function getParamValue(key:String):String
		{
			//1: check url params for the value
			var url:String = _experienceModule.getExperienceURL();
			if(url.indexOf("?") !== -1)
			{
				var urlParams:Array = url.split("?")[1].split("&");
				for(var i:uint = 0; i < urlParams.length; i++)
				{
					var keyValuePair:Array = urlParams[i].split("=");
					if(keyValuePair[0] == key)
					{
						return keyValuePair[1];
					}
				}
			}

			//2: check player params for the value
			var playerParam:String = _experienceModule.getPlayerParameter(key);
			if(playerParam)
			{
				return playerParam;
			}

			//3: check plugin params for the value
			var pluginParams:Object = LoaderInfo(this.root.loaderInfo).parameters;
			for(var param:String in pluginParams)
			{
				if(param == key)
				{
					return pluginParams[param];
				}
			}

			return null;
		}

		//string helpers pulled from the AS3 docs
		public function trim(str:String, char:String):String 
		{
			return trimBack(trimFront(str, char), char);
		}

		public function trimFront(str:String, char:String):String 
		{
			char = stringToCharacter(char);
			if(str.charAt(0) == char)
			{
				str = trimFront(str.substring(1), char);
			}

			return str;
		}

		public function trimBack(str:String, char:String):String 
		{
			char = stringToCharacter(char);

			if(str.charAt(str.length - 1) == char) 
			{
				str = trimBack(str.substring(0, str.length - 1), char);
			}
			return str;
		}

		public function stringToCharacter(str:String):String 
		{
        	if(str.length == 1) 
        	{
            	return str;
        	}
        	return str.slice(0, 1);
    	}
	}
}
