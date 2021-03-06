{**************************************************************************************************}
{ The contents of this file are subject to the Mozilla Public License Version 1.1 (the "License"); }
{ you may not use this file except in compliance with the License. You may obtain a copy of the    }
{ License at http://www.mozilla.org/MPL/                                                           }
{                                                                                                  }
{ Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF   }
{ ANY KIND, either express or implied. See the License for the specific language governing rights  }
{ and limitations under the License.                                                               }
{                                                                                                  }
{ The Original Code is DelphiMaps.GoogleMaps.pas                                                   }
{                                                                                                  }
{ The Initial Developer of the Original Code is Wouter van Nifterick                               }
{                                              (wouter_van_nifterick@hotmail.com.                  }
{**************************************************************************************************}

{$M+}

unit DelphiMaps.GoogleMaps;

interface

uses
  Generics.Collections,
  Classes,
  Controls,
  SysUtils,
  Contnrs,
  Forms,
  StrUtils,
  Graphics,
  DelphiMaps.Browser.Event,
  RegularExpressions,
  DelphiMaps.Browser,
  DelphiMaps.DouglasPeuckers
  ;

const
  GoogleMapsFileName = 'GoogleMaps.html';
  WGS84_MULT_FACT    = 100000; // multiply lat/lon values by this value in order to fit them into integers
  DEFAULT_SIMPLIFY_TOLERANCE = 0.5;


type
  TPointFloat2D = DelphiMaps.DouglasPeuckers.TPointFloat2D;
  TGoogleMapControlType = (MC_NONE=1,MC_SMALL,MC_LARGE);
  TGoogleMapType        = (MT_ROADMAP, MT_SATELLITE, MT_TERRAIN, MT_HYBRID);
  TStaticMapType        = (ST_ROADMAP, ST_SATELLITE, ST_TERRAIN, ST_HYBRID);

const
  cGoogleMapTypeStr : Array[TGoogleMapType]of String=('ROADMAP','SATELLITE','HYBRID','TERRAIN');
  cStaticMapTypeStr : Array[TStaticMapType]of String=('roadMap','satellite','terrain','hybrid');

type
  TGoogleMaps       = class; // forward declaration

  GIcon             = class end; // to be implemented


  IGHidable=interface(IInterface)
    procedure hide;                         // Hides the object if the overlay is both currently visible and the overlay's supportsHide() method returns true. Note that this method will trigger the respective visibilitychanged event for each child overlay that fires that event (e.g. GMarker.visibilitychanged, GGroundOverlay.visibilitychanged, etc.). If no overlays are currently visible that return supportsHide() as true, this method has no effect. (Since 2.87)
    function  isHidden           : Boolean; // Returns true if the object is currently hidden, as changed by the .hide() method. Otherwise returns false.
    procedure show;                         // Shows the child overlays created by the GGeoXml object, if they are currently hidden. Note that this method will trigger the respective visibilitychanged event for each child overlay that fires that event (e.g. GMarker.visibilitychanged, GGroundOverlay.visibilitychanged). (Since 2.87)
    function  supportsHide       : Boolean; //
  end;

  TGSize = class(TJsClassWrapper)
  private
    FWidth: Double;
    FHeight: Double;
    procedure SetHeight(const Value: Double);
    procedure SetWidth(const Value: Double);
  public
    property Width:Double read FWidth write SetWidth;
    property Height:Double read FHeight write SetHeight;
    constructor Create(width,height:Double; widthUnit:string='';heightUnit:string='');reintroduce;
    function Equals(aSize: TGSize): Boolean; reintroduce;
  end;


  TGEvent = class(TJsClassWrapper)

  end;

  // marker class
  TGMarkerOptions=record
    icon          : GIcon;    // Chooses the Icon for this class. If not specified, G_DEFAULT_ICON is used. (Since 2.50)
    dragCrossMove : Boolean;  // When dragging markers normally, the marker floats up and away from the cursor. Setting this value to true keeps the marker underneath the cursor, and moves the cross downwards instead. The default value for this option is false. (Since 2.63)
    title         : String;   // This string will appear as tooltip on the marker, i.e. it will work just as the title attribute on HTML elements. (Since 2.50)
    clickable     : Boolean;  // Toggles whether or not the marker is clickable. Markers that are not clickable or draggable are inert, consume less resources and do not respond to any events. The default value for this option is true, i.e. if the option is not specified, the marker will be clickable. (Since 2.50)
    draggable     : Boolean;  // Toggles whether or not the marker will be draggable by users. Markers set up to be dragged require more resources to set up than markers that are clickable. Any marker that is draggable is also clickable, bouncy and auto-pan enabled by default. The default value for this option is false. (Since 2.61)
    bouncy        : Boolean;  // Toggles whether or not the marker should bounce up and down after it finishes dragging. The default value for this option is false. (Since 2.61)
    bounceGravity : Integer;   // When finishing dragging, this number is used to define the acceleration rate of the marker during the bounce down to earth. The default value for this option is 1. (Since 2.61)
    autoPan       : Boolean;  // Auto-pan the map as you drag the marker near the edge. If the marker is draggable the default value for this option is true. (Since 2.87)
    // to implement:
    //    zIndexProcess : Function; // This function is used for changing the z-Index order of the markers when they are overlaid on the map and is also called when their infowindow is opened. The default order is that the more southerly markers are placed higher than more northerly markers. This function is passed in the GMarker object and returns a number indicating the new z-index. (Since 2.98)
  end;

  TGPoint=class(TJsClassWrapper)
  private
    FX: Double;
    FY: Double;
    procedure SetX(const Value: Double);
    procedure SetY(const Value: Double);
    function GetX: Double;
    function GetY: Double;
  public
    function getJsClassName:String;
    function ToString: string; override;
    function Equals(P:TGPoint):Boolean;reintroduce;
    function ToJavaScript: string; override;
  published
    property X:Double read GetX write SetX;
    property Y:Double read GetY write SetY;
  end;

  TGLatLng=class(TJsClassWrapper)
  private
    FLat,
    FLng:Double;
  published
    constructor Create(aLat,aLng:Double);reintroduce;
    property Lat:Double read FLat write FLat;
    property Lng:Double read FLng write FLng;
    function ToJavaScript:String;override;
    function Equals(const AGLatLng:TGLatLng):Boolean;reintroduce;
    function Clone:TGLatLng;reintroduce;
    function ToString:String;override;
    function JsClassName:String;override;
  end;

  TGBounds=class(TJsClassWrapper)
  private
    FMinX, FMinY, FMaxX, FMaxY:Double;
    FMin,FMax,FMid:TGLatLng;
    function GetMax: TGLatLng;
    function GetMid: TGLatLng;
    function GetMin: TGLatLng;
    procedure SetJsVarName(const Value: String); reintroduce;
    function GetJsVarName: String;
  published
    destructor Destroy;override;
    property minX : Double read FMinX write FMinX;
    property minY : Double read FMinY write FMinY;
    property maxX : Double read FMaxX write FMaxX;
    property maxY : Double read FMaxY write FMaxY;
    function ToString:String;override;
    function Equals(aGBounds:TGBounds):Boolean;reintroduce;
    property Min:TGLatLng read GetMin;
    property Mid:TGLatLng read GetMid;
    property Max:TGLatLng read GetMax;
    function JsClassName:String;override;
    property JsVarName:String read GetJsVarName write SetJsVarName;
    function ToJavaScript:String;override;
  end;

  // A LatLngBounds  instance represents a rectangle in geographical coordinates,
  // including one that crosses the 180 degrees longitudinal meridian.
  TGLatLngBounds=class(TJsClassWrapper)
  private
    FNorthEast:TGLatLng;
    FSouthWest:TGLatLng;
    procedure setNorthEast(const Value: TGLatLng);
    procedure setSouthWest(const Value: TGLatLng);
    function GetJsVarName: string;
    procedure SetJsVarName(const aVarName: string);
  public
    function JsClassName: string;override;
    function ToJavaScript: string;override;
    constructor Create(sw,ne:TGLatLng);reintroduce;overload;
    constructor Create(const aJs:String);reintroduce;overload;
    constructor Create(aEast,aNorth,aWest,aSouth:Double);reintroduce;overload;
  published
    destructor Destroy;override;
    function contains(aLatLng:TGLatLng):Boolean; deprecated; //  	Returns true if the given lat/lng is in this bounds.
    function containsLatLng(aLatLng:TGLatLng):Boolean; // Returns true iff the geographical coordinates of the point lie within this rectangle. (Since 2.88)
    function intersects(aGLatLngBounds:TGLatLngBounds):Boolean;
    function containsBounds(aGLatLngBounds:TGLatLngBounds):Boolean;
    procedure Extend(aLatLng:TGLatLng); // Enlarges this rectangle such that it contains the given point. In longitude direction, it is enlarged in the smaller of the two possible ways. If both are equal, it is enlarged at the eastern boundary.
    function Union(other:TGLatLngBounds):TGLatLngBounds; // Extends this bounds to contain the union of this and the given bounds.

    function toSpan()       :	TGLatLng; //	Returns a GLatLng whose coordinates represent the size of this rectangle.
    function isFullLat()    :	Boolean ; //	Returns true if this rectangle extends from the south pole to the north pole.
    function isFullLng()    :	Boolean ; //	Returns true if this rectangle extends fully around the earth in the longitude direction.
    function isEmpty()      :	Boolean ; //	Returns true if this rectangle is empty.
    function getCenter()    :	TGLatLng; //	Returns the point at the center of the rectangle. (Since 2.52)

    function getSouthWest() :	TGLatLng; //	Returns the point at the south-west corner of the rectangle.
    function getNorthEast() :	TGLatLng; //	Returns the point at the north-east corner of the rectangle.
    property SouthWest : TGLatLng read getSouthWest write setSouthWest;
    property NorthEast : TGLatLng read getNorthEast write setNorthEast;

    function Clone:TGLatLngBounds;reintroduce;

    property JsVarName: string read GetJsVarName write SetJsVarName;
    function ToString:String;override;
    procedure FromString(const aJs:String);
    function Equals(aGLatLngBounds:TGLatLngBounds):Boolean;reintroduce;
  end;

  // abstract class.. subclassed by TGMarker and TGPolygon and TGPolyLine..
  TGOverlay = class(TJsClassWrapper, IGHidable)
  private
    FID: Integer;
    FMap: TGoogleMaps;
    FName: String;
    procedure SetID(const Value: Integer);
    procedure SetMap(const Value: TGoogleMaps);
    procedure SetName(const Value: String);
    function GetJsVarName: String;
    procedure SetJsVarName(const Value: String);
  public
    procedure hide; virtual;
    function isHidden: Boolean; virtual;
    procedure show; virtual;
    function supportsHide: Boolean; virtual;
  published
    property ID: Integer read FID write SetID;
    function ToJavaScript: String; override; abstract;
    property JsVarName: String read GetJsVarName write SetJsVarName;
    property Map: TGoogleMaps read FMap write SetMap;
    property Name: String read FName write SetName;
    function JsClassName: string; override;
  end;

  TOverlayList = class(TObjectList<TGOverlay>)
  private
    AutoIncrementID: Integer;
    function GetItems(Index: Integer): TGOverlay;
    procedure SetItems(Index: Integer; const Value: TGOverlay);
  public
    property Items[Index: Integer]: TGOverlay read GetItems write SetItems; default;
  published
    constructor Create;
    function Add(var aGOverlay: TGOverlay): Integer;
    function ToString: String; override;
  end;


  TGInfoWindow = class(TGOverlay, IJsClassWrapper, IGHidable)
    procedure Maximize;
    procedure Restore;
  private
    FHTML: String;
    procedure SetHTML(const Value: String);
  public
    property HTML: String read FHTML write SetHTML;
    function JsClassName: String; override;
    constructor Create(const aCenter: TGLatLng);reintroduce;
    destructor Destroy; override;
    function ToJavaScript: String; override;
    function supportsHide: Boolean; override;
  end;


  // used to show a location on a map
  // can be dragged, can show a popup, can have custom colors and icon
  TGMarker=class(TGOverlay,IJsClassWrapper,IGHidable)
  strict private
    FPosition: TGLatLng;
    FDraggingEnabled: Boolean;
    procedure setLatLng(const Value: TGLatLng);
    procedure SetDraggingEnabled(const Value: Boolean);
  private
    FTitle: String;
    FIcon: String;
    procedure SetTitle(const Value: String);
    procedure SetIcon(const Value: String);
  public
    function supportsHide: Boolean;override;
  published
    function JsClassName:String;override;
    constructor Create(const aPosition:TGLatLng; aMap:TGoogleMaps=nil; const aTitle:String=''; const aIcon:String='');reintroduce;
    destructor Destroy;override;
    property Position:TGLatLng read FPosition write setLatLng;
    property DraggingEnabled:Boolean read FDraggingEnabled write SetDraggingEnabled;
    function ToJavaScript:String;override;
    function Clone:TGMarker;reintroduce;
   { TODO 3 -oWouter : implement all marker methods and events }

    procedure openInfoWindow(aContent:String); // Opens the map info window over the icon of the marker. The content of the info window is given as a DOM node. Only option GInfoWindowOptions.maxWidth is applicable.
    procedure openInfoWindowHtml(aContent:String); // Opens the map info window over the icon of the marker. The content of the info window is given as a string that contains HTML text. Only option GInfoWindowOptions.maxWidth is applicable.
{    procedure openInfoWindowTabs(tabs, opts?) : none; // Opens the tabbed map info window over the icon of the marker. The content of the info window is given as an array of tabs that contain the tab content as DOM nodes. Only options GInfoWindowOptions.maxWidth and InfoWindowOptions.selectedTab are applicable.
    procedure openInfoWindowTabsHtml(tabs, opts?) : none; // Opens the tabbed map info window over the icon of the marker. The content of the info window is given as an array of tabs that contain the tab content as Strings that contain HTML text. Only options InfoWindowOptions.maxWidth and InfoWindowOptions.selectedTab are applicable.
    procedure bindInfoWindow(content, opts?) : none; // Binds the given DOM node to this marker. The content within this node will be automatically displayed in the info window when the marker is clicked. Pass content as null to unbind. (Since 2.85)
    procedure bindInfoWindowHtml(content, opts?) : none; // Binds the given HTML to this marker. The HTML content will be automatically displayed in the info window when the marker is clicked. Pass content as null to unbind. (Since 2.85)
    procedure bindInfoWindowTabs(tabs, opts?) : none; // Binds the given GInfoWindowTabs (provided as DOM nodes) to this marker. The content within these tabs' nodes will be automatically displayed in the info window when the marker is clicked. Pass tabs as null to unbind. (Since 2.85)
    procedure bindInfoWindowTabsHtml(tabs, opts?) : none; // Binds the given GInfoWindowTabs (provided as strings of HTML) to this marker. The HTML content within these tabs will be automatically displayed in the info window when the marker is clicked. Pass tabs as null to unbind. (Since 2.85)
    procedure closeInfoWindow() : none; // Closes the info window only if it belongs to this marker. (Since 2.85)
    procedure showMapBlowup(opts?) : none; // Opens the map info window over the icon of the marker. The content of the info window is a closeup map around the marker position. Only options InfoWindowOptions.zoomLevel and InfoWindowOptions.mapType are applicable.
    procedure getIcon() : GIcon; // Returns the icon of this marker, as set by the constructor.
    procedure getTitle() : String; // Returns the title of this marker, as set by the constructor via the GMarkerOptions.title property. Returns undefined if no title is passed in. (Since 2.85)
    procedure getPoint() : GLatLng; // Returns the geographical coordinates at which this marker is anchored, as set by the constructor or by setPoint(). (Deprecated since 2.88)
    procedure getLatLng() : GLatLng; // Returns the geographical coordinates at which this marker is anchored, as set by the constructor or by setLatLng(). (Since 2.88)
    procedure setPoint(latlng) : none; // Sets the geographical coordinates of the point at which this marker is anchored. (Deprecated since 2.88)
    procedure setLatLng(latlng) : none; // Sets the geographical coordinates of the point at which this marker is anchored. (Since 2.88)
    procedure enableDragging() : none; // Enables the marker to be dragged and dropped around the map. To function, the marker must have been initialized with GMarkerOptions.draggable = true.
    procedure disableDragging() : none; // Disables the marker from being dragged and dropped around the map.
    procedure draggable() : Boolean; // Returns true if the marker has been initialized via the constructor using GMarkerOptions.draggable = true. Otherwise, returns false.
    procedure draggingEnabled() : Boolean; // Returns true if the marker is currently enabled for the user to drag on the map.
    procedure setImage(url) : none; // Requests the image specified by the url to be set as the foreground image for this marker. Note that neither the print image nor the shadow image are adjusted. Therefore this method is primarily intended to implement highlighting or dimming effects, rather than drastic changes in marker's appearances. (Since 2.75)
}
    property Title:String read FTitle write SetTitle;
    property Icon:String read FIcon write SetIcon;

  end;

  TGMarkerimage=class(TJsClassWrapper)
  private
    FOrigin: TGPoint;
    FAnchor: TGPoint;
    FIcon: String;
    FSize: TGSize;
  private
    procedure SetAnchor(const Value: TGPoint);
    procedure SetIcon(const Value: String);
    procedure SetOrigin(const Value: TGPoint);
    procedure SetSize(const Value: TGSize);
  public
    constructor Create(const aIcon:string;aSize:TGSize;aOrigin,aAnchor:TGPoint);reintroduce;
    function ToJavaScript: string; override;
  published
    property Icon:String read FIcon write SetIcon;
    property Size:TGSize read FSize write SetSize;
    property Origin:TGPoint read FOrigin write SetOrigin;
    property Anchor:TGPoint read FAnchor write SetAnchor;
  end;

  TGProjection=record
    class function fromLatLngToPoint(latLng:TGLatLng; point:TGPoint=nil):TGPoint; static; // Translates from the LatLng cylinder to the Point plane. This interface specifies a function which implements translation from given LatLng values to world coordinates on the map projection. The Maps API calls this method when it needs to plot locations on screen. Projection objects must implement this method.
    class function fromPointToLatLng(pixel:TGPoint; nowrap:boolean=false):TGLatLng; static; // This interface specifies a function which implements translation from world coordinates on a map projection to LatLng values. The Maps API calls this method when it needs to translate actions on screen to positions on the map. Projection objects must implement this method.
  end;

  TGGeoXml = class(TGOverlay, IJsClassWrapper, IGHidable)
  private
    FUrlOfXml: String;
    procedure SetUrlOfXml(const Value: String);
  published

    // function  getTileLayerOverlay: GTileLayerOverlay; // GGeoXml objects may create a tile overlay for optimization purposes in certain cases. This method returns this tile layer overlay (if available). Note that the tile overlay may be null if not needed, or if the GGeoXml file has not yet finished loading. (Since 2.84)
    // function  getDefaultCenter   : GLatLng;           // Returns the center of the default viewport as a lat/lng. This function should only be called after the file has been loaded. (Since 2.84)
    // function  getDefaultSpan     : GLatLng;           // Returns the span of the default viewport as a lat/lng. This function should only be called after the file has been loaded. (Since 2.84)
    // function  getDefaultBounds   : GLatLngBounds;     // Returns the bounding box of the default viewport. This function should only be called after the file has been loaded. (Since 2.84)
    procedure gotoDefaultViewport(Map: TGoogleMaps); // Sets the map's viewport to the default viewport of the XML file. (Since 2.84)
    // function  hasLoaded          : Boolean; // Checks to see if the XML file has finished loading, in which case it returns true. If the XML file has not finished loading, this method returns false. (Since 2.84)
    // function  loadedCorrectly    : Boolean; // Checks to see if the XML file has loaded correctly, in which case it returns true. If the XML file has not loaded correctly, this method returns false. If the XML file has not finished loading, this method's return value is undefined. (Since 2.84)
    function supportsHide: Boolean; override; // Always returns true. (Since 2.87)

    function JsClassName: String; override;
    constructor Create(const aUrlOfXml: String);reintroduce;
    destructor Destroy; override;
    property UrlOfXml: String read FUrlOfXml write SetUrlOfXml;
    function ToJavaScript: String; override;
  end;


  // polygon class
  TGPolygon=class(TGOverlay,IJsClassWrapper,IGHidable)
  private
    FPoints:Array of TGLatLng;
    FStrokeOpacity: double;
    FStrokeWeight: double;
    FStrokeColor: TColor;
    FSimplified: TGPolygon;
    FIsDirty: Boolean;
    procedure SetColor(const Value: TColor);
    procedure SetOpacity(const Value: double);
    procedure SetWeightPx(const Value: Double);
    function GetCount: Integer;
    procedure SetSimplified(const Value: TGPolygon);
    function GetSimplified: TGPolygon;
  public
    constructor Create;overload;override;
    constructor Create(const aPath: array of TGLatLng;aStrokeColor:TColor=clBlue;aStrokeOpacity:Double=1.0;aStrokeWeight:Double=2);reintroduce;overload;
    constructor Create(const aPoints:Array of TPointFloat2D);reintroduce;overload;
    function supportsHide: Boolean;override;
    function Clone: TGPolygon; reintroduce;
  published
    function JsClassName:String;override;
    procedure Clear;
    function ToJavaScript:String;override;
    function AddPoint(const aGLatLng:TGLatLng):integer;
    function AddPoints(const aGLatLngAr: Array of TGLatLng):integer;
    property StrokeColor:TColor read FStrokeColor write SetColor;
    property StrokeWeight:double read FStrokeWeight write SetWeightPx;
    property StrokeOpacity:double read FStrokeOpacity write SetOpacity;// number between 0 and 1
    property Count:Integer read GetCount;
    destructor Destroy;override;
    property IsDirty:Boolean read FIsDirty write FIsDirty;
    property Simplified:TGPolygon read GetSimplified write SetSimplified;
    function getSimplifiedVersion(Tolerance:Double=DEFAULT_SIMPLIFY_TOLERANCE):TGPolygon;
  end;

  TGPolyLine = class(TGPolygon, IJsClassWrapper, IGHidable)
  published
    function JsClassName: String; override;
  end;

  TGCopyright = class(TGOverlay, IJsClassWrapper, IGHidable)
  strict private
    FminZoom: Integer;
    FID: Integer;
    Fbounds: TGLatLngBounds;
    Ftext: String;
    procedure Setbounds(const Value: TGLatLngBounds);
    procedure SetID(const Value: Integer);
    procedure SetminZoom(const Value: Integer);
    procedure Settext(const Value: String);
  published
    property ID: Integer read FID write SetID; // A unique identifier for this copyright information.
    property minZoom: Integer read FminZoom write SetminZoom; // The lowest zoom level at which this information applies.
    property bounds: TGLatLngBounds read Fbounds write Setbounds; // The region to which this information applies.
    property text: String read Ftext write Settext; // The text of the copyright message.
    constructor Create(aId: Integer; aBounds: TGLatLngBounds; aMinZoom: Integer; aText: String);reintroduce;
  end;

  TGControl = string;

  TMapTypeRegistry = class

  end;

  TGoogleMaps=class(TBrowserControl, IJsClassWrapper)
  strict private
    FBrowser:TBrowser;
    FOverlays: TOverlayList;
    FMapType: TGoogleMapType;
    FLatLngCenter: TGLatLng;
    FBounds : TGLatLngBounds;
    FJsVarName : String;
    FZoom:Integer;
    FControls: TList<TGControl>;
    FEvent:TEvent;
    procedure Init;

    procedure SetOverlays(const Value: TOverlayList);
    function GetCenter: TGLatLng;
    procedure SetMapType(AMapType:TGoogleMapType);
    function GetMapType: TGoogleMapType;
  private
    FOnBoundsChanged: TNotifyEvent;
    FOnCenterChanged: TNotifyEvent;
    FOnDblClick: TNotifyEvent;
    FOnClick: TNotifyEvent;
    FOnMouseMove: TNotifyEvent;
    procedure SetOnBoundsChanged(const Value: TNotifyEvent);
    procedure SetOnCenterChanged(const Value: TNotifyEvent);
    procedure SetOnClick(const Value: TNotifyEvent);
    procedure SetOnDblClick(const Value: TNotifyEvent);
    procedure SetOnMouseMove(const Value: TNotifyEvent);
  protected
    function AddOverlay(aOverlay:TGOverlay):Integer;
    procedure Loaded; override;
    procedure HandleOnResize(Sender:TObject);
  public
    constructor Create(AOwner: TComponent);override;
    destructor Destroy;override;
    procedure SetCenter(const Value: TGLatLng);overload;
    procedure SetCenter(Lat,Lng:Double;doPan:Boolean=false);overload;

    function GetZoom: Integer;
    procedure SetZoom(const Value: Integer);

    procedure CheckResize;
    function JsClassName: string;
    function GetJsVarName: string;
    procedure SetJsVarName(const aVarName: string);
    function ToJavaScript: string;
    property Browser : TBrowser read FBrowser write FBrowser;
    property Center : TGLatLng read GetCenter write SetCenter;

  published
    property Overlays     : TOverlayList read FOverlays write SetOverlays;
    property Controls     : TList<TGControl> read FControls write FControls;

    property MapType:TGoogleMapType read GetMapType write SetMapType;
    procedure AddControl(ControlType:TGoogleMapControlType);
    procedure RemoveOverlay(aOverlay:TGOverlay);
    procedure RemoveOverlayByIndex(Index:Integer);
    procedure ClearOverlays;
    procedure PanBy(X,Y:Double);
    procedure panToBounds(latLngBounds:TGLatLngBounds);
    procedure FitBounds(const aBounds:TGLatLngBounds);
    function GetBounds:TGLatLngBounds;
    property Bounds : TGLatLngBounds read GetBounds write FitBounds;
    property Zoom:Integer read GetZoom write SetZoom;
    procedure ExecJavaScript(const aScript:String);
    procedure WebBrowserDocumentComplete(ASender: TObject; const pDisp: IDispatch; var URL: OleVariant);
    property Align;
//    property OnClick;
    property OnResize;
//    property OnEnter;
//    property OnExit;
//    property OnKeyDown;
//    property OnKeyPress;
//    property OnKeyUp;
//    property OnDblClick;
    property Anchors;
    property BoundsRect;
//    property ShowHint;
    property Visible;
    property Event:TEvent read FEvent write FEvent;
    property OnBoundsChanged:TNotifyEvent read FOnBoundsChanged write SetOnBoundsChanged;
    property OnCenterChanged:TNotifyEvent read FOnCenterChanged write SetOnCenterChanged;
    property OnClick:TNotifyEvent read FOnClick write SetOnClick;
    property OnDblClick:TNotifyEvent read FOnDblClick write SetOnDblClick;
    property OnMouseMove:TNotifyEvent read FOnMouseMove write SetOnMouseMove;
    class function GetHTMLResourceName:String;override;
  end;

{$R DelphiMaps.GoogleMaps.dcr}
{$R DelphiMapsBrowserExternal.tlb}
{$R DelphiMaps.GoogleMaps_html.res}

implementation

uses
  Math, Windows;

{ TGoogleMaps }

procedure TGoogleMaps.Init;
var
  LHtmlFileName : String;
begin
  Browser.OnDocumentComplete := WebBrowserDocumentComplete;
  LHtmlFileName := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName))+GoogleMapsFileName;
  SaveHtml(LHtmlFileName);
  if FileExists(LHtmlFileName) then
    FBrowser.Navigate('file://' + LHtmlFileName);

  FOverlays := TOverlayList.Create;
