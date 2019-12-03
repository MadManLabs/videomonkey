//
//  FileInfoPanelController.m
//  VideoMonkey
//
//  Created by Chris Marrin on 11/12/08.

/*
Copyright (c) 2009-2011 Chris Marrin (chris@marrin.com)
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, 
are permitted provided that the following conditions are met:

    - Redistributions of source code must retain the above copyright notice, this 
      list of conditions and the following disclaimer.

    - Redistributions in binary form must reproduce the above copyright notice, 
      this list of conditions and the following disclaimer in the documentation 
      and/or other materials provided with the distribution.

    - Neither the name of Video Monkey nor the names of its contributors may be 
      used to endorse or promote products derived from this software without 
      specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY 
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT 
SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH 
DAMAGE.
*/

#import "AppController.h"
#import "DeviceController.h"
#import "FileInfoPanelController.h"
#import "FileListController.h"
#import "Metadata.h"
#import "MetadataSearch.h"
#import "Transcoder.h"

@implementation FileInfoPanelController

@synthesize fileListController = m_fileListController;
@synthesize metadataPanel = m_metadataPanel;
@synthesize metadataStatus = m_metadataStatus;
@synthesize searcherStrings = m_searcherStrings;
@synthesize metadataEnabled = m_metadataEnabled;

-(BOOL) autoSearch
{
    return [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:@"autoSearch"] boolValue];    
}

-(void) setAutoSearch:(BOOL) value
{
    [[[NSUserDefaultsController sharedUserDefaultsController] values] setValue:[NSNumber numberWithBool:value] forKey:@"autoSearch"];
}

