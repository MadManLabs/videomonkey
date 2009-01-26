//
//  DeviceController.h
//  DeviceController
//
//  Created by Chris Marrin on 11/12/08.
//  Copyright Chris Marrin 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// Command file contains an outer <videomonkey> element with one of each children:
//
//  <commands> - command strings used by all devices, with children:
//      <command> - command string, contained text is the string of the command, with attributes:
//          id - name of the command (referenced by other commands)
//
//  <default_device> - parameters used by any device when not overridden, with children:
//      <quality> - set of stops for quality slider, with children:
//          <quality_stop> - one quality stop, with attributes:
//              which - index of this quality stop (0-5)
//                  Quality stop 0 is untitled and is used to hold lowest values for slider.
//                  Quality stop 5 is the rightmost tick mark and holds the highest slider values.
//              title - the title of the tick mark
//              bitrate - highest bitrate for this tick mark (or minimum bitrate when which=0)
//              audio - audio quality: low (16k, 1ch, 11025), medium (32k, 1ch, 22050), high (128k, 2ch, 48000)
//              size - relative video size (e.g., 0.5 is half size horiz and vert)
//
//      <performance> - values for performance menu, with children:
//          <performance_item> - one item in menu, with attributes and children:
//              title - title of this item in menu
//              <param> - a param (in runtime param dictionary) to use when this item is selected, with atributes:
//                  id - name of this param
//                  value - string value of this param (can use $ and ! as in commands)
//
//      <param> - see above. Param to use if none of the same name is given in device spec.
//
//      <recipes> - default recipes to use. Content is recipe string, with attributes
//          is_quicktime - boolean, true is special quicktime processing is needed
//          has_audio - boolean, true if source has audio
//          is_2pass - boolean, true if 2 pass is requested
//
//  <devices> - List of devices in device menu, with children:
//      <device_group> - A grouping of devices. Each groups has a title and groups are separated by a line, with attributes and children:
//          title - title for this group
//          <device> - device in this group, with same children as <default_device> and additional attributes and children:
//              title - title for this device
//              id - internal identifier to use for this device
//              tab - which tab in the GUI to use for this device (see below)
//              <checkbox> - in tabs with checkboxes this describes a checkbox, with attributes:
//                  which - which checkbox (0-n)
//                  title - title on the checkbox
//                  id - name of the param described by this checkbox
//                  checked - value to use for this param when box is checked
//                  unchecked - value to use for this param when box is unchecked

#define MAX_CHECKBOXES 4
#define MAX_MENUS 4
#define MAX_RADIOS 4

@class DeviceController;
@class JavaScriptContext;

@interface DeviceTab : NSTabViewItem {
    IBOutlet NSButton* m_button0;
    IBOutlet NSTextField* m_buttonLabel0;
    IBOutlet NSButton* m_button1;
    IBOutlet NSTextField* m_buttonLabel1;
    IBOutlet NSButton* m_button2;           // menu 0
    IBOutlet NSTextField* m_buttonLabel2;
    IBOutlet NSButton* m_button3;           // menu 1
    IBOutlet NSTextField* m_buttonLabel3;
    
    IBOutlet NSMatrix* m_radio;
    IBOutlet NSTextField* m_radioLabel0;
    
    IBOutlet NSSlider* m_slider;
    IBOutlet NSTextField* m_sliderLabel1;
    IBOutlet NSTextField* m_sliderLabel2;
    IBOutlet NSTextField* m_sliderLabel3;
    IBOutlet NSTextField* m_sliderLabel4;
    IBOutlet NSTextField* m_sliderLabel5;
    
    IBOutlet DeviceController* m_deviceController;
    
    double m_sliderValue;
}

-(IBAction)sliderChanged:(id)sender;
-(IBAction)controlChanged:(id)sender;

-(NSString*) deviceName;

-(void) setCheckboxes: (NSArray*) checkboxes;
-(void) setMenus: (NSArray*) menus;
-(void) setQuality: (NSArray*) qualityStops;

-(int) checkboxState:(int) index;
-(int) menuState:(int) index;
-(int) qualityState;
-(double) sliderValue;

@end

#define DT_NO_MENUS @"nomenus"
#define DT_RADIO_2_CHECK @"radio2check"
#define DT_2_MENU_2_CHECK @"2menu2check"
#define DT_DVD @"dvd"

@interface QualityStop : NSObject {
    NSString* m_title;

    double m_bitrate;

    NSMutableDictionary* m_params;
    NSString* m_script;
}

+(QualityStop*) qualityStopWithElement: (NSXMLElement*) element;

-(NSString*) title;
-(NSDictionary*) params;
-(NSString*) script;
-(double) bitrate;

@end

@interface PerformanceItem : NSObject {
    NSString* m_title;
    
    NSMutableDictionary* m_params;
    NSString* m_script;
}

+(PerformanceItem*) performanceItemWithElement: (NSXMLElement*) element;

-(NSString*) title;
-(NSDictionary*) params;
-(NSString*) script;

@end

@interface Checkbox : NSObject {
    NSString* m_title;
    
    NSMutableDictionary* m_checkedParams;
    NSString* m_checkedScript;
    NSMutableDictionary* m_uncheckedParams;
    NSString* m_uncheckedScript;
}

+(Checkbox*) checkboxWithElement: (NSXMLElement*) element;

-(NSString*) title;
-(NSDictionary*) uncheckedParams;
-(NSString*) uncheckedScript;
-(NSDictionary*) checkedParams;
-(NSString*) checkedScript;

@end

@interface Menu : NSObject {
    NSString* m_title;
    
    NSMutableArray* m_itemTitles;
    NSMutableArray* m_itemParams;
    NSMutableArray* m_itemScripts;
}

+(Menu*) menuWithElement: (NSXMLElement*) element;
-(NSArray*) itemTitles;
-(NSArray*) itemParams;
-(NSArray*) itemScripts;
-(NSString*) title;

@end

@interface DeviceEntry : NSObject {
    NSString* m_icon;
    NSString* m_title;
    NSString* m_groupTitle;
    
    DeviceEntry* m_defaultDevice;
    
    NSString* m_deviceTabName;
    DeviceTab* m_deviceTab;
    
    NSMutableArray* m_qualityStops;
    NSMutableArray* m_performanceItems;
    NSMutableArray* m_recipes;
    NSMutableDictionary* m_params;
    NSString* m_script;
    NSMutableArray* m_checkboxes;
    NSMutableArray* m_menus;
    
    double m_minBitrate;
    double m_maxBitrate;
    int m_currentQualityStopIndex;
}

+(DeviceEntry*) deviceEntryWithElement: (NSXMLElement*) element inGroup: (NSString*) group withDefaults: (DeviceEntry*) defaults;
-(DeviceEntry*) initWithElement: (NSXMLElement*) element inGroup: (NSString*) group withDefaults: (DeviceEntry*) defaults;

-(NSString*) group;
-(NSString*) title;
-(NSString*) icon;
-(NSArray*) qualityStops;
-(NSArray*) performanceItems;
-(NSArray*) recipes;
-(NSString*) fileSuffix;
-(NSString*) videoFormat;
-(double) bitrate;

-(void) setCurrentParamsInJavaScriptContext:(JavaScriptContext*) context performanceIndex:(int) perfIndex;
-(void) populateTabView:(NSTabView*) tabview;
-(void) populatePerformanceButton:(NSPopUpButton*) tabview;
-(void) addParamsToJavaScriptContext: (JavaScriptContext*) context performanceIndex:(int) perfIndex;
-(void) evaluateScript: (JavaScriptContext*) context performanceIndex:(int) perfIndex;

@end
