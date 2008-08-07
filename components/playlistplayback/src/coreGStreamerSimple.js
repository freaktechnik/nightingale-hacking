/*
//
// BEGIN SONGBIRD GPL
//
// This file is part of the Songbird web player.
//
// Copyright(c) 2005-2008 POTI, Inc.
// http://songbirdnest.com
//
// This file may be licensed under the terms of of the
// GNU General Public License Version 2 (the "GPL").
//
// Software distributed under the License is distributed
// on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either
// express or implied. See the GPL for the specific language
// governing rights and limitations.
//
// You should have received a copy of the GPL along with this
// program. If not, go to http://www.gnu.org/licenses/gpl.html
// or write to the Free Software Foundation, Inc.,
// 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
//
// END SONGBIRD GPL
//
 */

/**
 * \file coreGStreamerSimple.js
 * \brief The CoreWrapper implementation for the GStreamer simple component
 * \sa sbICoreWrapper.idl coreBase.js
 */

Components.utils.import("resource://app/jsmodules/StringUtils.jsm");

// Helper function to get a platform string.
function getPlatformString() 
{
  try {
    var sysInfo =
      Components.classes["@mozilla.org/system-info;1"]
                .getService(Components.interfaces.nsIPropertyBag2);
    return sysInfo.getProperty("name");
  }
  catch (e) {
    var user_agent = navigator.userAgent;
    if (user_agent.indexOf("Windows") != -1)
      return "Windows_NT";
    else if (user_agent.indexOf("Mac OS X") != -1)
      return "Darwin";
    else if (user_agent.indexOf("Linux") != -1)
      return "Linux";
    else if (user_agent.indexOf("SunOS") != -1)
      return "SunOS";
    return "Unknown";
  }
}

/**
 * \class CoreGStreamerSimple
 * \brief The CoreWrapper for the simple GStreamer Simple component
 * \sa CoreBase
 */
function CoreGStreamerSimple()
{
  this._object = null;
  this._url = "";
  this._id = "";
  this._paused  = false;
  this._oldVolume = 0;
  this._muted = false;

  // Extensions we support in 'full' mode.
  this._mediaUrlExtensions = ["mp3", "ogg", "flac", "mpc", "wav", "m4a", "m4v",
                              "wmv", "asf", "avi",  "mov", "mpg", "mp4", "ogm",
                              "mp2", "mka", "mkv",  "oga", "ogv", "ogx", "wv"];

  // Set of extensions to support in 'minimal' mode.
  this._mediaUrlMinimalExtensions = ["flac"];

  this._mediaUrlSchemes = ["mms", "rstp"];

  this._videoUrlExtensions = ["wmv", "asf",  "avi", "mov", "mpg", "m4v", "mp4",
                              "mp2", "mpeg", "mkv", "ogm", "ogv", "ogx"];

  this._unsupportedExtensions = [];

  this._uriChecker = null;
  this._lastPlayStart = null;
  this._hasShownHelpPrompt = false;

  var environment = Components.classes["@mozilla.org/process/environment;1"]
                              .getService(Components.interfaces.nsIEnvironment);

  // Enable for all supported formats.
  this._gstEnableAll = false;
  // Enable for only a minimal set of formats. If both are false, this core
  // is never used.
  this._gstEnableMinimal = false;
  // Has enabling all been set explicitly, or (based on platform) automatically?
  this._gstEnableAllExplicit = false;

  var platform = getPlatformString()
  if ((platform.indexOf("Windows_NT") < 0) && 
      (platform.indexOf("Darwin") < 0))
  {
    // On linux/etc, we only have a gstreamer mediacore, so support everything.
    this._gstEnableAll = true;
  }
  else {
    if (environment.exists("SB_GST_ENABLE")) {
      var enable = environment.get("SB_GST_ENABLE");
      if (enable == "all") {
        this._gstEnableAll = true;
        this._gstEnableAllExplicit = true;
      }
      else {
        // Otherwise disable completely.
        this._gstEnableAll = false;
        this._gstEnableMinimal = false;
      }
    }
    else {
      // If no environment variable is set, we default to just supporting
      // the minimal set.
      this._gstEnableMinimal = true;
    }
  }

  if (this._gstEnableAll) {
    this._mediaUrlMatcher = new ExtensionSchemeMatcher(this._mediaUrlExtensions,
                                                       this._mediaUrlSchemes);
    this._videoUrlMatcher = new ExtensionSchemeMatcher(this._videoUrlExtensions,
                                                     []);
  }
  else if (this._gstEnableMinimal) {
    this._mediaUrlMatcher = new ExtensionSchemeMatcher(
            this._mediaUrlMinimalExtensions, []);
    this._videoUrlMatcher = new ExtensionSchemeMatcher([], []);
  }
  else {
    this._mediaUrlMatcher = new ExtensionSchemeMatcher([], []);
    this._videoUrlMatcher = new ExtensionSchemeMatcher([], []);
  }

};