//  FEvent := TEvent.Create(FBrowser);

//  FEvent.AddListener(self, 'bounds_changed', procedure() begin if Assigned(FOnBoundsChanged) then FOnBoundsChanged(Self) end, '');
//  FEvent.AddListener(self, 'center_changed', procedure() begin if Assigned(FOnCenterChanged) then FOnCenterChanged(Self) end, '');
//  FEvent.AddListener(self, 'click'         , procedure() begin if Assigned(FOnClick)         then FOnClick(Self) end, '');
//  FEvent.AddListener(self, 'dblclick'      , procedure() begin if Assigned(FOnDblClick)      then FOnDblClick(Self) end, '');
//  FEvent.AddListener(self, 'mousemove'     , procedure() begin if Assigned(FOnMouseMove)     then FOnMouseMove(Self) end, '');


end;

function TGoogleMaps.JsClassName: string;
begin
  Result := 'google.maps.Map';
end;

constructor TGoogleMaps.Create(AOwner: TComponent);
begin
  inherited;

  Color := 0;
  FLatLngCenter := TGLatLng.Create(52,5);
  FBrowser := TBrowser.Create(self);
  FBrowser.Resizable := False;
  FBrowser.Silent := True;
  TWinControl(FBrowser).Parent := Self;
  FBrowser.Align := alClient;
  FBrowser.Show;