-(NSString*) currentSearcher
{
    NSString* s = [[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:@"defaultMetadataSearch"];
    return ([s length] == 0) ? @"thetvdb.com" : s;
}

-(void) setCurrentSearcher:(NSString*) s
{
    [[[NSUserDefaultsController sharedUserDefaultsController] values] setValue:s forKey:@"defaultMetadataSearch"];
}

-(NSArray*) artworkList
{
    return [[(Transcoder*) [m_fileListController selection] metadata] artworkList];
}

-(NSImage*) primaryArtwork
{
    return [[(Transcoder*) [m_fileListController selection] metadata] primaryArtwork];
}

-(void) setPrimaryArtwork:(NSImage*) image
{
    id item = [[(Transcoder*) [m_fileListController selection] metadata] createArtwork: image];
    [m_artworkListController insertObject:item atArrangedObjectIndex:0];
}

- (void)awakeFromNib
{
    [m_fileInfoWindow setExcludedFromWindowsMenu:YES];
    
    [m_artworkTable setRowHeight:[[[m_artworkTable tableColumns] objectAtIndex:2] width]];
    
    // scroll to top of metadata
    NSPoint pt = NSMakePoint(0.0, [[m_metadataScrollView documentView] bounds].size.height);
    [[m_metadataScrollView documentView] scrollPoint:pt];
    
    // make the search box selected
    [m_searchField setDelegate:self];
    [m_searchField becomeFirstResponder];
    
    // Fill in the searchers
    self.searcherStrings = [NSArray arrayWithObjects:@"thetvdb.com", @"themoviedb.org", nil];
    self.currentSearcher = [[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:@"defaultMetadataSearch"];
    
    // Initialize the metadata disabled status
    [self setMetadataStateForFileType:nil];
}

-(IBAction)droppedInImage:(id)sender
{
    [m_artworkTable reloadData];
}

-(void) setVisible: (BOOL) b
{
    if (b != m_isVisible) {
        m_isVisible = b;
        if (m_isVisible)
            // Update info
            ;
    }
}

- (void)windowWillMiniaturize:(NSNotification *)notification
{
    [self setVisible:NO];
}

- (void)windowDidDeminiaturize:(NSNotification *)notification
{
    [self setVisible:YES];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [self setVisible:NO];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    [self setVisible:YES];
}

// NSDrawer delegate methods
- (NSSize)drawerWillResizeContents:(NSDrawer *)sender toSize:(NSSize)contentSize
{
    [m_artworkTable setRowHeight:[[[m_artworkTable tableColumns] objectAtIndex:2] width]];
    return contentSize;
}

// keep the disclosure button updated correctly
- (void)drawerDidClose:(NSNotification *)notification
{
    [m_artworkDrawerDisclosureButton setState:NSOffState];
}

-(IBAction)artworkCheckedStateChanged:(id)sender
{
    [m_fileListController rearrangeObjects];
}

- (void)searchStringSelected:(NSString*)searchString
{
    if ([searchString length]) {
        m_metadataSearchCount = 0;
        m_metadataSearchSucceeded = YES;
        [m_fileListController searchSelectedFilesForString:searchString];
    }
}

-(IBAction)searchBoxSelected:(id)sender
{
    NSString* searchString = [[sender stringValue] retain];
    [self searchStringSelected:searchString];
    [searchString release];
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification
{
    [self searchStringSelected:[notification.object objectValueOfSelectedItem]];
}

- (IBAction)useSeasonValueForAllFiles:(id)sender
{
    if ([m_fileListController selection]) {
        Transcoder* selectedTranscoder = [m_fileListController selection];
        NSString* season = selectedTranscoder.metadata.search.currentSeason;
        NSArray* arrangedObjects = [m_fileListController arrangedObjects];
        
        for (Transcoder* transcoder in arrangedObjects)
            transcoder.metadata.search.currentSeason = season;
    }
}

- (IBAction)searchAllFiles:(id)sender
{
    m_metadataSearchCount = 0;
    m_metadataSearchSucceeded = YES;
    [m_fileListController searchAllFiles];
}

- (IBAction)searchSelectedFiles:(id)sender
{
    m_metadataSearchCount = 0;
    m_metadataSearchSucceeded = YES;
    [m_fileListController searchSelectedFiles];
}

- (void)initializeMetadataSearch
{
    m_metadataSearchCount = 0;
    m_metadataSearchSucceeded = YES;
}    

- (void) startMetadataSearch
{
    if (++m_metadataSearchCount == 1) {
        [self.metadataPanel setMetadataSearchSpinner:YES];
        self.metadataStatus = @"Searching for metadata...";
    }
}

- (void) finishMetadataSearch:(BOOL) success
{
    if (!success)
        m_metadataSearchSucceeded = NO;

    if (--m_metadataSearchCount <= 0) {
        [self.metadataPanel setMetadataSearchSpinner:NO];
        self.metadataStatus = @"";
        
        [m_fileListController setSearchBox];
        
        if (!m_metadataSearchSucceeded) {
            // If we failed, show an alert
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"One or more metadata searches failed"];
            [alert setInformativeText:@"See console for more information"];
            [alert setAlertStyle:NSWarningAlertStyle];
            [alert runModal];
        }
    }
}

- (void)setMetadataStateForFileType:(NSString*) fileType
{
    BOOL enabled = fileType && [fileType length];
    
    if (![fileType isEqualToString:@"MPEG-4"])
        enabled = NO;
        
    [m_metadataContainer setHidden:!enabled];
    [m_metadataDisabledMessage setHidden:enabled];
    
    if (!enabled) {
        if (!fileType)
            [m_metadataDisabledMessage setStringValue:[NSString stringWithFormat:@"No metadata compatible output file selected"]];
        else
            [m_metadataDisabledMessage setStringValue:[NSString stringWithFormat:@"Metadata cannot be written to %@ files", fileType]];
    }
}

-(id) selection
{
    // if we get here it means the artwork has no selection
    return nil;
}

- (id)valueForUndefinedKey:(NSString *)key
{
    NSLog(@"*** FileInfoPanelController::valueForUndefinedKey:%@\n", key);
    return nil;
}

// NSTextField delegate methods for searchField
- (void)controlTextDidBeginEditing:(NSNotification *)aNotification
{
    m_searchFieldIsEditing = YES;
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
    //NSLog(@"textDidChange\n");
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
    m_searchFieldIsEditing = NO;
}

@end