// inherit the prototype from CoreBase
CoreGStreamerSimple.prototype = new CoreBase();

// set the constructor so we use ours and not the one for CoreBase
CoreGStreamerSimple.prototype.constructor = CoreGStreamerSimple();

CoreGStreamerSimple.prototype.playURL = function ( aURL )
{
  this._verifyObject();
  this._checkURL(aURL);

  this._hasShownHelpPrompt = false;

  if (!aURL) {
    throw Components.results.NS_ERROR_INVALID_ARG;
  }

  aURL = this.sanitizeURL(aURL);
  this._paused = false;

  try
  {
    if(this._object.isPlaying || this._object.isPaused)
    {
      this._object.stop();
    }

    if (window.fullScreen)
    {
      window.fullScreen = !window.fullScreen;
      if (this._object.fullscreen) {
        this._object.fullscreen = false;
      }
    }

    var ioService =
      Components.classes["@mozilla.org/network/io-service;1"]
                .getService(Components.interfaces.nsIIOService);

    var uri = ioService.newURI(aURL, null, null);

    // If this is a local file, just play it
    if (uri instanceof Components.interfaces.nsIFileURL) {
      this._object.uri = aURL;
      this._object.play();
      this._lastPlayStart = new Date();
      return true;
    }
    else {
      // Resolve the network URL
      return this._resolveRedirectsAndPlay(uri);
    }

  }
  catch(e)
  {
      this.LOG(e);
  }

  return true;
};

CoreGStreamerSimple.prototype._resolveRedirectsAndPlay = function(aURI) {

  // Cancel any old checkers
  if (this._uriChecker) {
    this._uriChecker = null;
  }

  // Make a new uriChecker and initialize it
  var uriChecker =
    Components.classes["@mozilla.org/network/urichecker;1"]
              .createInstance(Components.interfaces.nsIURIChecker);

  try {
    uriChecker.init(aURI);
  } catch (e) {
    // Unknown protocols/schemes will cause this to throw an exception.
    // Those are likely to be media protocols like MMS or RTSP; let the
    // core try to handle them.
    this.playFinalURI(aURI.spec);
    return true;
  }

  // Save it away so we can cancel if necessary. Can't do this until after the
  // init call.
  this._uriChecker = uriChecker;

  // And begin the check
  uriChecker.asyncCheck(this, null);

  return true;
};

CoreGStreamerSimple.prototype.play = function ()
{
  this._verifyObject();

  this._paused = false;

  try
  {
    this._object.play();
    this._lastPlayStart = new Date();
  }
  catch(e)
  {
    this.LOG(e);
  }

  return true;
};

CoreGStreamerSimple.prototype.pause = function ()
{
  if( this._paused )
    return this._paused;

  this._verifyObject();

  try
  {
    this._object.pause();
  }
  catch(e)
  {
    this.LOG(e);
  }

  this._paused = true;

  return this._paused;
};

CoreGStreamerSimple.prototype.stop = function ()
{
  try
  {
    if (this._object)
      this._object.stop();
    this._paused = false;
  }
  catch(e)
  {
    this.LOG(e);
  }

  return true;
};

CoreGStreamerSimple.prototype.getPlaying = function ()
{
  if (!this._object)
    return false;

  var playing = (this._object.isPlaying || this._paused) && (!this._object.isAtEndOfStream);
  return playing;
};