//  JsVarName := Name;
  JsVarName := 'map';
  Init;
end;


destructor TGoogleMaps.Destroy;
begin
  FOverlays.Clear;
  FreeAndNil(FOverlays);
  FreeAndNil(FLatLngCenter);
  FreeAndNil(FBounds);
//  FreeAndNil(FEvent);
  inherited;
end;

procedure TGoogleMaps.ExecJavaScript(const aScript: String);
begin
  Browser.ExecJavaScript(aScript);
end;

procedure TGoogleMaps.FitBounds(const aBounds: TGLatLngBounds);
begin
  FreeAndNil(FBounds);
  FBounds := aBounds.Clone;
  ExecJavaScript(jsVarName+'.fitBounds('+aBounds.ToJavaScript+')');
end;

procedure TGoogleMaps.AddControl(ControlType: TGoogleMapControlType);
begin
  ExecJavaScript(Format('addControl(%d);',[Integer(ControlType)]));
end;


function TGoogleMaps.AddOverlay(aOverlay:TGOverlay):Integer;
begin
  if aOverLay.Map<>self then
    aOverLay.Map := self;
  Result := FOverlays.Add(aOverlay);
//  V2 way to do it:
//  ExecJavaScript('var '+aOverlay.JsVarName + '=' + aOverlay.ToJavaScript+ ';');
//  ExecJavaScript(JsVarName+'.addOverlay('+aOverlay.JsVarName+')');

