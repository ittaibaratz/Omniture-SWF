package com.brightcove.opensource
{
	import com.brightcove.api.dtos.VideoDTO;
	import com.brightcove.api.modules.ExperienceModule;
	
	public class DataBinder
	{
		private var _currentVideo:VideoDTO;
		
		public function DataBinder()
		{
		}
		
		public function getValue(property:String, experienceModule:ExperienceModule, video:VideoDTO = null):String
		{
			if(property.indexOf("{") !== -1)
			{
				var dataBindingValue:String = property.substring(1, property.length-1); //strip off the curly braces
				var propertySplit:Array = dataBindingValue.split('.');
				
				if(propertySplit[0].toLowerCase() == 'video')
				{
					return getVideoProperty(propertySplit, video);
				}
				else if(propertySplit[0].toLowerCase() == 'experience')
				{
					return getExperienceProperty(propertySplit, experienceModule);
				}
			}
			else //not a data-binding value, so just return it
			{
				return property;
			}
			
			return null;
		}
		
		private function getVideoProperty(propertySplit:Array, video:VideoDTO):String
		{
			if(propertySplit[1].toLowerCase().indexOf('customfields[') !== -1)
			{
				var customFieldSplit:Array = propertySplit[1].split("'");
				var customFieldName:String = customFieldSplit[1].toLowerCase();
				
				return video.customFields[customFieldName];
			}
			else //not a custom field
			{
				return video[propertySplit[1]];
			}
				
			return null;
		}
		
		private function getExperienceProperty(propertySplit:Array, experienceModule:ExperienceModule):String
		{
			var experienceProperty:String = propertySplit[1].toLowerCase();
			
			switch(experienceProperty)
			{
				case 'url':
					return experienceModule.getExperienceURL();
					break;
				case 'playername':
					return experienceModule.getPlayerName();
					break;
				case 'id':
					return experienceModule.getExperienceID().toString();
					break;
				case 'publisherID':
					return experienceModule.getPublisherID().toString();
					break;
				case 'referrerURL':
					return experienceModule.getReferrerURL();
					break;
				case 'userCountry':
					return experienceModule.getUserCountry();
					break;
				default:
					return null;
			}
			
			return null;
		}
	}
}