CoreGStreamerSimple.prototype.getPlayingVideo = function ()
{
  if (!this._object)
    return false;

  return this._object.isPlayingVideo;
};

CoreGStreamerSimple.prototype.getPaused = function ()
{
  if (!this._object)
    return false;

  return this._paused;
};

CoreGStreamerSimple.prototype.getLength = function ()
{
  this._verifyObject();

  var playLength = 0;

  try
  {
    if(this._object.lastErrorCode > 0) {
      return -1;
    }
    else if(!this.getPlaying()) {
      playLength = 0;
    }
    else {
      playLength = this._object.streamLength / (1000 * 1000);
    }
  }
  catch(e)
  {
    if(e.result == Components.results.NS_ERROR_NOT_AVAILABLE)
    {
      return -1;
    }
    else
    {
      this.LOG(e);
    }
  }

  return playLength;
};

CoreGStreamerSimple.prototype.getPosition = function ()
{
  this._verifyObject();

  var curPos = 0;

  var position = -1;
  try {
    position = this._object.position;
  }
  catch (e) {
    if(e.result != Components.results.NS_ERROR_NOT_AVAILABLE) {
      Components.util.reportError(e);
    }
  }

  if(this._object.lastErrorCode > 0) {
    curPos = -1;
  }
  else if(this._object.isAtEndOfStream || !this.getPlaying()) {
    curPos = 0;
  }
  else if(position > 0) {
    curPos = Math.round(position / (1000 * 1000));
  }
  else {
    // If bufferingPercent is > 0 and < 100, we know we are trying to play
    // a remote stream that is buffering.  While this is happening,
    // subsitute playback position for the number of milliseconds since play
    // was requested.  This will make playlistplayback think that the file
    // is playing and will prevent it from thinking that there is a problem.
    if (this._object.bufferingPercent > 0 && 
        this._object.bufferingPercent < 100) {
      curPos = (new Date()) - this._lastPlayStart;
    }
  }

  return curPos;
};

CoreGStreamerSimple.prototype.setPosition = function ( pos )
{
  this._verifyObject();

  try
  {
    this._object.seek( pos * (1000 * 1000) );
  }
  catch(e)
  {
    this.LOG(e);
  }
};

CoreGStreamerSimple.prototype.getVolume = function ()
{
  this._verifyObject();

  return Math.round(this._object.volume * 255);
};

CoreGStreamerSimple.prototype.setVolume = function ( volume )
{
  this._verifyObject();

  if ((volume < 0) || (volume > 255))
    throw Components.results.NS_ERROR_INVALID_ARG;

  this._object.volume = volume / 255;
};

CoreGStreamerSimple.prototype.getMute = function ()
{
  this._verifyObject();

  return this._muted;
};

CoreGStreamerSimple.prototype.setMute = function ( mute )
{
  this._verifyObject();

  if(mute)
  {
    this._oldVolume = this.getVolume();
    this._muted = true;
  }
  else
  {
    this.setVolume(this._oldVolume);
    this._muted = false;
  }
};

CoreGStreamerSimple.prototype.getMetadata = function ( key )
{
  this._verifyObject();

  var rv;

  switch(key) {
      case "title":
        rv = this._object.title;
      break;
      case "album":
        rv = this._object.album;
      break;
      case "artist":
        rv = this._object.artist;
      break;
      case "genre":
        rv = this._object.genre;
      break;
      case "url": {
      // Special case for URL... Need to make sure we hand back a complete URI.
       var ioService =
          Components.classes[IOSERVICE_CONTRACTID].getService(nsIIOService);
        var uri;
        try {
          // See if it is a file, first.
          var file =
            Components.classes["@mozilla.org/file/local;1"]
                      .createInstance(Components.interfaces.nsILocalFile);
          file.initWithPath(this._object.uri);
          var fileHandler =
            ioService.getProtocolHandler("file")
                     .QueryInterface(Components.interfaces.nsIFileProtocolHandler);
          var url = fileHandler.getURLSpecFromFile(file);
          uri = ioService.newURI(url, null, null);
        }
        catch (err) { }
        
        if (!uri) {
          try {
            // See if it is a regular URI
            uri = ioService.newURI(this._object.uri, null, null);
          }
          catch (err) { };
        }
        
        if (uri)
          rv = uri.spec;
      }
      break;
      default:
        rv = "";
      break;
  }

  return rv;
};