//  V3 way to do it:
  ExecJavaScript('var '+aOverLay.JsVarName+' = '+aOverLay.ToJavaScript+';');
  ExecJavaScript(aOverLay.JsVarName+'.setMap('+JsVarName+');');

end;


procedure TGoogleMaps.Loaded;
begin
  inherited;
  JsVarName := 'map';
end;


procedure TGoogleMaps.PanBy(X, Y: Double);
begin
  // Changes the center of the map by the given distance in pixels.
  // If the distance is less than both the width and height of the map,
  // the transition will be smoothly animated.
  // Note that the map coordinate system increases from west to east
  // for x values) and north to south (for y values).
  ExecJavaScriptFmt('%s.panBy(%g,%g);',[JsVarName,X,Y]);
end;

procedure TGoogleMaps.panToBounds(latLngBounds: TGLatLngBounds);
begin
  // Pans the map by the minimum amount necessary to contain the
  // given LatLngBounds. It makes no guarantee where on the map the
  // bounds will be, except that as much of the bounds as possible
  // will be visible. The bounds will be positioned inside the area
  // bounded by the map type and navigation controls, if they are
  // present on the map. If the bounds is larger than the map,
  // the map will be shifted to include the northwest corner of the
  // bounds. If the change in the map's position is less than both the
  // width and height of the map, the transition will be smoothly animated.
  ExecJavaScriptFmt('%s.panToBounds(%s);',[JsVarName,latLngBounds.ToJavaScript]);
