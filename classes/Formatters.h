//
//  Formatters.h
//  VideoMonkey
//
//  Created by Chris Marrin on 1/20/09.
//  Copyright 2009 Apple. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FileSizeFormatter : NSNumberFormatter {
}

- (NSString *)stringForObjectValue:(id)anObject;

@end

@interface DurationFormatter : NSNumberFormatter {
}

- (NSString *)stringForObjectValue:(id)anObject;

@end