CoreGStreamerSimple.prototype.goFullscreen = function ()
{
  this._verifyObject();
  window.fullScreen=!window.fullScreen;
  if (!this._object.fullscreen) 
    this._object.fullscreen = true;
  else
    this._object.fullscreen = false;
};

  
CoreGStreamerSimple.prototype.isMediaURL = function ( aURL )
{
  return this._mediaUrlMatcher.match(aURL);
}

CoreGStreamerSimple.prototype.isVideoURL = function ( aURL )
{
  return this._videoUrlMatcher.match(aURL);
}

CoreGStreamerSimple.prototype.getSupportedFileExtensions = function ()
{
  if (this._gstEnableAll)
    return new StringArrayEnumerator(this._mediaUrlExtensions);
  else if (this._gstEnableMinimal)
    return new StringArrayEnumerator(this._mediaUrlMinimalExtensions);
  else
    return new StringArrayEnumerator([]);
}

const GST_EXTENSION_SUPPORTED = 1;           /* A recognised/supported format */
const GST_EXTENSION_EXPLICITLY_SELECTED = 5; /* Recognised/supported and the user has explicitly
                                                enabled gstreamer. */
const GST_EXTENSION_UNSUPPORTED = -1;        /* We know we must not handle this */
const GST_EXTENSION_UNKNOWN = 0;             /* We don't recognise this, but let gstreamer try
                                                if there's nothing else available */

CoreGStreamerSimple.prototype.getSupportForURI = function(aURI)
{
  var extension = this.getFileExtensionFromURI(aURI);
  
  // Strip the beginning '.' if it exists and make it lowercase
  extension = extension.charAt(0) == "." ? extension.slice(1) : extension;
  extension = extension.toLowerCase();

  // TODO: do something smarter here
  if (this._gstEnableAll) {
    if (this._mediaUrlExtensions.indexOf(extension) > -1) {
      if (this._gstEnableAllExplicit)
        return GST_EXTENSION_EXPLICITLY_SELECTED;
      else
        return GST_EXTENSION_SUPPORTED;
    }
    else if (this._unsupportedExtensions.indexOf(extension) > -1)
      return GST_EXTENSION_UNSUPPORTED;
    else 
      return GST_EXTENSION_UNKNOWN; // We are the default handler for whomever.
  }
  // In minimal mode, we support a small set of formats.
  else if (this._gstEnableMinimal && 
           this._mediaUrlMinimalExtensions.indexOf(extension) > -1)
  {
    return GST_EXTENSION_SUPPORTED;
  }
  else {
    // In minimal or 'off' mode, we don't want to ever be used, even as a 
    // default.
    return GST_EXTENSION_UNSUPPORTED;
  }
  
};

CoreGStreamerSimple.prototype.onStartRequest = function(request, context)
{
  // Nothing to do here.
};

CoreGStreamerSimple.prototype.onStopRequest = function(request, context, status)
{
  if (request != this._uriChecker) {
    return;
  }

  var uriChecker = this._uriChecker
  // Clear immediately so we can't try to cancel it anymore
  this._uriChecker = null;

  var url;
  if (status == NS_BINDING_SUCCEEDED) {
    url = uriChecker.baseChannel.URI.spec;
  }
  else {
    // One common reason for this to fail is if we are redirected to a 
    // shoutcast server (they don't actually implement HTTP - just something
    // that looks superficially similar). So, if this happens, try to just play
    // the original URL, it's probably the actual shoutcast server URL and will
    // work fine - and if not, we'll just error out a bit later.
    url = uriChecker.baseChannel.originalURI.spec;
  }

  this.playFinalURI(url);
}

CoreGStreamerSimple.prototype.playFinalURI = function(uri)
{
  this._url = uri;
  this._object.uri = uri;
  this._object.play();
  this._lastPlayStart = new Date();
};