end;

procedure TGoogleMaps.SetCenter(Lat, Lng: Double;doPan:Boolean=False);
var
  Operation:String;
begin
  if (Lat=FLatLngCenter.Lat) and (FLatLngCenter.Lng = Lng)  then
    Exit;

  if DoPan then
    Operation := 'panTo'
  else
    Operation := 'setCenter';

  FormatSettings.DecimalSeparator := '.';
  FLatLngCenter.Lat := Lat;
  FLatLngCenter.Lng := Lng;
  ExecJavaScript(Format('%s.%s(%s);',[jsVarName, Operation, FLatLngCenter.ToJavaScript]));
end;

procedure TGoogleMaps.SetCenter(const Value: TGLatLng);
begin
  FLatLngCenter := Value;
  SetCenter(FLatLngCenter.Lat,FLatLngCenter.Lng);
end;


procedure TGoogleMaps.SetMapType(AMapType: TGoogleMapType);
begin
  FMapType := AMapType;
  ExecJavaScript(jsVarName+'.setMapTypeId(google.maps.MapTypeId.'+cGoogleMapTypeStr[FMapType]+');');
end;


procedure TGoogleMaps.SetOnBoundsChanged(const Value: TNotifyEvent);
begin
  FOnBoundsChanged := Value;
end;

procedure TGoogleMaps.SetOnCenterChanged(const Value: TNotifyEvent);
begin
  FOnCenterChanged := Value;
end;

procedure TGoogleMaps.SetOnClick(const Value: TNotifyEvent);
begin
  FOnClick := Value;
end;

procedure TGoogleMaps.SetOnDblClick(const Value: TNotifyEvent);
begin
  FOnDblClick := Value;
end;

procedure TGoogleMaps.SetOnMouseMove(const Value: TNotifyEvent);
begin
  FOnMouseMove := Value;
end;

procedure TGoogleMaps.SetOverlays(const Value: TOverlayList);
begin
  FOverlays := Value;
end;

procedure TGoogleMaps.SetZoom(const Value: Integer);
begin
  if FZoom=Value then
    Exit;

  FZoom := Value;
  ExecJavaScriptFmt('%s.setzoom(%d);',[jsVarName,Value]);
end;

function TGoogleMaps.ToJavaScript: string;
begin
  result := ' new ' + JsClassName + '()';
end;

procedure TGoogleMaps.WebBrowserDocumentComplete(ASender: TObject;
  const pDisp: IDispatch; var URL: OleVariant);
begin

end;



procedure TGoogleMaps.RemoveOverlay(aOverlay: TGOverlay);
begin
//  v2 style:
//  ExecJavaScript(JsVarName+'.removeOverlay('+aOverlay.JsVarName+');');

//  v3 style:
//  ExecJavaScript('if('+aOverlay.JsVarName+')'+aOverlay.JsVarName + '.map=null;');
//  ExecJavaScript('delete '+aOverlay.JsVarName+';');
  ExecJavaScript(aOverLay.JsVarName+'.setMap(null);');

//  FOverlays.Remove(aOverlay);
end;

procedure TGoogleMaps.RemoveOverlayByIndex(Index: Integer);
begin
  if InRange(Index,0,Pred(Overlays.Count)) then
    RemoveOverlay(Overlays.Items[index]);
end;


function TGoogleMaps.GetBounds: TGLatLngBounds;
var
  Js : String;
begin
  // read values from the browser.. the user might have scrolled in the meanwhile
  Js := Browser.Eval(JsVarName+'.getBounds()','');
  if Js<>'' then
  begin
    FreeAndNil(FBounds);
    FBounds := TGLatLngBounds.Create(Js);
  end;
  Result := FBounds;
end;

class function TGoogleMaps.GetHTMLResourceName: String;
begin
  Result := 'GOOGLE_MAPS_HTML';
end;

function TGoogleMaps.GetJsVarName: string;
begin
  Result := JsVarName;
end;

function TGoogleMaps.GetMapType: TGoogleMapType;
var
  Js : String;
  LGoogleMapType:TGoogleMapType;
begin
  // read values from the browser.. the user might have scrolled in the meanwhile
  Js := Browser.Eval(JsVarName+'.getMapTypeId()','');
  if Js<>'' then
  begin
    FreeAndNil(FBounds);
    for LGoogleMapType := Low(cGoogleMapTypeStr) to High(cGoogleMapTypeStr)  do
    begin
      if Js=cGoogleMapTypeStr[LGoogleMapType] then
      begin
        FMapType := LGoogleMapType;
        Break;
      end;
    end;
  end;
  Result := FMapType;
end;

function TGoogleMaps.GetCenter: TGLatLng;
begin
//  FLatLngCenter.Lat := GetJsValue(JsVarName+'.getCenter().lat()');
//  FLatLngCenter.Lng := GetJsValue(JsVarName+'.getCenter().lng()');
  Result            := FLatLngCenter;
end;

function TGoogleMaps.GetZoom: Integer;
begin
  FZoom := FBrowser.Eval(JsVarName + '.getZoom()',FZoom);
  Result := FZoom;
end;

procedure TGoogleMaps.SetJsVarName(const aVarName: string);
begin
  FJsVarName := aVarName;
end;

procedure TGoogleMaps.CheckResize;
begin
  ExecJavaScript(JsVarName+'.checkResize();');
end;

procedure TGoogleMaps.HandleOnResize(Sender: TObject);
begin
  CheckResize;
end;

procedure TGoogleMaps.ClearOverlays;
var
  Overlay:TGOverlay;
begin
  // v2 style:
  // FOverlays.Clear;
  // ExecJavaScript(JsVarName+'.clearOverlays();');

  // v3 style:
  for Overlay in FOverlays do
  begin
    Overlay.Map := nil;
  end;
  FOverlays.Clear;

end;


{ TGPolygon }

function TGPolygon.AddPoint(const aGLatLng: TGLatLng): integer;
begin
  Result := -1;
  if (Count>0) and (aGLatLng.Equals(FPoints[High(FPoints)])) then
    Exit;

  SetLength(FPoints,Length(FPoints)+1);
  FPoints[High(FPoints)] := aGLatLng;
end;

function TGPolygon.JsClassName: String;
begin
  Result := 'google.maps.Polygon';
end;

function TGPolygon.AddPoints(const aGLatLngAr: array of TGLatLng): integer;
var
  LGLatLng: TGLatLng;
  Index:Integer;
begin
  Index := Length(FPoints);
  SetLength(FPoints,Length(FPoints)+Length(aGLatLngAr));
  for LGLatLng in aGLatLngAr do
  begin
    FPoints[Index] := LGLatLng;
    Inc(Index);
  end;
  Result := High(FPoints);
end;

procedure TGPolygon.Clear;
begin
  FreeAndNil(FSimplified);
  SetLength(FPoints,0);
