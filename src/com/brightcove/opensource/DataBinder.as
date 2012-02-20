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
			var propStart:int;
			var propEnd:int;
			var idx:int =0;
			
			while ((propStart = property.indexOf("{")) !== -1 && 
					(propEnd = property.indexOf("}")) > propStart && idx<10)
			{
				idx++; // Avoid loops.
				var dataBindingValue:String = property.substring(propStart, propEnd+1); //strip off the curly braces
				var dataBindingStripped:String = dataBindingValue.substring(1,dataBindingValue.length-1); 
				var propertySplit:Array = dataBindingStripped.split('.');
				var value:String = "unknown";
				
				if(propertySplit[0].toLowerCase() == 'video')
				{
					value = getVideoProperty(propertySplit, video);
				}
				else if(propertySplit[0].toLowerCase() == 'experience')
				{
					value = getExperienceProperty(propertySplit, experienceModule);
				}

				property = property.replace(dataBindingValue,value);
			}
			
			return property;
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