CoreGStreamerSimple.prototype.promptUserForHelp = function (dialogTitle, 
        dialogText, checkBoxLabel, helpUrl)
{
  var prefs = Components.classes["@mozilla.org/preferences-service;1"]
                        .getService(Components.interfaces.nsIPrefBranch);

  skip = prefs.getPrefType("songbird.skipGStreamerHelp") &&
         prefs.getBoolPref("songbird.skipGStreamerHelp");
  if (skip || this._hasShownHelpPrompt)
    return;

  // We only show the help prompt once per URL - so that multiple errors from
  // a single URL don't get shown (usually the latter ones are useless - e.g.
  // 'internal data flow error)
  this._hasShownHelpPrompt = true;

  var promptService = Components.classes[
      "@mozilla.org/embedcomp/prompt-service;1"]
      .getService(Components.interfaces.nsIPromptService);

  var neverPromptAgain = { value: false };

  // Get a reference to the main window.
  var windowMediator = Components.classes[
      "@mozilla.org/appshell/window-mediator;1"]
      .getService(Components.interfaces.nsIWindowMediator);
  var mainWindow = windowMediator.getMostRecentWindow("Songbird:Main")

  var promptResult = promptService.confirmEx(
          mainWindow,
          dialogTitle,
          dialogText,
          Components.interfaces.nsIPromptService.STD_YES_NO_BUTTONS,
          null, null, null, // button labels (use defaults)
          checkBoxLabel,
          neverPromptAgain);

  prefs.setBoolPref("songbird.skipGStreamerHelp", neverPromptAgain.value);

  if (promptResult == 0) {
    // User clicked 'yes' - we should show them the help webpage.
    var browserDOMWindow = mainWindow.
        getInterface(Components.interfaces.nsIWebNavigation).
        QueryInterface(Components.interfaces.nsIDocShellTreeItem).
        rootTreeItem.
        QueryInterface(Components.interfaces.nsIInterfaceRequestor).
        getInterface(Components.interfaces.nsIDOMWindow).
        QueryInterface(Components.interfaces.nsIDOMChromeWindow).
        browserDOMWindow;

    var uri =  Components.classes[
              "@mozilla.org/network/io-service;1"]
              .getService(Components.interfaces.nsIIOService)
              .newURI(helpUrl, null, null);
    browserDOMWindow.openURI(uri, null, 
            Components.interfaces.nsIBrowserDOMWindow.OPEN_NEWTAB,
            Components.interfaces.nsIBrowserDOMWindow.OPEN_EXTERNAL);
  }
}

CoreGStreamerSimple.prototype.handleUnknownType = function ()
{
  // The media type of this file couldn't be determined.
}

CoreGStreamerSimple.prototype.onGStreamerEvent = function (gstreamerEvent)
{
  // Hrm.. should we have different checkboxes/prefs for each type of error?
  var checkboxLabel = SBString("mediacorecheck.dialog.skipCheckboxLabel");
  var helpUrl = SBString("mediacore.gstreamer.plugin.helpUrl");
  var showDialog = true;

  if (gstreamerEvent.type == 
          gstreamerEvent.EVENT_ERROR_CORE_MISSING_PLUGIN)
  {
    // A (specific) plugin is missing. Probably an installation issue.
    var title = SBString("mediacore.gstreamer.plugin.missing.title");
    var text = SBFormattedString("mediacore.gstreamer.plugin.missing.text",
            [gstreamerEvent.message]);
  }
  else if (gstreamerEvent.type == 
                gstreamerEvent.EVENT_ERROR_STREAM_CODEC_NOT_FOUND)
  {
    // An appropriate plugin couldn't be found. Probably this format isn't
    // supported without downloading more plugins/addons.
    var title = SBString("mediacore.gstreamer.plugin.codecnotfound.title");
    var text = SBFormattedString(
            "mediacore.gstreamer.plugin.codecnotfound.text", 
            [gstreamerEvent.message]);
  }
  else if (gstreamerEvent.type == gstreamerEvent.EVENT_ERROR_RESOURCE_BUSY)
  {
    // Resource was busy. Usually this means that we don't have a software
    // mixer, and the hardware is busy, or there's no free Xv port for video,
    // etc.
    var title = SBString("mediacore.gstreamer.resource.busy.title");
    var text = SBFormattedString("mediacore.gstreamer.resource.busy.text", 
            [gstreamerEvent.message]);
  }
  else if (gstreamerEvent.type >= gstreamerEvent.EVENT_ERROR_RESOURCE_BASE &&
           gstreamerEvent.type < gstreamerEvent.EVENT_ERROR_STREAM_BASE)
  {
    // Some other resource error. Usually this means that the resource can't
    // be read for some reason (doesn't exist, or permissions lacking, etc).
    var title = SBString("mediacore.gstreamer.resource.error.title");
    var text = SBFormattedString("mediacore.gstreamer.resource.error.text", 
            [gstreamerEvent.message]);
  }
  else if (gstreamerEvent.type >= gstreamerEvent.EVENT_ERROR_FIRST &&
           gstreamerEvent.type <= gstreamerEvent.EVENT_ERROR_LAST)
  {
    // Some other error has occurred. No specific handling yet.
    var title = SBString("mediacore.gstreamer.generic.error.title");
    var text = SBFormattedString("mediacore.gstreamer.generic.error.text", 
            [gstreamerEvent.message]);
  }
  else {
    // Some non-error event has occurred.
    // We don't have any of these yet.
    showDialog = false;
  }

  if (showDialog)
    this.promptUserForHelp(title, text, checkboxLabel, helpUrl);
}