end;


function TGPolygon.Clone: TGPolygon;
var
  LPoints : array of TGLatLng;
  i: Integer;
begin
  SetLength(LPoints, Length(FPoints));
  for i := low(FPoints) to high(FPoints) do
    LPoints[I] := FPoints[I].Clone;

  Result := TGPolygon.Create( LPoints, FStrokeColor, FStrokeOpacity, FStrokeWeight);
  Result.Map := FMap;
end;

constructor TGPolygon.Create;
begin
  inherited;
  FStrokeColor    := clBlue;
  FStrokeOpacity  := 1.0;
  FStrokeWeight   := 2;
end;

destructor TGPolygon.Destroy;
var
  I : integer;
begin
  FreeAndNil(FSimplified);
  for I := 0 to High(FPoints) do
    FreeAndNil(FPoints[I]);
  inherited;
end;

constructor TGPolygon.Create(const aPath: array of TGLatLng;aStrokeColor:TColor=clBlue;aStrokeOpacity:Double=1.0;aStrokeWeight:Double=2);
var
  I :integer;
begin
  FStrokeColor    := aStrokeColor;
  FStrokeOpacity  := aStrokeOpacity;
  FStrokeWeight   := aStrokeWeight;

  SetLength(FPoints,Length(aPath));

  for I := 0 to High(aPath) do
    FPoints[I] := aPath[I];
end;

constructor TGPolygon.Create(const aPoints: array of TPointFloat2D);
var
  I :integer;
begin
  Create;
  SetLength(FPoints,Length(APoints));
  for I := 0 to High(APoints) do
    FPoints[I] := TGLatLng.Create(APoints[I].Y,APoints[I].X);
end;


function TGPolygon.GetCount: Integer;
begin
  Result := Length(FPoints);
end;

function TGPolygon.GetSimplified: TGPolygon;
begin
  if (not Assigned(FSimplified)) or  FSimplified.IsDirty then
    FSimplified := getSimplifiedVersion;

  Result := FSimplified;
end;

function TGPolygon.getSimplifiedVersion(Tolerance:Double): TGPolygon;
var
  OrigAr,
  SimplifiedAr:TFloat2DPointAr;
  I: Integer;
begin

  SetLength( OrigAr, Count );

  for I := 0 to Count - 1 do
  begin
    OrigAr[I].X := FPoints[I].Lng;
    OrigAr[I].Y := FPoints[I].Lat;
  end;

  PolySimplifyFloat2D( Tolerance, OrigAr, SimplifiedAr );

  for I := 0 to High(SimplifiedAr) do
  begin
    OrigAr[I].X := FPoints[I].Lng;
    OrigAr[I].Y := FPoints[I].Lat;
  end;

  Result := TGPolygon.Create(SimplifiedAr);
end;


procedure TGPolygon.SetColor(const Value: TColor);
begin
  FStrokeColor := Value;
end;

procedure TGPolygon.SetOpacity(const Value: double);
begin
  FStrokeOpacity := Value;
end;

procedure TGPolygon.SetSimplified(const Value: TGPolygon);
begin
  FSimplified := Value;
end;

procedure TGPolygon.SetWeightPx(const Value: Double);
begin
  FStrokeWeight := Value;
end;

function TGPolygon.supportsHide: Boolean;
begin
  Result := True;
end;

function TGPolygon.ToJavaScript: String;
var
  I : Integer;
begin
  Result := ' new ' + JsClassName + '({path:['#13#10;
  for I := 0 to High(FPoints) do
  begin
    Result := Result +  FPoints[I].ToJavaScript;
    if I<High(FPoints) then
      Result := Result + ','#13#10;
  end;
  FormatSettings.DecimalSeparator := '.';
	Result := Result + '], strokeColor:"'+ColorToHtml(StrokeColor)+'", strokeOpacity:'+FloatToStr(FStrokeOpacity)+', strokeWeight:'+FloatToStr(StrokeWeight)+'})'#13#10;
end;

{ TGLatLng }

function TGLatLng.Clone: TGLatLng;
begin
  Result := TGLatLng.Create(FLat,FLng);
end;

constructor TGLatLng.Create(aLat, aLng: Double);
begin
  FLat := aLat;
  Flng := aLng;
end;

function TGLatLng.Equals(const AGLatLng: TGLatLng): Boolean;
begin
  Result := (AGLatLng.Lat=Lat) and (AGLatLng.Lng=Lng);
end;


function TGLatLng.JsClassName: String;
begin
  Result := 'google.maps.LatLng';
end;

function TGLatLng.ToJavaScript: String;
begin
  FormatSettings.DecimalSeparator := '.';
  Result := Format(' new '+jsClassName+'(%g,%g)',[ Lat, Lng ]);
end;

function TGLatLng.ToString: String;
begin
  Result := Format('(Lat:%g,Lng:%g)',[Lat,Lng])
end;

{ TGPolyLine }

function TGPolyLine.JsClassName: String;
begin
  Result := 'google.maps.Polyline';
end;

{ TMarker }

destructor TGMarker.Destroy;
begin
  FreeAndNil(FPosition);
  inherited;
end;

function TGMarker.JsClassName: String;
begin
  Result := 'google.maps.Marker';
end;

procedure TGMarker.openInfoWindow(aContent:String);
begin
  Map.ExecJavaScript(JsVarName+'.openInfoWindow("'+aContent+'");');
end;

procedure TGMarker.openInfoWindowHtml(aContent:String);
begin
  Map.ExecJavaScript(JsVarName+'.openInfoWindowHtml("'+aContent+'");');
end;

procedure TGMarker.SetDraggingEnabled(const Value: Boolean);
begin
  FDraggingEnabled := Value;
end;

procedure TGMarker.SetIcon(const Value: String);
begin
  FIcon := Value;
  Map.ExecJavaScript(Format('%s.setIcon("%s");',[JsVarName,FIcon]));
end;

function TGMarker.Clone: TGMarker;
begin
  Result := TGMarker.Create( FPosition.Clone, FMap, FTitle, FIcon );
end;

constructor TGMarker.Create(const aPosition: TGLatLng; aMap:TGoogleMaps=nil;const aTitle:String='';const aIcon:string='');
begin
  FPosition := aPosition;
  FTitle := aTitle;
  FIcon := aIcon;
  Map := aMap;
end;


procedure TGMarker.setLatLng(const Value: TGLatLng);
begin
  FPosition := Value;
end;

procedure TGMarker.SetTitle(const Value: String);
begin
  FTitle := Value;
  Map.ExecJavaScript(Format('%s.setTitle("%s");',[JsVarName,FTitle]));
end;

function TGMarker.SupportsHide: Boolean;
begin
  Result := True;
end;

function TGMarker.ToJavaScript: String;
begin
  Result := ' new '+JsClassName+'({Position:'+FPosition.ToJavaScript;
  if Assigned(Map) then
    Result := Result + ',map:'+Map.JsVarName;
  if Title<>'' then
    Result := Result + ',title:"'+FTitle+'"';
  if Icon<>'' then
    Result := Result + ',icon:"'+FIcon+'"';
  Result := Result +'})';

end;

{ TOverlayList }

function TOverlayList.Add(var aGOverlay: TGOverlay): Integer;
begin
  aGOverlay.ID := AutoIncrementID;
  inc(AutoIncrementID);
  result := inherited Add(aGOverLay);
end;

constructor TOverlayList.Create;
begin
  OwnsObjects := True;
end;


function TOverlayList.GetItems(Index: Integer): TGOverlay;
begin
  result := TGOverlay(inherited Items[Index]);
end;

procedure TOverlayList.SetItems(Index: Integer; const Value: TGOverlay);
begin
  inherited Items[Index] := Value;
end;

