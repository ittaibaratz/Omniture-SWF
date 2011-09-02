About
=====

This project provides a Flash plug-in for reporting events from within Brightcove video players to Omniture. Reports can then be rolled up using Omniture's SiteCatalyst. It can be used out-of-the-box or as a jumping off point for customizing your analytics plug-in. By setting up an XML file, you can access all of the necessary events that fire inside the Brightcove player. You can configure that XML file to pull from any of the available video fields and player properties (see full list below), giving you much greater control over the data in your reports.

Setup
=====

There are two methods to getting your plug-in ready. The recommended option is to modify the `events_map.xml` file to match your needs and then compile your own SWF. That sounds scarier than it really is. All you need is a copy of FlashBuilder (and you can get a free trial from Adobe if need be) and you can follow the instructions below. However, if you're really averse to that or just want to get something up and running quickly, you can pass in your events map XML file as a URL parameter (there are a few different options for how to pass that in - see below). Please note that by doing it this way, you're introducing the risk of latency. If the file doesn't load up in time and the video starts, the tracking methods will not have initialized properly and information won't be tracked for that viewing. With that in mind, please make sure that if you're going to use this method to host the XML file on a CDN to mitigate the risk of latency.


Recommended: Creating Your Custom SWF
-------------------------------------
If you want to eliminate latency problems by compiling your own SWF, or if you want to make modifications to the SWF/codebase, follow these steps:

1.	Import the project into either FlexBuilder or FlashBuilder. Go to File > Import... > and under General choose "Existing Projects into Workspace." Choose the location of the project you downloaded from the [GitHub project page](https://github.com/BrightcoveOS/Omniture-SWF).

2.	Modify the events_map.xml file inside the assets folder to match your needs. See below for more instructions.

3.	Compile the SWF by using "Export Release Build..." under the Projects menu to get an optimized file size.

4.	Upload the SWF to a server that's URL addressable and make note of the URL.

5.	Log in to your Brightcove account.

6.	Edit your Brightcove player and add the URL under the "plugins" tab and save your player changes.


Optional: Using the Existing SWF 
--------------------------------
If you don't want to compile your own SWF, follow these steps (please keep in mind potential latency issues - see above):

1.	Choose the latest download from the [GitHub project's downloads page](https://github.com/BrightcoveOS/Omniture-SWF/downloads).

2.	Upload both the SWF file and `events_map.xml` file to a server that's URL addressable; make note of those URLs.

3.	At this stage you can add the reference to your events map XML file in one of a few ways:

	*	**Recommended**: Add `?eventsMap=http://mydomain.com/my-events-map.xml` to the URL of the SWF file (http://mydomain.com/my-events-map.xml will be replaced with the location of your events map XML file). For example, `http://mydomain.com/OmnitureSWF.swf?eventsMap=http://mydomain.com/my-events-map.xml`
	
	*	Instead of using the above recommended method, you could specify a parameter in the JavaScript publishing code for the player.
		`<param name="eventsMap" value="http://mydomain.com/my-events-map.xml" />`
		You could also use this method to override the XML file specified with the above method.
		
	*	It's doubtful you'll use this option for anything other than testing, but you can also pass in your events map XML file as a parameter to the URL of the page. Similar to the recommended option, you would append `?eventsMap=http://mydomain.com/my-events-map.xml` to the current URL in the browser's address bar. This option will override the above two methods if either or both are being used.

4.	Log in to your Brightcove account.

5.	Edit your Brightcove player and add the URL under the "plugins" tab.

6.	Save your player changes.


Setting Up Your Events Map XML File 
-----------------------------------
Included in each zip on the [project's downloads page](https://github.com/BrightcoveOS/Omniture-SWF/downloads) is a sample `events_map.xml` file. If you're using the recommended setup option above, *do not* change the name of the file or change its location from the assets folder. Otherwise, the name of the file can be changed. All of the available events that you can tap into are in the sample XML file. You'll even find some `event` nodes in the XML file with no child nodes. Nothing gets tracked when these events fire since there are no props, eVars or events setup for them. You can remove them entirely from the XML file if you want and get the same effect, but it's nice to have them there to remind you what's available. 

#### Account Level Settings
At the top of the sample XML file, you'll see a section called `initialization`. Inside of that is where you can specify your report suites, visitor namespace, and tracking server. If you're not sure where to find that information, you can either pull it from Flex code that you can generate from the Admin section of Site Catalyst, or simply ask Omniture's support team. The `pageName` and `pageURL` values are using data-binding, in the example file, to get properties from the Brightcove Experience (a.k.a. Brightcove Player). You can see a list of available data-binding options below if you'd like to change that. Anything wrapped in those curly braces will attempt to use data-binding to get the value you're looking for. If you enter text without curly braces, we'll just use that text. You can override the account suite(s) being used by passing in a parameter on the URL to the plugin, in the player's publishing code, or in the URL of the page. The parameter's key (or name) for overriding that will be `account` and the value can be one suite or many (separate many with commas). An example might be `http://mydomain.com/OmnitureSWF.swf?account=my-suite-name`.

#### Events
In the sample file, you'll see a long list of events. Each `event` entry can have any number of `prop`, `evar` and `eventNumbers` XML nodes inside of it. For `prop` and `evar` nodes, the `number` attribute will map to that particular prop or eVar number, and the `value` attribute will get assigned to those props and eVars. For instance, `<prop number="3" value="{video.displayName}" />` will convert to `prop3 = My Video Name` ("My Video Name" is an example of what the video's name could be). Event numbers get assigned by simply specifying whatever event number you want to use in the `value` attribute. If you want to use multiple event numbers, just separate each with a comma (no spaces).


Current Supported Data Binding Fields
=====================================
If you want to use data-binding, make sure to surround the below values with curly braces. You can even bind multiple fields for the same prop/eVar. See the events_map.xml sample file for an example. When data-binding to custom fields, you'll be using the internal name gets automatically created when you make the custom field. If you're unsure what that internal name is, please check the 'Video Fields' section under your account settings in the Brightcove Studio.

Experience Data-Bindings
------------------------
*	experience.playerName : The name of the player the plugin is currently being server from.
*	experience.url : The current URL of the page. This may not be available if using the HTML embed code.
*	experience.id : The ID of the player.
*	experience.publisherID : The ID of the publisher to which the media item belongs.
*	experience.referrerURL : The url of the referrer page where the player is loaded. 
*	experience.userCountry : The country the user is coming from.

Video Data-Bindings
-------------------
*	video.adKeys : Key/value pairs appended to any ad requests during media's playback.
*	video.customFields['customfieldname'] : Publisher-defined fields for media. 'customfieldname' would be the internal name of the custom field you wish to use.
*	video.displayName : Name of media item in the player.
*	video.economics : Flag indicating if ads are permitted for this media item.
*	video.id : Unique Brightcove ID for the media item.
*	video.length : The duration on the media item in milliseconds.
*	video.lineupId : The ID of the media collection (ie playlist) in the player containing the media, if any.
*	video.linkText : The text for a related link for the media item.
*	video.linkURL : The URL for a related link for the media item.
*	video.longDescription : Longer text description of the media item.
*	video.publisherId : The ID of the publisher to which the media item belongs.
*	video.referenceId : Publisher-defined ID for the media item.
*	video.shortDescription : Short text description of the media item.
*	video.thumbnailURL : URL of the thumbnail image for the media item.