CoreGStreamerSimple.prototype.destroyCore = function()
{
  if (this._object != null)
    this._object.removeEventListener(this)
}

/**
  * See nsISupports.idl
  */
CoreGStreamerSimple.prototype.QueryInterface = function(iid) {
  if (!iid.equals(Components.interfaces.sbICoreWrapper) &&
      !iid.equals(Components.interfaces.sbIGStreamerEventListener) &&
      !iid.equals(nsIRequestObserver) &&
      !iid.equals(Components.interfaces.nsISupports))
    throw Components.results.NS_ERROR_NO_INTERFACE;
  return this;
};

CoreGStreamerSimple.prototype.setVideoElementId = function(id)
{
  this._videoId = id;
}

CoreGStreamerSimple.prototype.doInitialize = function()
{
  var videoElement = document.getElementById( this._videoId );
  var gstSimple = Components.classes["@songbirdnest.com/Songbird/Playback/GStreamer/Simple;1"]
                            .createInstance(Components.interfaces.sbIGStreamerSimple);
  gstSimple.init(videoElement);

  this.setObject(gstSimple);
  gstSimple.addEventListener(this)

  return true;
}

CoreGStreamerSimple.prototype.doActivate = function GST_doActivate()
{
  var videoElement = document.getElementById( this._videoId );
  if (videoElement)
    videoElement.collapsed = false;
}

CoreGStreamerSimple.prototype.doDeactivate = function GST_doDeactivate()
{
  var videoElement = document.getElementById( this._videoId );
  if (videoElement)
    videoElement.collapsed = true;
}


/**
 * ----------------------------------------------------------------------------
 * Global variables and autoinitialization.
 * ----------------------------------------------------------------------------
 */

try {
  var gGStreamerSimpleCore = new CoreGStreamerSimple();
  window.addEventListener("unload", 
          function() { gGStreamerSimpleCore.destroyCore(); }, false);
}
catch(err) {
  dump("ERROR!!! coreGStreamerSimple failed to create properly.");
}

/**
  * This is the function called from a document onload handler to bind everything as playback.
  */
function CoreGStreamerSimpleDocumentInit( id )
{
  try
  {
    var gPPS = Components.classes["@songbirdnest.com/Songbird/PlaylistPlayback;1"]
                         .getService(Components.interfaces.sbIPlaylistPlayback);
    gGStreamerSimpleCore.setId("GStreamerSimple1");
    gGStreamerSimpleCore.setVideoElementId(id);
    gPPS.addCore(gGStreamerSimpleCore, true);
    registeredCores.push(gGStreamerSimpleCore);
  }
  catch ( err )
  {
    dump( "\n!!! coreGStreamerSimple failed to bind properly\n" + err );
  }
};