function TOverlayList.ToString: String;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    Result := Result + Format('%d : %s (%s)',[I,Items[I].JsVarName,Items[I].JsClassName])+ #13#10;

  Result := inherited + Trim(Result);
end;

{ TGOverlay }

function TGOverlay.GetJsVarName: String;
begin
  FJsVarName := 'ovl_'+IntToStr(ID);
  Result := FJsVarName;
end;


procedure TGOverlay.hide;
begin
  inherited;
  if supportsHide then
    FMap.ExecJavaScript(JsVarName + '.hide();');
end;

function TGOverlay.isHidden: Boolean;
begin
  Result := FMap.Browser.Eval(JsVarName + '.isHidden()',False);
end;

function TGOverlay.JsClassName: string;
begin
  Result := 'google.maps.Overlay';
end;

procedure TGOverlay.SetMap(const Value: TGoogleMaps);
begin
  if FMap=Value then
    Exit;

  if Assigned(FMap) and (not Assigned(Value)) then
  begin
    FMap.RemoveOverlay( self );
    Exit;
  end;

  FMap := Value;
  if not Assigned(FMap) then
    Exit;

  FMap.AddOverlay(self);
end;

procedure TGOverlay.SetID(const Value: Integer);
begin
  FID := Value;
end;

procedure TGOverlay.SetJsVarName(const Value: String);
begin
  FJsVarName := Value;
end;

procedure TGOverlay.SetName(const Value: String);
begin
  FName := Value;
  FJsVarName := Value;
end;

procedure TGOverlay.show;
begin
  FMap.ExecJavaScript(JsVarName + '.show();');
end;

function TGOverlay.supportsHide: Boolean;
begin
  Result := false;
end;

{ TGBounds }

destructor TGBounds.Destroy;
begin
  FreeAndNil(FMin);
  FreeAndNil(FMid);
  FreeAndNil(FMax);
  inherited;
end;

function TGBounds.Equals(aGBounds: TGBounds): Boolean;
begin
  Result :=
  (
    (minX = aGBounds.minX) and
    (minY = aGBounds.minY) and
    (maxX = aGBounds.maxX) and
    (maxY = aGBounds.maxY)
  );
end;

function TGBounds.GetJsVarName: String;
begin
  Result := FJsVarName;
end;

function TGBounds.GetMax: TGLatLng;
begin
  Result := TGLatLng.Create(maxY,MaxX);
end;

function TGBounds.GetMid: TGLatLng;
begin
  if not Assigned(FMin) then
    FMid := TGLatLng.Create(minX+((maxX-minX)/2),minY+((maxY-minY)/2));

  Result := FMid;
end;

function TGBounds.GetMin: TGLatLng;
begin
  Result := TGLatLng.Create(minY,MinX);
end;

function TGBounds.JsClassName: String;
begin
  Result := 'google.maps.Bounds';
end;

procedure TGBounds.SetJsVarName(const Value: String);
begin
  FJsVarName := Value;
end;

function TGBounds.ToJavaScript: String;
begin
  Result := ' new '+JsClassName + '()';
  // @@@ not implemented
end;

function TGBounds.ToString: String;
begin
  // @@@ not yet implemented
end;

{ TGeoXML }

constructor TGGeoXml.Create(const aUrlOfXml: String);
begin
  FUrlOfXml:= aUrlOfXml;
end;

destructor TGGeoXml.Destroy;
begin
  // @@@ nothing to clean up
  inherited;
end;

procedure TGGeoXml.gotoDefaultViewport(Map: TGoogleMaps);
begin
  Map.ExecJavaScript(JsVarName + '.gotoDefaultViewport('+ Map.JsVarName +');');
end;

function TGGeoXml.JsClassName: String;
begin
  Result := 'google.maps.GeoXml';
end;

procedure TGGeoXml.SetUrlOfXml(const Value: String);
begin
  FUrlOfXml := Value;
end;

function TGGeoXml.supportsHide: Boolean;
begin
  Result := True;
end;

function TGGeoXml.ToJavaScript: String;
begin
  Map.ExecJavaScript('var '+JsVarName+' = new '+JsClassName+'("'+FUrlOfXml+'", function() { if ('+JsVarName+'.loadedCorrectly()) {'+JsVarName+'.gotoDefaultViewport('+Map.JsVarName+');}})');
  Result := JsVarName;
end;

{ TGCopyright }

constructor TGCopyright.Create(aId: Integer; aBounds: TGLatLngBounds;
  aMinZoom: Integer; aText: String);
begin
  Fid      := aID;
  FBounds  := aBounds;
  FMinZoom := aMinZoom;
  FText    := aText;
end;

procedure TGCopyright.Setbounds(const Value: TGLatLngBounds);
begin
  Fbounds := Value;
end;

procedure TGCopyright.Setid(const Value: Integer);
begin
  Fid := Value;
end;

procedure TGCopyright.SetminZoom(const Value: Integer);
begin
  FminZoom := Value;
end;

procedure TGCopyright.Settext(const Value: String);
begin
  Ftext := Value;
end;

{ TGLatLngBounds }


function TGLatLngBounds.Clone: TGLatLngBounds;
begin
  Result := TGLatLngBounds.Create( Self.FNorthEast.Clone, self.FSouthWest.Clone );
end;

function TGLatLngBounds.contains(aLatLng: TGLatLng): Boolean;
begin
  Result :=
    (aLatLng.FLat > Self.FNorthEast.FLat) and
    (aLatLng.FLat < Self.FSouthWest.FLat) and
    (aLatLng.FLng > Self.FNorthEast.FLng) and
    (aLatLng.FLng < Self.FSouthWest.FLng);
end;

function TGLatLngBounds.containsBounds(aGLatLngBounds: TGLatLngBounds): Boolean;
begin
  Result := containsLatLng( aGLatLngBounds.FNorthEast ) and containsLatLng( aGLatLngBounds.FSouthWest )
end;

function TGLatLngBounds.containsLatLng(aLatLng: TGLatLng): Boolean;
begin
  Result :=
    InRange(aLatLng.FLat,Self.FNorthEast.FLat,Self.FSouthWest.FLat) and
    InRange(aLatLng.FLng,Self.FNorthEast.FLng,Self.FSouthWest.FLng)
end;

constructor TGLatLngBounds.Create(aEast, aNorth, aWest, aSouth: Double);
begin
  FNorthEast := TGLatLng.Create(aNorth,aEast);
  FSouthWest := TGLatLng.Create(aSouth,aWest);
end;

constructor TGLatLngBounds.Create(const aJs: String);
begin
  FromString(aJs);
end;

constructor TGLatLngBounds.Create(sw, ne: TGLatLng);
begin
  FSouthWest := sw;
  FNorthEast := ne;
end;

destructor TGLatLngBounds.Destroy;
begin
  FreeAndNil(FNorthEast);
  FreeAndNil(FSouthWest);
  inherited;
end;

function TGLatLngBounds.Equals(aGLatLngBounds: TGLatLngBounds): Boolean;
begin
  Result :=
    NorthEast.Equals(aGLatLngBounds.NorthEast) and
    SouthWest.Equals(aGLatLngBounds.SouthWest);
end;

procedure TGLatLngBounds.extend(aLatLng: TGLatLng);
begin
{
  NorthEast. va.extend(a.pd());
  SouthWest.Extend(
  this.fa.extend(aLatLng.qd())
  }
end;

procedure TGLatLngBounds.FromString(const aJs: String);
var
  SL: TStringList;
  LJs : String;
begin
  {$IFDEF VER220}FormatSettings.{$ENDIF}DecimalSeparator := '.';
  LJs := aJs;
  LJs := ReplaceStr(LJs,'(','');
  LJs := ReplaceStr(LJs,')','');
  LJs := ReplaceStr(LJs,' ','');
  SL := TStringList.Create;
  try
    SL.Delimiter := ',';
    SL.StrictDelimiter := True;
    SL.DelimitedText := LJs;
    if SL.Count=4 then
    begin
      FreeAndNil(FNorthEast);
      FreeAndNil(FSouthWest);
      FNorthEast := TGLatLng.Create( StrToFloat(SL[0]), StrToFloat(SL[1]) );
      FSouthWest := TGLatLng.Create( StrToFloat(SL[2]), StrToFloat(SL[3]) );
    end
    else
    begin

    end;
  finally
    SL.Free;
  end;
end;

function TGLatLngBounds.getCenter: TGLatLng;
begin
  Result := TGLatLng.Create(
    (FNorthEast.Lat + FSouthWest.FLat) / 2,
    (FNorthEast.Lng + FSouthWest.Lng ) / 2
  );
end;

function TGLatLngBounds.GetJsVarName: string;
begin
end;

function TGLatLngBounds.getNorthEast: TGLatLng;
begin
  Result := FNorthEast;
  //TGLatLngBounds.getNorthEast=function(){return K.fromRadians(this.va.hi,this.fa.hi)}
end;

function TGLatLngBounds.getSouthWest: TGLatLng;
begin
  Result := SouthWest;

  //TGLatLngBounds.getSouthWest=function(){return K.fromRadians(this.va.lo,this.fa.lo)}
end;

function TGLatLngBounds.intersects(aGLatLngBounds: TGLatLngBounds): Boolean;
begin
  //TGLatLngBounds.intersects=function(a){return this.va.intersects(a.va)&&this.fa.intersects(a.fa)}
  raise ENotImplemented.CreateFmt('function %s not implemented',['TGLatLngBounds.intersects()']);
end;

function TGLatLngBounds.isEmpty: Boolean;
begin
  //TGLatLngBounds.isEmpty=function(){return this.va.$()||this.fa.$()}
  raise ENotImplemented.CreateFmt('function %s not implemented',['TGLatLngBounds.isEmpty)']);
end;

function TGLatLngBounds.isFullLat: Boolean;
begin
  //TGLatLngBounds.isFullLat=function(){return this.va.hi>=Bc/2&&this.va.lo<=-Bc/2}
//  Result := FNorthEast.FLat=-90 and FSouthWest.FLat==90;
  raise ENotImplemented.CreateFmt('function %s not implemented',['TGLatLngBounds.isFullLat)']);
end;

function TGLatLngBounds.isFullLng: Boolean;
begin
  //TGLatLngBounds.isFullLng=function(){return this.fa.Yh()}
  raise ENotImplemented.CreateFmt('function %s not implemented',['TGLatLngBounds.isFullLng)']);
end;

function TGLatLngBounds.JsClassName: string;
begin
  Result := 'google.maps.LatLngBounds';
end;

procedure TGLatLngBounds.SetJsVarName(const aVarName: string);
begin
  JsVarName := aVarName;
end;

procedure TGLatLngBounds.setNorthEast(const Value: TGLatLng);
begin
  FNorthEast := Value;
end;

procedure TGLatLngBounds.setSouthWest(const Value: TGLatLng);
begin
  FSouthWest := Value;
end;

function TGLatLngBounds.ToJavaScript: string;
begin
  Result := ' new '+JsClassName + '('+ FSouthWest.ToJavaScript + ',' + FNorthEast.ToJavaScript + ')';
end;

function TGLatLngBounds.toSpan: TGLatLng;
begin
//  Result := K.fromRadians(this.va.span(),this.fa.span(),true)}
  raise ENotImplemented.CreateFmt('function %s not implemented',['TGLatLngBounds.toSpan)']);
end;

function TGLatLngBounds.ToString: String;
begin
  Result := Format('((%g,%g),(%g,%g))',[ self.FNorthEast.FLat, self.FNorthEast.FLng, self.FSouthWest.FLat, self.FSouthWest.FLng ]);
end;

function TGLatLngBounds.Union(other: TGLatLngBounds): TGLatLngBounds;
begin
  Result := TGLatLngBounds.Create(
    TGLatLng.Create(Min(SouthWest.FLat,Other.SouthWest.Lat),
                    Min(SouthWest.FLng,Other.SouthWest.FLng)),
    TGLatLng.Create(Max(NorthEast.FLat,Other.NorthEast.Lat),
                    Max(NorthEast.FLng,Other.NorthEast.FLng)));
end;

{ TGInfoWindow }

constructor TGInfoWindow.Create(const aCenter: TGLatLng);
begin
end;

destructor TGInfoWindow.Destroy;
begin

  inherited;
end;


function TGInfoWindow.JsClassName: String;
begin
  Result := 'google.maps.InfoWindow';
end;

procedure TGInfoWindow.Maximize;
begin
  //
end;

procedure TGInfoWindow.Restore;
begin
  //
end;


procedure TGInfoWindow.SetHTML(const Value: String);
begin
  FHTML := Value;
end;

function TGInfoWindow.supportsHide: Boolean;
begin
  Result := True;
end;

function TGInfoWindow.ToJavaScript: String;
begin
  Result := Map.JsVarName + '.getInfoWindowHtml();';
end;


{ TGPoint }

function TGPoint.Equals(P: TGPoint): Boolean;
begin
  Result:= (X = p.X) and (Y = p.Y);
end;

function TGPoint.getJsClassName: String;
begin
  Result := 'google.maps.Point';
end;

function TGPoint.GetX: Double;
begin
  Result := FX;
end;

function TGPoint.GetY: Double;
begin
  Result := FY;
end;

procedure TGPoint.SetX(const Value: Double);
begin
  FX := Value;
end;

procedure TGPoint.SetY(const Value: Double);
begin
  FY := Value;
end;

function TGPoint.ToJavaScript: string;
begin
  Result := Format(' new '+jsClassName+'(%g,%g)',[ X, Y ]);
end;

function TGPoint.ToSTring: string;
begin
  Result := Format('%g,%g',[X,Y]);
end;

{ TGMarkerimage }

constructor TGMarkerimage.Create(const aIcon: string; aSize: TGSize; aOrigin,
  aAnchor: TGPoint);
begin
  FIcon := aIcon;
  FSize := aSize;
  FOrigin := aOrigin;
  FAnchor := aAnchor;
end;

procedure TGMarkerimage.SetAnchor(const Value: TGPoint);
begin
  FAnchor := Value;
end;

procedure TGMarkerimage.SetIcon(const Value: String);
begin
  FIcon := Value;
end;

procedure TGMarkerimage.SetOrigin(const Value: TGPoint);
begin
  FOrigin := Value;
end;

procedure TGMarkerimage.SetSize(const Value: TGSize);
begin
  FSize := Value;
end;

function TGMarkerimage.ToJavaScript: string;
begin
  Result := Format(' new %s(%s,%s,%s,%s)',[jsClassName, FIcon, FSize.ToJavaScript, FOrigin.ToJavaScript, FAnchor.ToJavaScript ]);
end;

{ TGSize }

constructor TGSize.Create(width, height: Double; widthUnit, heightUnit: string);
begin
  //
end;

function TGSize.Equals(aSize: TGSize): Boolean;
begin
  Result := (aSize.FWidth=FWidth) and (aSize.FHeight=FHeight)
end;

procedure TGSize.SetHeight(const Value: Double);
begin
  FHeight := Value;
end;

procedure TGSize.SetWidth(const Value: Double);
begin
  FWidth := Value;
end;

{ TGProjection }

class function TGProjection.fromLatLngToPoint(latLng: TGLatLng; point: TGPoint): TGPoint;
begin
  raise ENotImplemented.Create('not yet implemented');
end;

class function TGProjection.fromPointToLatLng(pixel: TGPoint;
  nowrap: boolean): TGLatLng;
begin
  raise ENotImplemented.Create('not yet implemented');
end;

end.

